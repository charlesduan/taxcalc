module HomeOfficeManager

  def home_office_partnership
    forms('Home Office') { |f| f.line['type'] == 'partnership' }.each do |f|
      unless f.line['method'] == 'simplified'
        raise 'Actual home office expense method not implemented'
      end

      k1 = forms('1065 Schedule K-1').find { |k| k.line['A'] == f.line['ein'] }
      raise "No matching 1065 Schedule K-1 for Home Office form" unless k1
      ws = @manager.compute_form(
        Pub587Worksheet.new(@manager, f, k1)
      )
      yield(f, ws.line[:fill]) if ws.line[:fill] != 0
    end
  end

end

class Pub587Worksheet < TaxForm

  def name
    'Publication 587 Worksheets'
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
      line[:method] = 'simplified'
      compute_simplified
    when 'actual'
      line[:method] = 'actual'
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
    line[:fill] = line[5]
  end

  def compute_actual
    raise "Home office actual expenses not implemented"

    # Right now it's not worth implementing this because it would require also
    # implementing the reduction in the Schedule A mortgage interest deduction,
    # and as a practical matter the mortgage interest gets deducted either here
    # or there.

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
