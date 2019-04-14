require 'tax_form'
require 'dc/dc_tax_table'

# Supplemental information and dependents. This contains three sub-forms: the
# listing of dependents, the computation of the standard deduction, and the
# splitting for MFSSR.
#
class FormD40S < TaxForm

  include DcTaxTable

  def name
    'D-40 Schedule S'
  end

  def year
    2018
  end

  def compute
    line['dep_name', :all] = forms('Dependent').lines('name')
    line['dep_rel', :all] = forms('Dependent').lines('relationship')

    status = form('D-40').line[1]
    if status == 'mfssr'
      compute_calculation_j
    end
  end

  def compute_calculation_j
    my1040 = forms(1040).find { |f| f.line[:whose] == 'mine' }
    sp1040 = forms(1040).find { |f| f.line[:whose] == 'spouse' }

    line['J.a.m'] = my1040.line[7]
    line['J.a.s'] = sp1040.line[7]
    d40 = form('D-40')
    unless d40.line[5, :opt] == 0 && d40.line[4, :opt] == 0
      raise 'DC income additions splitting is not implemented'
    end
    line['J.c.m'] = sum_lines('J.a.m', 'J.b.m')
    line['J.c.s'] = sum_lines('J.a.s', 'J.b.s')
    unless d40.line[13, :opt] == 0
      raise 'DC income subtractions splitting is not implemented'
    end
    line['J.e.m'] = line['J.c.m'] - line['J.d.m', :opt]
    line['J.e.s'] = line['J.c.s'] - line['J.d.s', :opt]

    deduction = form('D-40').line[16]
    line['J.f.m'] = optimize_split(deduction)
    line['J.f.s'] = deduction - line['J.f.m']

    line['J.g.m'] = line['J.e.m'] - line['J.f.m']
    line['J.g.s'] = line['J.e.s'] - line['J.f.s']

    line['J.h.m'] = compute_tax(line['J.g.m'])
    line['J.h.s'] = compute_tax(line['J.g.s'])

    line['J.i'] = sum_lines('J.h.m', 'J.h.s')

  end

  def optimize_split(deduction)
    tax_founds = {}
    (0..deduction).min_by { |my_ded|
      sp_ded = deduction - my_ded
      my_tax = compute_tax(line['J.e.m'] - my_ded)
      sp_tax = compute_tax(line['J.e.s'] - sp_ded)
      tax = my_tax + sp_tax
      unless tax_founds[tax]
        explain("#{my_ded}/#{deduction} deduction split gives tax #{tax}")
        tax_founds[tax] = 1
      end
      tax
    }
  end


  def needed?
    return true if line['J.i', :present]
    return true if line['dep_name', :present]
    return false
  end

end

