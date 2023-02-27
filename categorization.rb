#
# Manages a table of expenses organized by category.
#
module Categorization

  #
  # Searches for all forms of the given type, and computes aggregate amounts for
  # each category.
  #
  def categorize_records(form_name)
    if @categorized_amounts
      raise "Cannot recompute categorization"
    end
    @categorized_amounts = {}
    forms(form_name).each do |f|
      cat = f.line['category']
      unless @categorized_amounts.include?(cat)
        @categorized_amounts[cat] = {
          :used => false,
          :amount => 0.0
        }
      end
      @categorized_amounts[cat][:amount] += f.line['amount']
    end

  end

  #
  # Modifies a category's amount by a rule given in the block.
  #
  def modify_category(cat)
    if @categorized_amounts.include?(cat)
      @categorized_amounts[cat][:amount] = yield(
        @categorized_amounts[cat][:amount]
      )
    else
      new_amount = yield(0.0)
      if new_amount != 0.0
        @categorized_amounts[cat] = {
          :used => false, :amount => new_amount
        }
      end
    end
  end

  #
  # Adds form lines for each category, the value being the summed amount.
  #
  def category_form_lines
    @categorized_amounts.keys.sort.each do |cat|
      line[cat] = @categorized_amounts[cat][:amount].round(2)
    end
  end

  #
  # Retrieves one or more categories' amount, marking the categories as used for
  # purposes of generating a continuation form. Then fills the given line on the
  # given form if the value is nonzero.
  #
  def fill_for_categories(fill_form, fill_line, *cats)
    res = cats.sum { |cat|
      if @categorized_amounts[cat]
        @categorized_amounts[cat][:used] = true
        @categorized_amounts[cat][:amount]
      else
        0.0
      end
    }.round
    if res != 0.0
      fill_form.line[fill_line] = res
    end
  end

  #
  # For any unfilled categories, sums them, enters the result in a given "Other"
  # form line, and produces a continuation form.
  #
  def fill_other_categories(fill_form, other_line,
                            continuation: 'Table of Expenses',
                            category_map: {})

    unused = @categorized_amounts.select { |cat, data| !data[:used] }.sort
    return if unused.empty?

    fill_form.line[other_line] = unused.sum { |cat, data| data[:amount] }.round

    con_form = NamedForm.new(continuation, fill_form.manager)
    fill_form.manager.add_form(con_form)
    con_form.exportable = true
    fill_form.line[:continuation!] = continuation

    con_form.line['Type', :all] = unused.map { |cat, data|
      category_map[cat] || cat.gsub('_', ' ')
    }

    con_form.line['Amount', :all] = unused.map { |cat, data|
      data[:amount].round(2)
    }
  end
end
