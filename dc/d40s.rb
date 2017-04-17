require 'tax_form'
require 'dc/dc_tax_table'

class FormD40S < TaxForm

  include DcTaxTable

  def name
    'D-40 Schedule S'
  end

  def compute
    line['dep_name', :all] = forms('Dependent').lines('name')
    line['dep_rel', :all] = forms('Dependent').lines('relationship')

    status = form('D-40').line[1]
    line['G.a'] = 1
    line['G.b'] = 1 if status == 'hoh'
    assert_question('Were you or your spouse born before 1952 or blind?', false)
    line['G.e'] = line['dep_name', :all].count
    line['G.f'] = 1 if %w(mfj mfssr).include?(status)

    line['G.i'] = sum_lines(*%w(G.a G.b G.c G.d G.e G.f G.g G.h))

    agi = form('D-40').line[14]
    if status == 'mfssr'
      compute_calculation_j
    end
  end

  def compute_calculation_j
    my1040 = forms(1040).select { |f| f.line['whose'] == 'mine' }.first
    sp1040 = forms(1040).select { |f| f.line['whose'] == 'spouse' }.first

    line['J.a.m'] = my1040.line[38]
    line['J.a.s'] = sp1040.line[38]
    unless form('D-40').line[5, :opt] == 0
      raise 'DC income additions splitting is not implemented'
    end
    line['J.c.m'] = sum_lines('J.a.m', 'J.b.m')
    line['J.c.s'] = sum_lines('J.a.s', 'J.b.s')
    unless form('D-40').line[13, :opt] == 0
      raise 'DC income subtractions splitting is not implemented'
    end
    line['J.e.m'] = line['J.c.m'] - line['J.d.m', :opt]
    line['J.e.s'] = line['J.c.s'] - line['J.d.s', :opt]

    deduction_split = interview(
      'Enter fraction of deductions to allocate to yourself:'
    )
    raise 'Invalid split' unless deduction_split >= 0 && deduction_split <= 1
    deduction = form('D-40').line[16]
    line['J.f.m'] = (deduction * deduction_split).round
    line['J.f.s'] = deduction - line['J.f.m']

    exemption_split = interview(
      'Enter number of exemptions to allocate to yourself:'
    )
    unless exemption_split >= 1 && exemption_split < line['G.i']
      raise 'Invalid exemption allocation'
    end
    line['J.g.m'] = exemption_split
    line['J.g.s'] = line['G.i'] - line['J.g.m']

    line['J.h.m'] = 1775 * line['J.g.m'] - exemption_reduction(line['J.e.m'])
    line['J.h.s'] = 1775 * line['J.g.s'] - exemption_reduction(line['J.e.s'])

    line['J.i.m'] = sum_lines('J.f.m', 'J.h.m')
    line['J.i.s'] = sum_lines('J.f.s', 'J.h.s')

    line['J.j.m'] = line['J.e.m'] - line['J.i.m']
    line['J.j.s'] = line['J.e.s'] - line['J.i.s']

    line['J.k.m'] = compute_tax(line['J.j.m'])
    line['J.k.s'] = compute_tax(line['J.j.s'])

    line['J.l'] = sum_lines('J.k.m', 'J.k.s')

  end

  def needed?
    return true if line['J.l', :present]
    return true if line['dep_name', :present]
    exp_exemptions = (%w(mfj mfssr).include?(form('D-40').line[1]) ? 2 : 1)
    return true if line['G.i'] > exp_exemptions
    return false
  end

end

