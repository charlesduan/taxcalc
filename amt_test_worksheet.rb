require 'tax_form'
require 'form6251'

#
# From 1040 instructions, Schedule 2 Line 1
#
class AMTTestWorksheet < TaxForm
  def name
    "Worksheet to See If You Should Fill In Form 6251"
  end

  def year
    2019
  end

  def compute
    f1040 = form(1040)
    with_or_without_form('1040 Schedule A') do |sched_a|
      if sched_a
        line['1yes'] = 'X'
        line[1] = f1040.line_taxinc
        line[2] = sched_a.line_salt
        line[3] = sum_lines(1, 2)
      else
        line['1no'] = 'X'
        line[3] = f1040.line_agi - f1040.line_qbid
      end
    end

    with_form('1040 Schedule 1') do |f|
      line[4] = f.sum_lines(:taxrefund, 8) # Fix line 8 to be just taxes
    end

    line[5] = line[3] - line[4]

    line[6] = f1040.status.amt_exemption
    if line[5] > line[6]
      line['7yes'] = 'X'
      line[7] = line[5] - line[6]
    else
      line['7no'] = 'X'
      line[:fill_no] = 'X'
      return
    end

    line[8] = f1040.status.amt_exempt_max
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

    if line[11] > f1040.status.halve_mfs(194800)
      line['12yes'] = 'X'
      line[:fill_yes] = 'X'
      return
    else
      line['12no'] = 'X'
      line[12] = (line[11] * 0.26).round
    end
    # Schedule J: assumed we are not a farmer or fisherman.
    # I'm assuming no Premium Tax Credit at issue and thus no Schedule 2, line
    # 46.
    line[13] = f1040.line_tax
    if line[12] > line[13]
      line[:fill_yes] = 'X'
    else
      line[:fill_no] = 'X'
    end
  end
end

# amt_exempt_max and amt_exemption values are set in Form 6251
