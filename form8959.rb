require 'tax_form'

# Additional Medicare Tax
class Form8959 < TaxForm
  NAME = '8959'

  def year
    2020
  end

  def compute
    set_name_ssn

    # Wages
    line[1] = forms('W-2').lines(5, :sum)
    with_form(4317) do |f| line[2] = f.line[6] end
    with_form(8919) do |f| line[3] = f.line[6] end
    line[4] = sum_lines(*1..3)

    line[5] = form(1040).status.form_8959_limit
    line[6] = [ 0, line[4] - line[5] ].max
    line[7] = (line[6] * 0.009).round

    with_form('1040 Schedule SE') do |sched_se|
      # Forms 1040-PR or 1040-SS may be required if the self-employed person
      # lives in a US territory.
      line[8] = [ 0, sched_se.line[:se_inc] ].max
      line[9] = form(1040).status.form_8959_limit
      line[10] = line[4]
      line[11] = [ 0, line[9] - line[10] ].max
      line[12] = [ 0, line[8] - line[11] ].max
      line[13] = (line[12] * 0.009).round
    end

    if forms('W-2').any? { |w2| w2.line[14, :present] }
      raise "RRTA compensation additional medicare tax not implemented"
    end

    line[18] = sum_lines(7, 13, 17)

    line[19] = forms('W-2').lines(6, :sum)
    line[20] = line[1]
    line[21] = (line[20] * 0.0145).round
    line[22] = [ 0, line[19] - line[21] ].max

    # Line 23 relates to RRTA withholding; not implemented per above

    line[24] = sum_lines(22, 23)
  end

  def needed?
    return true if line[1] > 200_000
    return true if sum_lines(4, 8) > line[5]
    return false
  end
end


FilingStatus.set_param('form_8959_limit',
                       single: 200000, mfj: 250000, mfs: 125000, hoh: :single,
                       qw: :single)

