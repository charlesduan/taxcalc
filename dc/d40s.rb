require 'tax_form'
require 'dc/dc_tax_table'

# Supplemental information and dependents. This contains three sub-forms: the
# listing of dependents, the computation of the standard deduction, and the
# splitting for MFSSR.
#
class FormD40S < TaxForm

  include DcTaxTable

  NAME = 'D-40 Schedule S'

  def year
    2024
  end

  def compute
    #
    # Commented out because I'm just using these programs to compute numbers
    #
    #line[:dep_name, :all] = forms('Dependent').lines('name')
    #line[:dep_rel, :all] = forms('Dependent').lines('relationship')
    #line[:dep_tin, :all] = forms('Dependent').lines('ssn').map { |x|
    #  x.gsub(/-/, '')
    #}
    #line[:dep_dob, :all] = forms('Dependent').lines('dob').map { |x|
    #  x.strftime("%m%d%Y")
    #}

    if form('D-40').line[:status] == 'mfssr'
      compute_calculation_j
    end
  end

  def split_calc_j(name, amt)
    line["J.#{name}.m"] = half = (amt / 2).round
    line["J.#{name}.s"] = amt - half
  end

  def add_calc_j(from1, from2, to)
    line["J.#{to}.m"] = line["J.#{from1}.m"] + line["J.#{from2}.m", :opt]
    line["J.#{to}.s"] = line["J.#{from1}.s"] + line["J.#{from2}.s", :opt]
  end
  def sub_calc_j(from1, from2, to)
    line["J.#{to}.m"] = line["J.#{from1}.m"] - line["J.#{from2}.m", :opt]
    line["J.#{to}.s"] = line["J.#{from1}.s"] - line["J.#{from2}.s", :opt]
  end
  def compute_calculation_j
    d40 = form('D-40')

    f1040s = forms(1040)
    case f1040s.count
    when 2
      my1040 = f1040s.find { |f| f.line[:whose] == 'mine' }
      sp1040 = f1040s.find { |f| f.line[:whose] == 'spouse' }
      line['J.a.m'] = my1040.line_agi
      line['J.a.s'] = sp1040.line_agi
    when 1
      #
      # I'm assuming a community property marriage in which all income is
      # community property. If this is not the case, then some sort of manual
      # allocation of the parts of a MFJ return needs to be done here.
      #
      split_calc_j('a', f1040s.lines[:agi, :sum])
    else
      raise 'Strange number of Form 1040s'
    end

    unless d40.sum_lines(5, 6) == 0
      raise 'DC income additions splitting is not implemented'
    end
    add_calc_j(:a, :b, :c)
    unless d40.line[15, :opt] == 0
      raise 'DC income subtractions splitting is not implemented'
    end
    sub_calc_j(:c, :d, :e)

    deduction = d40.line[:ded]
    line['J.f.m'] = optimize_split(deduction)
    line['J.f.s'] = deduction - line['J.f.m']
    sub_calc_j(:e, :f, :g)

    line['J.h.m'] = compute_tax(line['J.g.m'])
    line['J.h.s'] = compute_tax(line['J.g.s'])

    line['J.i/calc_j_tax'] = sum_lines('J.h.m', 'J.h.s')

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
    return true if line[:calc_j_tax, :present]
    return true if line['dep_name', :present]
    return false
  end

end

