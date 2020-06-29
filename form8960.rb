require 'tax_form'

# Net Investment Income Tax
class Form8960 < TaxForm

  def name
    '8960'
  end

  def year
    2019
  end

  def compute
    set_name_ssn

    line[1] = form(1040).line['2b']
    line[2] = form(1040).line['3b']

    annuities = forms('1099-R') { |x| x.line[7] == 'D' }
    if annuities.any? { |x| x.line['2b.not_determined?'] }
      raise "Annuity amounts taxable not determined"
    else
      line[3] = annuities.lines('2a', :sum)
    end

    # Rental real estate, partnerships, trusts
    line['4a'] = form('1040 Schedule 1').line[5]
    with_form('1040 Schedule E') do |f|
      # We assume that any partnerships listed on 1040 Schedule E, part II that
      # involve nonpassive income/losses are section 162 businesses (i.e.,
      # businesses for which business expense deductions may be taken), and are
      # also not in the business of trading financial instruments or
      # commodities.
      line['4b'] = -(f.line['29a.k', :opt] - f.sum_lines(*%w(29b.i 29b.j)))
    end
    line['4c'] = line['4a'] + line['4b']

    line['5a'] = form(1040).line_6 + form('1040 Schedule 1').line[4, :opt]
    line['5d'] = sum_lines('5a', '5b', '5c')

    # Total investment income
    line[8] = sum_lines(1, 2, 3, '4c', '5d', 6, 7)

    with_form('1040 Schedule A') do |f|
      line['9a'] = f.line[9, :opt]

      # The view appears to be that the excludable expense is calculated first
      # based on the full tax, and then the $10,000 limit is applied to that.
      l9b = f.line['5d'] - (f.line['5a.sales', :present] ? f.line['5a'] : 0)
      l9b *= 1.0 * line[8] / form(1040).line_agi
      line['9b'] = [ l9b.round, f.line['5e'] ].min
    end
    with_form(4954) do |f|
      line['9c'] = f.line[5]
    end
    line['9d'] = sum_lines('9a', '9b', '9c')

    line[11] = sum_lines('9d', 10)

    line[12] = [ 0, line[8] - line[11] ].max
    line[13] = form(1040).line_agi

    line[14] = form(1040).status.niit_threshold

    line[15] = [ 0, line[13] - line[14] ].max

    line[16] = [ line[12], line[15] ].min
    line[17] = (line[16] * 0.038).round

  end
end
