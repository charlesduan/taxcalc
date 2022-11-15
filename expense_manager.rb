require 'tax_form'

#
# Computes deductions from a table of business expenses. This implements parts
# of Publication 535, under Other Expenses.
#

class ExpenseManager < TaxForm
  NAME = 'Business Expense Manager'

  def year
    2021
  end

  def compute
    exps = forms('Business Expense')

    # Arrange the business expenses into a hash, keyed by category.
    deds = {}
    exps.each do |exp|
      cat = exp.line['category']
      deds[cat] ||= 0.0
      deds[cat] += exp.line['amount']
    end

    # For each of these categories, the deduction value is divided by two.
    half_cats = %w(Meals Utilities)

    #
    # 100% deduction for business meals in 2021 and 2022. Note that per IRS
    # Notice 2021-25, the 100% deduction only applies to "restaurants". For
    # deductions for grocery stores, convenience stores, or others that
    # primarily sell "packaged food" for later consumption, you will have to
    # manually divide these amounts in the input file.
    #
    if year == 2021 or year == 2022
      half_cats.delete("Meals")
    end

    half_cats.each do |half_cat|
      deds[half_cat] /= 2 if deds[half_cat]
    end

    deds.keys.sort.each do |cat|
      line[cat] = deds[cat].round
    end

    # Add in the safe harbor assets.
    @asset_manager = find_or_compute_form('Asset Manager')
    if @asset_manager.has_safe_harbor_expenses?
      line['Safe_Harbor'] = @asset_manager.safe_harbor_expense_total.round
    end

    #
    # This will store the deduction categories that have been placed onto a form
    # already, such that the unused categories can be totaled for an Other field
    # and included on a continuation sheet.
    #
    @used_cats = []
  end

  def fill_lines(fill_form, fill_lines, other: nil,
                 continuation: 'Table of Business Expenses')

    #
    # fill_lines is a hash of line numbers for fill_form to one or more
    # categories (i.e., line numbers in the expense manager).
    #
    fill_lines.each do |l, cats|
      cats = [ cats ].flatten.map(&:to_s)
      v = cats.map { |c| line[c, :opt] }.sum
      fill_form.line[l] = v if v != 0
      @used_cats.push(*cats)
    end

    other_amt = line.map { |l, v| @used_cats.include?(l) ? BlankZero : v }.sum
    if other_amt != 0
      if other
        fill_form.line[other] = other_amt
      else
        warn("In expense manager, no 'other' field but other expenses found")
      end
      make_continuation(fill_form, continuation) if continuation
    end
  end

  def make_continuation(form, name)
    @con_form = NamedForm.new(name, @manager)
    @manager.add_form(@con_form)
    @con_form.exportable = true

    cats, amts = line.to_a.reject { |l, v| @used_cats.include?(l) }.transpose
    cats = cats.map { |c| present_name(c) }
    amts = amts.map { |a| a.round }
    @con_form.line['Type', :all] = cats
    @con_form.line['Amount', :all] = amts
    form.line[:continuation!] = name
  end

  #
  # This is a table of category names mapped to presentation names. These
  # category names should be used in tables of business expenses. Other names
  # should follow the naming conventions found in Form 1065 or Form 1040
  # Schedule C.
  #
  CAT_NAMES = {
    'Meals' => 'Business Meals',
    'Licenses' => 'Taxes and Licenses',
    'Safe_Harbor' => '1.263(a)-1(f) Safe Harbor',
    'Rent_Equipment' => 'Rented Vehicles, Machinery, and Equipment',
    'Rent_Property' => 'Rented Business Property',
  }

  def present_name(cat)
    CAT_NAMES[cat] || cat.gsub('_', ' ')
  end

end

