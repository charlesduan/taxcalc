require 'tax_form'

#
# Net Investment Income Tax
#
class Form8960 < TaxForm

  NAME = '8960'

  def year
    2023
  end

  def needed?
    return form(1040).line[:agi] > form(1040).status.niit_threshold
  end

  def compute
    return unless needed?

    set_name_ssn

    line[1] = form(1040).line[:taxable_int]
    line[2] = form(1040).line[:taxable_div]

    annuities = forms('1099-R') { |x| x.line[7] == 'D' }
    if annuities.any? { |x| x.line['2b.not_determined?'] }
      raise "Annuity amounts taxable not determined"
    else
      line[3] = annuities.lines('2a', :sum)
    end

    # Rental real estate, partnerships, trusts
    line['4a'] = form('1040 Schedule 1').sum_lines(:bus_inc, :rrerpst)

    # Adjustments for non-passive income
    line4b = 0
    with_form('1040 Schedule E') do |f|
      # We assume that any partnerships listed on 1040 Schedule E, part II that
      # involve nonpassive income/losses are section 162 businesses (i.e.,
      # businesses for which business expense deductions may be taken), and are
      # also not in the business of trading financial instruments or
      # commodities.
      line4b = -(f.line[:pship_nonpassive_inc, :opt] \
                     - f.sum_lines(*%w(pship_nonpassive_loss pship_179_ded)))
    end
    with_form('1040 Schedule C') do |f|
      raise "Need to deduct Schedule C non-passive income"
    end
    line['4b'] = line4b

    line['4c'] = line['4a'] + line['4b']

    # This needs to be limited to other income
    line['5a'] = form(1040).line[:cap_gain, :opt] +
      form('1040 Schedule 1').line[:other_gains, :opt]
    line['5d'] = sum_lines('5a', '5b', '5c')

    # Total investment income
    line[8] = sum_lines(1, 2, 3, '4c', '5d', 6, 7)

    # Part II

    with_form('1040 Schedule A') do |f|
      line['9a'] = f.line[:inv_int, :opt]

      # The view appears to be that the excludable expense is calculated first
      # based on the full tax, and then the $10,000 limit is applied to that.
      l9b = f.line[:salt_all] -
        (f.line['5a.sales', :present] ? f.line[:salt_inc] : 0)
      l9b *= 1.0 * line[8] / form(1040).line_agi
      line['9b'] = [ l9b.round, f.line[:salt_lim] ].min
    end
    with_form(4954) do |f|
      line['9c'] = f.line[5]
    end
    line['9d'] = sum_lines('9a', '9b', '9c')

    if year > 2025
      raise "Consider miscellaneous itemized deductions from NIIT"
    end

    line[11] = sum_lines('9d', 10)

    # Part III

    line[12] = [ 0, line[8] - line[11] ].max
    line[13] = form(1040).line[:agi]

    line[14] = form(1040).status.niit_threshold

    line[15] = [ 0, line[13] - line[14] ].max

    line[16] = [ line[12], line[15] ].min
    line['17/niit'] = (line[16] * 0.038).round

  end
end

# Not inflation adjusted
FilingStatus.set_param('niit_threshold',
                       single: 200000, mfj: 250000, mfs: 125000,
                       hoh: 200000, qw: 250000)
