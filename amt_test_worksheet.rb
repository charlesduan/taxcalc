require 'tax_form'

class AMTTestWorksheet < TaxForm
  def name
    "Worksheet to See If You Should Fill In Form 6251"
  end

  def compute
    f1040 = form(1040)
    with_or_without_form('1040 Schedule A') do |sched_a|
      if sched_a
        line['1yes'] = 'X'
        line[1] = f1040.line[10]
        line[2] = sched_a.line[7]
        line[3] = sum_lines(1, 2)
      else
        line['1no'] = 'X'
        line[3] = f1040.line[7] - f1040.line[9]
      end
    end

    with_form('1040 Schedule 1') do |f|
      line[4] = f.sum_lines(10, 21)
    end

    line[5] = line[3] - line[4]

    line[6] = f1040.status.amt_exemption
    if line[5] > line[6]
      line['7yes'] = 'X'
      line[7] = line[5] - line[6]
    else
      line['7no'] = 'X'
      line['fillform'] = 'no'
      return
    end

    line[8] = f1040.status.amt_exemption_2
    if line[5] > line[8]
      line['9yes'] = 'X'
      line[9] = line[5] - line[8]
      line[10] = [ line[6], (line[9] * 0.25).round ].min
      line[11] = line[7] + line[10]
    else
      line['9no'] = 'X'
      line[9] = 0
      line[11] = line[7]
    end

    if line[11] > f1040.status.halve_mfs(191100)
      line['12yes'] = 'X'
      line['fillform'] = 'yes'
      return
    else
      line['12no'] = 'X'
      line[12] = (line[11] * 0.26).round
    end
    assert_no_forms('1040 Schedule J')
    # I'm assuming no Premium Tax Credit at issue and thus no Schedule 2, line
    # 46.
    line[13] = f1040.line['11a']
    if line[12] > line[13]
      line['fillform'] = 'yes'
    else
      line['fillform'] = 'no'
    end
  end
end

FilingStatus.set_param('amt_exemption', 70300, 109400, 54700, :single, :mfj)
FilingStatus.set_param(
  'amt_exemption_2', 500000, 1000000, 500000, :single, :mfj
)
