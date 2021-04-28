module HomeOfficeManager

  def home_office_sole_proprietorship
    forms('Home Office') { |f|
      f.line['type'] == 'sole proprietorship'
    }.each do |f|
      raise "Home office for sole proprietorship not implemented"
    end
  end

  def home_office_partnership
    forms('Home Office') { |f| f.line['type'] == 'partnership' }.each do |f|
      unless f.line['method'] == 'simplified'
        raise 'Actual home office expense method not implemented'
      end

      k1 = forms('1065 Schedule K-1').find { |k| k.line['A'] == f.line['ein'] }
      raise "No matching 1065 Schedule K-1 for Home Office form" unless k1
      ws = @manager.compute_form('Publication 587 Worksheets', f, k1)
      yield(f, ws.line[:fill!]) if ws.line[:fill!] != 0
    end
  end

end

class Pub587Worksheet < TaxForm

  NAME = 'Publication 587 Worksheets'

  def year
    2019
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
    line[5] = [ [ line[1], line[4] ].min, 0 ].max
    line[:fill!] = line[5]
  end

  def compute_actual
    raise "Home office actual expenses not implemented"

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

  end

end

module Pub587Partnership

  def income_form
    return @income_form if @income_form
    fs = forms('1065 Schedule K-1') { |f| f.line[:A] == @ho_form.line[:ein] }
    unless fs.count == 1
      raise "Zero or multiple matching 1065 Schedule K-1 forms found"
    end
    @income_form = fs[0]
    return @income_form
  end

  def confirm_all_from_home
    assert_question(
      "Is all income/loss for Partnership " + \
      "#{@ho_form.line[:ein]} from business use of your home?",
      true
    )
  end

  def gross_income
    confirm_all_from_home
    return @income_form.sum_lines(
      1, 2, 3, 4, 5, '6a', '6b', 7, 8, '9a', '9b', '9c', 10, 11
    )
  end

  def nonhome_business_expenses
    assert_question(
      'Do you have unreimbursed partnership expenses (other than home office)?',
      false
    )
    return @income_form.line[12]
  end
end
