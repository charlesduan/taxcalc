require 'tax_form'
require 'date'

class FormD65 < TaxForm

  def name
    'D-65'
  end

  def check_box(line_no, condition)
    if condition
      line["#{line_no}.yes"] = '*'
    else
      line["#{line_no}.no"] = '*'
    end
  end

  def compute
    f1065 = form(1065)

    line[:ein] = f1065.line[:D]
    line[:tax_period_month] = 12
    line[:tax_period_year] = (Date.today.year - 1) % 100

    line[:business_name] = f1065.line[:name]
    line[:address] = f1065.line[:address]
    csz = f1065.line[:address2]
    if csz =~ /,? ([A-Z][A-Z]) (\d{5}(?:-\d{4})?)$/
      line[:city] = $`
      line[:state] = $1
      line[:zip] = $2
    else
      raise "Could not parse city, state, zip"
    end

    line[1] = f1065.line['1c']
    copy_line(2, f1065)
    line[3] = line[1] - line[2, :opt]

    copy_line(4, f1065)
    copy_line(5, f1065)
    copy_line(6, f1065)
    copy_line(7, f1065)

    line[8] = sum_lines(3, 4, 5, 6, 7)

    copy_line(9, f1065)
    copy_line(10, f1065)
    copy_line(11, f1065)
    copy_line(12, f1065)
    copy_line(13, f1065)
    copy_line(14, f1065)
    copy_line(15, f1065)
    copy_line(16, f1065)
    copy_line(17, f1065)
    copy_line(18, f1065)
    copy_line(19, f1065)
    copy_line(20, f1065)

    line[21] = sum_lines(*9:20)

    line[22] = line[8] - line[21]

    assert_question('Did you have non-DC gross receipts of income?', false)
    line['F1.1'] = line[1]
    line['F1.2'] = line[1]
    line['F2'] = (line['F1.2'] * 1.0 / line['F1.1']).round(6)

    if f1065.line[:E] =~ /^(\d+)\/(\d+)\/(\d+)$/
      line[:A] = "%02d%02d" % [ $1, $3 % 100 ]
    else
      raise "Could not parse start date"
    end

    if f1065.line['H.1', :present]
      line['B.cash'] = '*'
    elsif f1065.line['H.2', :present]
      line['B.accrual'] = '*'
    elsif f1065.line['H.3', :present]
      line['B.other'] = '*'
      line['B.other.expl'] = f1065.line['H.other']
    end

    line[:C] = f1065.line[:I]
    check_box(:D, f1065.line['B1b', :present])

    check_box(:E, f1065.line['B1c', :present])

    partner_types = forms('1065 Schedule K-1').lines('I1')
    check_box(:F, !(partner_types & %w(Corporate Partnership)).empty?)

    check_box(
      :G, interview("Is this partnership a partner in another partnership?")
    )

    check_box(:H, f1065.line['12a.yes', :present])
    check_box(:I, interview('Was a D-65 filed for the preceding year?'))
    check_box(:J, interview('Was a D-30 filed for the preceding year?'))
    check_box(:K, interview('Did you file a ballpark fee return?'))
    check_box(:L, interview('Did you file forms 1096 or 1099?'))

    if line[9, :opt] == 0
      line['M.no'] = '*'
      line['M.expl'] = 'No employees'
    else
      raise 'DC wage withholding question not implemented'
    end

    check_box(:N, interview('Was your previous year 1065 amended or changed?'))

  end
end
