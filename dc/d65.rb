require 'tax_form'
require 'date'
require 'dc/d65_distrib'

class FormD65 < TaxForm

  NAME = 'D-65'

  def year
    2019
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

    line[:ein] = f1065.line[:D].sub("-", "")
    box_line(:ein, 9)
    line[:tax_period] = "1231#{year}"
    box_line(:tax_period, 4)

    line[:business_name] = f1065.line[:name]
    box_line(:business_name, 25)
    addr, addr2 = f1065.line[:address], nil
    if addr.length > 26
      addr.match(/^(.{0,26}) (.*)$/) { |m| addr, addr2 = m[1], m[2] }
    end
    line[:address] = addr
    box_line(:address, 26)
    if addr2
      line[:address2] = addr2
      box_line(:address2, 26)
    end

    csz = f1065.line[:city_zip]
    if csz =~ /,? ([A-Z][A-Z]) (\d{5}(?:-\d{4})?)$/
      line[:city] = $`
      box_line(:city, 20)
      line[:state] = $1
      box_line(:state, 2)
      line[:zip] = $2
      box_line(:zip, 5)
    else
      raise "Could not parse city, state, zip"
    end

    line[:agent_name] = f1065.line['PR.name']
    line[:agent_tin] = f1065.line['PR.tin!'].gsub("-", "")
    box_line(:agent_name, 21)
    box_line(:agent_tin, 9)

    1.upto(22) do |n| box_line(n, 9) end

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

    line[21] = sum_lines(*9..20)

    line[22] = line[8] - line[21]


    #
    # Page 2
    #
    line[:page2_name] = line[:business_name]
    line[:page2_ein] = line[:ein]

    assert_question('Did you have non-DC gross receipts of income?', false)
    line['F1.1'] = line[1]
    line['F1.2'] = line[1]
    line['F2'] = (line['F1.2'] * 1.0 / line['F1.1']).round(6)

    line[:A] = f1065.line[:E].strftime("%m%y")
    box_line(:A, 4)

    if f1065.line['H.1', :present]
      line['B.cash'] = '*'
    elsif f1065.line['H.2', :present]
      line['B.accrual'] = '*'
    elsif f1065.line['H.3', :present]
      line['B.other'] = '*'
      line['B.other.expl'] = f1065.line['H.other']
    end

    line[:C] = f1065.line[:I]
    box_line(:C, 4)
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

    line[:filing_explanation!, :all] = [
      'Explanation for Filing Form D-65 Rather Than Form D-30',
      'Form D-65 is being filed because the partnership for which the form is',
      'being filed is a trade or business deriving more than 80% of its gross',
      'income from personal services rendered by owners or members of the',
      'partnership in conducting or carrying on a trade or business in which',
      'capital is not a material income-producing factor.',
    ]

    compute_form('Schedule of Pass-Through Distribution of Income')
    line[:continuation!] = 'Schedule of Pass-Through Distribution of Income'

  end
end
