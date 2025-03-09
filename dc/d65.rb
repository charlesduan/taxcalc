require 'tax_form'
require 'date'
require 'dc/d65_distrib'
require 'dc/fr165'

class FormD65 < TaxForm

  NAME = 'D-65'

  def year
    2024
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
    bio = form('Partnership')
    partners = forms('Partner')

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

    copy_line(1, f1065, from: 'receipts')
    copy_line(2, f1065)
    line[3] = line[1] - line[2, :opt]

    copy_line(4, f1065, from: 'pet_inc')
    copy_line(5, f1065, from: 'farm_inc')
    copy_line(6, f1065, from: 'net_gain')

    # Line 7 has something to do with QOFs; it is assumed that this partnership
    # is not for one. If it were, then Form 1065 Schedule B, line 25 suggests
    # that Form 8996 would be attached.
    if has_form?(8996)
      raise "Qualified Opportunity Fund not implemented"
    end
    copy_line(8, f1065, from: 'other_inc')

    line[9] = sum_lines(3, 4, 5, 6, 7, 8)

    copy_line(10, f1065, from: :wages_ded)
    copy_line(11, f1065, from: :guaranteed_ded)
    copy_line(12, f1065, from: :repairs_ded)
    copy_line(13, f1065, from: :debts_ded)
    copy_line(14, f1065, from: :rents_ded)
    copy_line(15, f1065, from: :licenses_ded)
    copy_line(16, f1065, from: :interest_ded)
    copy_line(17, f1065, from: :depreciation_ded)
    copy_line(18, f1065, from: :depletion_ded)
    copy_line(19, f1065, from: :emp_plan_ded)
    copy_line(20, f1065, from: :emp_benefits_ded)
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

    case bio.line('accounting')
    when 'Cash'     then line['B.cash']    = '*'
    when 'Accrual'  then line['B.accrual'] = '*'
    else
      line['B.other'] = '*'
      line['B.other.expl'] = f1065.line['H.other']
    end

    line[:C] = partners.count
    check_box(:D, bio.line[:type] == 'limited')

    check_box(:E, bio.line[:type] == 'llc')

    partner_types = forms('1065 Schedule K-1').lines('I1')
    check_box(:F, !(partner_types & %w(Corporate Partnership)).empty?)

    confirm("This partnership is not a partner in another partnership")
    check_box(:G, false)

    check_box(:H, !f1065.line[:no_basis_adjustment, :present])
    check_box(:I, @manager.submanager(:last_year).has_form?('D-65'))
    check_box(:J, @manager.submanager(:last_year).has_form?('D-30'))
    check_box(:K, @manager.submanager(:last_year).has_form?('Ballpark Fee'))
    check_box(:L, !f1065.line[:no_1099_needed, :present])

    if line[10, :opt] == 0
      line['M.no'] = '*'
      line['M.expl'] = 'No employees'
    else
      raise 'DC wage withholding question not implemented'
    end

    interview("Your previous year 1065 was not amended or changed.")
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

  end
end
