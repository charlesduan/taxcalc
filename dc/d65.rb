require 'tax_form'
require 'date'
require 'dc/d65_distrib'
require 'dc/fr165'

class FormD65 < TaxForm

  NAME = 'D-65'

  def year
    2022
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

    line[:ein] = f1065.line[:ein].sub("-", "")
    line[:tax_period] = "1231#{year}"

    line[:business_name] = f1065.line[:name]
    addr, addr2 = f1065.line[:address], nil
    if addr.length > 26
      addr.match(/^(.{0,26}) (.*)$/) { |m| addr, addr2 = m[1], m[2] }
    end
    line[:address] = addr
    if addr2
      line[:address2] = addr2
    end

    csz = f1065.line[:city_zip]
    if csz =~ /,? ([A-Z][A-Z]) (\d{5}(?:-\d{4})?)$/
      line[:city] = $`
      line[:state] = $1
      line[:zip] = $2
    else
      raise "Could not parse city, state, zip"
    end

    line[:agent_name] = f1065.line['PR.name']
    line[:agent_tin] = f1065.line['PR.tin!'].gsub("-", "")

    copy_line(1, f1065, from: '1c')
    copy_line(2, f1065)
    line[3] = line[1] - line[2, :opt]

    copy_line(4, f1065)
    copy_line(5, f1065)
    copy_line(6, f1065)

    # Line 7 has something to do with QOFs; it is assumed that this partnership
    # is not for one. If it were, then Form 1065 Schedule B, line 25 suggests
    # that Form 8996 would be attached.
    with_form(8996) do |f|
      raise "Qualified Opportunity Fund not implemented"
    end
    copy_line(8, f1065, from: 7)

    line[9] = sum_lines(3, 4, 5, 6, 7, 8)

    copy_line(10, f1065, from: 9)
    copy_line(11, f1065, from: 10)
    copy_line(12, f1065, from: 11)
    copy_line(13, f1065, from: 12)
    copy_line(14, f1065, from: 13)
    copy_line(15, f1065, from: 14)
    copy_line(16, f1065, from: 15)
    copy_line(17, f1065, from: '16c')
    copy_line(18, f1065, from: 17)
    copy_line(19, f1065, from: 18)
    copy_line(20, f1065, from: 19)
    # Line 21 relates to QOFs
    copy_line(22, f1065, from: 20)

    line[23] = sum_lines(*10..22)

    line[24] = line[9] - line[23]


    #
    # Page 2
    #
    line[:page2_name] = line[:business_name]
    line[:page2_ein] = line[:ein]

    confirm('You have no non-DC gross receipts of income')
    line['F1.1'] = line[1]
    line['F1.2'] = line[1]
    line['F2'] = (line['F1.2'] * 1.0 / line['F1.1']).round(6)

    line[:A] = f1065.line[:E].strftime("%m%y")

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

    confirm("This partnership is not a partner in another partnership")
    check_box(:G, false)

    check_box(:H, f1065.line['12a.yes', :present])
    confirm("A D-65 was filed for the preceding year.")
    check_box(:I, true)
    confirm("A D-30 was not filed for the preceding year.")
    check_box(:J, false)
    confirm("A ballpark fee return was not filed.")
    check_box(:K, false)
    check_box(:L, f1065.line['16b.yes', :present])

    if line[10, :opt] == 0
      line['M.no'] = '*'
      line['M.expl'] = 'No employees'
    else
      raise 'DC wage withholding question not implemented'
    end

    confirm("Your previous year 1065 was not amended or changed.")
    check_box(:N, false)

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

    line[:telephone] = f1065.line['PR.phone'].gsub(/\D/, '')

    compute_form('FR-165')

  end
end
