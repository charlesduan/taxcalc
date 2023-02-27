require_relative 'tax_form'
require_relative 'categorization'

#
# Computes deductions from a table of business expenses. This implements parts
# of Publication 535, under Other Expenses.
#

class ExpenseManager < TaxForm

  include Categorization

  NAME = 'Business Expense Manager'

  def year
    2022
  end

  def compute
    categorize_records('Business Expense')

    # Utilities is assumed to be split between personal and business use.
    modify_category('Utilities') { |amt| amt / 2.0 }
    #
    # 100% deduction for business meals in 2021 and 2022. Note that per IRS
    # Notice 2021-25, the 100% deduction only applies to "restaurants". For
    # deductions for grocery stores, convenience stores, or others that
    # primarily sell "packaged food" for later consumption, you will have to
    # manually divide these amounts in the input file.
    #
    unless [ 2021, 2022 ].include?(year)
      modify_category('Meals') { |amt| amt / 2.0 }
    end

    # Add in the safe harbor assets.
    @asset_manager = find_or_compute_form('Asset Manager')
    if @asset_manager.has_safe_harbor_expenses?
      modify_category('Safe_Harbor') { |amt|
        amt + @asset_manager.safe_harbor_expense_total.round
      }
    end

    # Save the categorized data as line entries in this manager.
    category_form_lines

  end

  def fill_lines(fill_form, fill_lines, other: nil,
                 continuation: 'Table of Business Expenses')

    #
    # fill_lines is a hash of line numbers for fill_form to one or more
    # categories (i.e., line numbers in the expense manager).
    #
    fill_lines.each do |l, cats|
      cats = [ cats ].flatten.map(&:to_s)
      fill_for_categories(fill_form, l, *cats)
    end

    unless other
      warn("In expense manager, no 'other' field")
      return
    end
    fill_other_categories(
      fill_form, other, continuation: continuation,
      category_map: CAT_NAMES
    )
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

end

