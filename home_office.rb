require 'tax_form'
require 'categorization'
#
# Manages the computation of all home offices for this tax return. This form
# should be computed after all sources of self-employment income have been
# determined.
#
class HomeOfficeManager < TaxForm

  def year
    2023
  end

  NAME = 'Home Office Manager'

  def compute

    #
    # A Home Office form should be associated with an individual (SSN) and a
    # business (type and possibly EIN). This collects every Home Office form,
    # runs the appropriate worksheet or form on it, and collects a table of all
    # home office expense amounts.
    #

    forms('Home Office').each do |f|
      ssn = f.line[:ssn]
      worksheet = nil
      case f.line[:type]
      when 'sole proprietorship'
        raise "Home office for sole proprietorship not implemented"
      when 'partnership'
        k1 = form('1065 Schedule K-1') { |k|
          k.line[:ein] == f.line[:ein] && k.line[:ssn] == f.line[:ssn]
        }
        worksheet = compute_form('Pub. 587 Worksheets', f, k1)
        add_table_row(
          :type => f.line[:type],
          :ssn => f.line[:ssn],
          :ein => f.line[:ein],
          :amount => worksheet.line[:ho_expenses]
        )
      end
    end
  end

  # Various methods should be added below for retrieving home office expenses
  # for purposes of filling in forms.

  def each_match(hash)
    return unless line[:type, :present]

    line[:type, :all].count.times do |i|
      next unless hash.all? { |k, v| line[k, :all][i] == v }
      yield(
        :type => line[:type, :all][i],
        :ssn => line[:ssn, :all][i],
        :ein => line[:ein, :all][i],
        :amount => line[:amount, :all][i]
      )
    end
  end

  def total_matching(hash)
    total = 0
    each_match(hash) do |mhash|
      total += mhash[:amount]
    end
    return total
  end

end

class Pub587Worksheet < TaxForm

  include Categorization

  NAME = 'Pub. 587 Worksheets'

  def year
    2022
  end

  def initialize(manager, ho_form, income_form)
    super(manager)
    @ho_form = ho_form
    @income_form = income_form
  end

  def compute


    case @ho_form.line[:type]
    when 'partnership'
      extend Pub587Partnership
    else
      raise "Unknown Home Office business type #{@ho_form.line[:type]}"
    end

    # Biographical identification information
    line[:ssn] = @ho_form.line[:ssn]
    line[:ein] = @ho_form.line[:ein]
    line[:property] = @ho_form.line[:property]

    case @ho_form.line[:method]
    when 'simplified'
      line[:method!] = 'simplified'
      compute_simplified
    when 'actual'
      line[:method!] = 'actual'
      compute_actual
    else
      raise "Unknown Home Office method #{@ho_form.line[:method]}"
    end

  end

  def compute_simplified
    line[1] = gross_income
    line[2] = [ @ho_form.line[:sqft], 300 ].min
    line['3a'] = 5
    if @ho_form.line['daycare?']
      raise 'Day care home office not implemented'
    else
      line['3b'] = 1.0
    end
    line['3c'] = (line['3b'] * line['3a']).round(2)
    line[4] = (line[2] * line['3c']).round
    line['5/ho_expenses'] = [ [ line[1], line[4] ].min, 0 ].max

    # Line 6 only applies if you used actual expenses in a previous year

  end

  #
  # Chances are, the actual method should not be used unless we start hitting
  # mortgage interest deduction limits or utility costs go up. The main
  # deductions here are mortgage interest and depreciation, but mortgage
  # interest is deductible personally on Schedule A, and depreciation ends up
  # being recaptured at time of sale, making the deduction a wash. While the
  # $5 per square foot rate of the simplified method is lower than the actual
  # expenses, it cannot be recaptured at time of sale, so chances are it works
  # out better.
  #
  def compute_actual
    line[1] = @ho_form.line['sqft']
    line[2] = @ho_form.line['total_sqft']
    line[3] = (line[1] * 100.0 / line[2]).round(2)

    line['4/gross_inc'] = gross_income

    # We make a simplifying assumption that (1) every Home Office Expense
    # applies to every Home Office form, and (2) all expenses are indirect.
    categorize_records('Home Office Expense')
    #
    # We assume that the home office using the actual method is being rented and
    # thus there are no mortgage payments or such on it.
    #
    #fill_for_categories(self, '5b', 'Casualty_Losses')
    #fill_for_categories(self, '6b', 'Mortgage_Interest')
    #fill_for_categories(self, '7b', 'Real_Estate_Taxes')

    line['8b'] = sum_lines('5b', '6b', '7b')
    line[9] = (line['8b'] * line[3] / 100.0).round
    line[10] = line[9]

    line[11] = other_business_expenses

    line[12] = sum_lines(10, 11)
    line['13/ho_max_ded'] = line[4] - line[12]

    fill_for_categories(self, '16b', 'Insurance')
    fill_for_categories(self, '17b', 'Rent')
    fill_for_categories(self, '18b', 'Repairs')
    fill_for_categories(self, '19b', 'Utilities')
    fill_other_categories(
      self, '20b', continuation: 'Other Home Office Expenses'
    )
    line['21b'] = sum_lines(*%w(14b 15b 16b 17b 18b 19b 20b))
    line[22] = (line['21b'] * line[3] / 100.0).round

    # Assume no carryover for line 23
    line['24/ho_ded'] = sum_lines('21a', 22, 23)
    line[25] = [ line[13], line[24] ].min
    line[26] = line[13] - line[25]

    # Assume no casualty losses or depreciation for lines 27-29 and 33
    line[30] = sum_lines(27, 28, 29)
    line[31] = [ line[26], line[30] ].min
    line[32] = sum_lines(10, 25, 31)

    line[33] = BlankZero
    line['34/ho_expenses'] = line[32] - line[33]

  end

end

module Pub587Partnership

  def income_form
    return @income_form if @income_form
    fs = forms('1065 Schedule K-1') { |f|
      f.line[:A] == @ho_form.line[:ein] && \
        f.line[:E] == @ho_form.line[:ssn]
    }
    unless fs.count == 1
      raise "Zero or multiple matching 1065 Schedule K-1 forms found"
    end
    @income_form = fs[0]
    return @income_form
  end

  def gross_income
    confirm(
      "All income/loss for Partnership " + \
      "#{@ho_form.line[:ein]} is from business use of your home",
    )
    return @income_form.sum_lines(
      1, 2, 3, 4, 5, '6a', '6b', 7, 8, '9a', '9b', '9c', 10, 11
    )
  end

  #
  # Most partnership expenses would already have been deducted as reimbursed.
  # However, if there are any UPEs, they would count against the home office
  # deduction. Currently I don't have a good way of separating UPEs by partner.
  #
  def other_business_expenses
    return forms("Unreimbursed Partnership Expense") { |f|
      f.line[:ssn] == @ho_form.line[:ssn]
    }.lines(:amount, :sum)
  end

end
