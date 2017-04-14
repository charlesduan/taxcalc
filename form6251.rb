require 'tax_form'
require 'date'

class Form6251 < TaxForm

  def name
    '6251'
  end

  def compute

    if has_form('1040 Schedule A')
      sched_a = form('1040 Schedule A')
      line[1] = form(1040).line(41)
      line[2] = [
        0,
        [ sched_a.line[4, :opt], (0.025 * form(1040).line[38]).round ].min
      ].max
      line[3] = sched_a.line[9]
      line[4] = @manager.compute_form(MortgageInterestWorksheet).line[6]
      line[5] = sched_a.line[27]

      if form(1040).line[38] <= 155650
        line[6] = 0
      else
        raise 'Itemized Deductions Worksheet not implemented'
      end
    else
      line[1] = form(1040).line(38)
    end

    line[7] = form(1040).line[10]

    l28 = sum_lines(*1..27)
    if form(1040).status.is('mfs') && l28 > 247450
      if l28 > 415050
        line[28] = l28 + 41900
      else
        line[28] = l28 + (0.25 * (l28 - 247450)).round
      end
    else
      line[28] = l28
    end

    if line[28] > form(1040).status.amt_exempt_max
      line[29] = @manager.compute_form(Line29ExemptionWorksheet).line['fill']
    else
      line[29] = form(1040).status.amt_exemption
    end

    line[30] = [ 0, line[28] - line[29] ].max
    if line[30] == 0
      line[31] = line[33] = 0
      line[34] = form(1040).sum_lines(44, 46) - form(1040).line[48]
      line[35] = 0
      return
    end

    l31test = false
    l31test = true if form(1040).line[13] > 0 or form(1040).line('9b') > 0
    if !l31test and has_form('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      l31test = true if sched_d.line[15] > 0 and sched_d.line[16] > 0
    end
    if l31test
      compute_part_iii
      line[31] = line[64]
    elsif form(1040).status.is('mfs')
      if line[30] <= 93150
        line[31] = (0.26 * line[30]).round
      else
        line[31] = (0.28 * line[30]).round - 1863
      end
    else
      if line[30] <= 186300
        line[31] = (0.26 * line[30]).round
      else
        line[31] = (0.28 * line[30]).round - 3726
      end
    end

    assert_interview("Did you pay any foreign taxes?", false)
    assert_no_lines('1099-DIV', 6)
    assert_no_lines('1099-INT', 6)

    line[32] = 0
    line[33] = line[31] - line[32]

    assert_no_forms(4972, '1040 Schedule J')
    line[34] = form(1040).sum_lines(44, 46) - form(1040).line[48, :opt]
    line[35] = [ 0, line[33] - line[34] ].max

  end

end

FilingStatus.set_param('amt_exempt_max', 119700, 159700, 79850, 119700, 159700)
FilingStatus.set_param('amt_exemption', 53900, 83800, 41900, 53900, 83800)



class MortgageInterestWorksheet < TaxForm
  def name
    'Home Mortgage Interest Adjustment Worksheet'
  end

  def compute
    sched_a = form('1040 Schedule A')
    line[1] = sched_a.sum_lines(10, 11, 12, 13)
    if line[1] > 0
      assert_interview('Were all of your Schedule A mortgage deductions ' + \
                       'for eligible mortages (per form 6251)?', true)
      line[2] = forms('1098-INT').lines(1, :sum) + sched_a.sum_lines(11, 13)
    end
    line[5] = sum_lines(2, 3, 4)
    line[6] = line[1] - line[5]
  end
end

class Line29ExemptionWorksheet < TaxForm
  def name
    'Line 29 Exemption Worksheet'
  end

  def compute
    if form(6251).line[28] > form(1040).status.amt_exempt_zero
      line['fill'] = 0
      return
    end
    line[1] = form(1040).status.amt_exemption
    line[2] = form(6251).line[28]
    line[3] = form(1040).status.amt_exempt_max
    line[4] = [ 0, line[2] - line[3] ].max
    line[5] = (line[4] * 0.25).round
    line[6] = [ 0, line[1] - line[5] ].max

    if Date.today.year - Date.parse(form("Personal").line['birthday']).year < 24
      raise 'Special AMT exemption for children under 24 not implemented'
    end
    line['fill'] = line[6]
  end
end

FilingStatus.set_param('amt_exempt_zero', 335300, 494900, 247450, 335300,
                       494900)
