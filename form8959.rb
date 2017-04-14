require 'tax_form'

class Form8959 < TaxForm
  def name
    '8959'
  end

  def compute
    line[1] = forms('W-2').lines(5, :sum)

    assert_no_forms(4137, 8919)

    line[4] = sum_lines(*1..3)
    line[5] = form(1040).status.form_8959_limit
    line[6] = [ 0, line[4] - line[5] ].max
    line[7] = (line[6] * 0.009).round

    with_form('1040 Schedule SE') do |sched_se|
      assert_no_forms('1040-PR', '1040-SS')
      line[8] = [ 0, sched_se.line[6] ].max
      line[9] = form(1040).status.form_8959_limit
      line[10] = line[4]
      line[11] = [ 0, line[9] - line[10] ].max
      line[12] = [ 0, line[8] - line[11] ].max
      line[13] = (line[12] * 0.009).round
    end

    assert_no_lines('W-2', 14)

    line[18] = sum_lines(7, 13, 17)

    line[19] = forms('W-2').lines(6, :sum)
    line[20] = line[1]
    line[21] = (line[20] * 0.0145).round
    line[22] = line[19] - line[22]

    line[24] = sum_lines(22, 23)
  end

  def needed?
    return line[18] > 0 && line[24] > 0
  end
end


FilingStatus.set_param('form_8959_limit', 200000, 250000, 125000, 200000,
                       200000)

