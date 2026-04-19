require_relative 'tax_form'

#
# Computes what portion of home mortgage interest is deductible. So far, I have
# not hit the limits (line 16) and so have not implemented some features, such
# as average mortgage balance, that could lower the computation.
#
class Pub936Worksheet < TaxForm
  NAME = 'Pub. 936 Home Mortgage Interest Worksheet'

  def year
    2025
  end

  def compute

    #
    # It is assumed that all 1098-reported debt is for home acquisitions (i.e.,
    # not buying a car or other non-home) and that there are no mixed-use
    # mortgages (e.g., refinanced grandfathered debt with additional amounts
    # taken out so some of the debt is grandfathered and the rest isn't).
    #
    f1098s = forms(1098) { |f| f.line[:property, :present] }
    return if f1098s.empty?

    # Check that every 1098 form has a property
    props = forms('Real Estate')
    f1098s.each do |f|
      unless props.any? { |pf| pf.line[:property] == f.line[:property] }
        raise("No Real Estate form for #{f[:property]}")
      end
    end


    grandfathered, pre_tcja, post_tcja = 0, 0, 0
    props.each do |prop|
      avg = (prop.line[:start_principal] + prop.line[:end_principal]) / 2
      if prop.line[:origination_date] <= Date.new(1987, 10, 13)
        grandfathered += avg
      elsif prop.line[:origination_date] < Date.new(2017, 12, 16)
        pre_tcja += avg
      else
        post_tcja += avg
      end
    end
    s = form(1040).status

    line['1/grandfathered_principal'] = grandfathered
    line['2/pre_tcja_principal'] = pre_tcja
    line[3] = s.halve_mfs(1_000_000)
    line[4] = [ line[1], line[3] ].max
    line[5] = sum_lines(1, 2)
    line[6] = [ line[4], line[5] ].min
    if post_tcja == 0 or line[6] >= s.halve_mfs(750_000)
      line[11] = line[6]
    else
      line['7/post_tcja_principal'] = post_tcja
      line[8] = s.halve_mfs(750_000)
      line[9] = [ line[6], line[8] ].max
      line[10] = sum_lines(6, 7)
      line[11] = [ line[9], line[10] ].min
    end
    line[12] = sum_lines(1, 2, 7)
    line['13/tot_int_points'] = f1098s.lines(1, :sum) + f1098s.lines(6, :sum)
    if line[11] >= line[12]
      # Interest is below limit
      line['15/ded_hm_int'] = line[13]
      line[16] = 0
    else
      # Interest is above limit
      line[14] = (1.0 * line[11] / line[12]).round(3)
      line['15/ded_hm_int'] = (line[13] * line[14]).round
      line[16] = line[13] - line[15]
    end
  end

  # The form is needed if any interest is deductible.
  def needed?
    line[:ded_hm_int, :present]
  end

end


