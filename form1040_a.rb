require_relative 'tax_form'
require_relative 'form8283'

class Form1040A < TaxForm

  NAME = '1040 Schedule A'

  def year
    2020
  end

  def compute
    set_name_ssn

    # Medical expenses not implemented
    line['4/med_ded'] = BlankZero

    line['5a/salt_inc'] = forms('State Tax').lines(:amount, :sum) + \
      forms('W-2').lines(17, :sum)
    line['5b/salt_real'] = forms('1098').lines(10, :sum)
    line['5d/salt_all'] = sum_lines(*%w(5a 5b 5c))
    line['5e/salt_lim'] = [
      form(1040).status.halve_mfs(10_000), line['5d']
    ].min

    # This is for foreign taxes and the GST. The former is better dealt with as
    # a credit; the latter applies only to transfers of over $11 million.
    line['6/other_tax'] = BlankZero

    line['7/salt'] = sum_lines('5e', 6)

    compute_mortgage_interest

    confirm("You did not have any investment interest")
    line['9/inv_int'] = BlankZero
    line[10] = sum_lines('8e', 9)

    cg = forms('Charity Gift')
    cg.each do |f|
      if f.line[:amount] >= 250 && !f.line[:documented?]
        raise "Charity gift over $250 not documented"
      end
    end

    line[11] = forms('Charity Gift') { |f|
      f.line[:cash?]
    }.lines(:amount, :sum).round
    line[12] = forms('Charity Gift') { |f|
      !f.line[:cash?]
    }.lines(:amount, :sum).round

    if line[12] > 500
      find_or_compute_form(8283)
    end

    line[14] = sum_lines(11, 12, 13)
    if line[14] > 0.2 * form(1040).line_agi
      raise "Pub. 526 limit on charitable contributions not implemented"
    end

    confirm('You had no casualty or theft losses')
    line['15/cas_theft'] = BlankZero

    line['17/total'] = sum_lines(4, 7, 10, 14, 15, 16)

    if line[17] < form(1040).status.standard_deduction
      line[18] = 'X'
    end

  end

  def compute_mortgage_interest
    confirm("You did not receive non-1098 mortgage interest")

    # This calculates the various limits on home mortgage interest
    # deductibility.
    compute_form('Pub. 936 Home Mortgage Interest Worksheet') do |p936w|
      if p936w.line[16] != 0
        raise "Not able to handle mortgage interest deduction limit"
      end
      line['8a'] = p936w.line[:ded_hm_int] if p936w
    end

    #
    # There is some complicated business involving apportioning home mortgage
    # interest where there is a home office, if the non-simplified calculation
    # for the home office deduction is used. Since that also triggers recapture
    # at the time the home is sold, I assume that only the simplified method
    # will be used.
    #
    unless forms('Home Office').all? { |f| f.line[:method] == 'simplified' }
      raise "Cannot yet handle adjustment of Schedule A for home offices"
    end

    line['8e'] = sum_lines(*%w(8a 8b 8c))

  end
end

#
# Computes what portion of home mortgage interest is deductible. So far, I have
# not hit the limits (line 16) and so have not implemented some features, such
# as average mortgage balance, that could lower the computation.
#
class Pub936Worksheet < TaxForm
  NAME = 'Pub. 936 Home Mortgage Interest Worksheet'

  def year
    2020
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

    # TODO: This uses line 2 for the mortgage principal, although a smaller
    # number could correctly be used per the instructions.
    grandfathered, pre_tcja, post_tcja = 0, 0, 0
    f1098s.each do |f1098|
      p = f1098.match_form('Real Estate', :property)
      if p.line[:purchase_date] <= Date.new(1987, 10, 13)
        grandfathered += f1098.line[2]
      elsif p.line[:purchase_date] < Date.new(2017, 12, 16)
        pre_tcja += f1098.line[2]
      else
        post_tcja += f1098.line[2]
      end
    end
    s = form(1040).status

    line[1] = grandfathered
    line[2] = pre_tcja
    line[3] = s.halve_mfs(1_000_000)
    line[4] = [ line[1], line[3] ].max
    line[5] = sum_lines(1, 2)
    line[6] = [ line[4], line[5] ].min
    if post_tcja == 0 or line[6] >= s.halve_mfs(750_000)
      line[11] = line[6]
    else
      line[7] = post_tcja
      line[8] = s.halve_mfs(750_000)
      line[9] = [ line[6], line[8] ].max
      line[10] = sum_lines(6, 7)
      line[11] = [ line[9], line[10] ].min
    end
    line[12] = sum_lines(1, 2, 7)
    line[13] = f1098s.lines(1, :sum) + f1098s.lines(6, :sum)
    if line[11] >= line[12]
      line['15/ded_hm_int'] = line[13]
      line[16] = 0
    else
      line[14] = (1.0 * line[11] / line[12]).round(3)
      line['15/ded_hm_int'] = (line[13] * line[14]).round
      line[16] = line[13] - line[15]
      if line[16] > 0
        raise "You should refine the Pub. 936 Worksheet implementation"
      end
    end
  end

  # The form is needed if any interest is deductible.
  def needed?
    line[:ded_hm_int, :present]
  end

end

