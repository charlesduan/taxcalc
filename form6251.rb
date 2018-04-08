require 'tax_form'
require 'date'

class Form6251 < TaxForm

  def name
    '6251'
  end

  def compute
    line[:name] = form(1040).full_name
    line[:ssn] = form(1040).ssn

    if has_form?('1040 Schedule A')
      sched_a = form('1040 Schedule A')
      line[1] = form(1040).line(41)
      # Line 2 removed by legislation
      line[3] = sched_a.line[9]
      line[4] = @manager.compute_form(MortgageInterestWorksheet).line[6]
      line[5] = sched_a.line[27, :opt]

      # The worksheet will be present if Form 1040 line 38 is greater than the
      # itemized deduction limit.
      if has_form?('Itemized Deductions Worksheet')
        line[6] = -1 * form('Itemized Deductions Worksheet').line[9]
      else
        line[6] = 0
      end
    else
      line[1] = form(1040).line(38)
    end

    line[7] = form(1040).line[10, :opt]

    l28 = sum_lines(*1..27)
    # Special adjustment for mfs status; inflation adjusted
    if form(1040).status.is('mfs') && l28 > 249450
      if l28 > 418450
        line[28] = l28 + 42250
      else
        line[28] = l28 + (0.25 * (l28 - 249450)).round
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
    if !l31test and has_form?('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      l31test = true if sched_d.line[15] > 0 and sched_d.line[16] > 0
    end
    if l31test
      compute_part_iii
      line[31] = line[64]
    else
      line[31] = amt_tax(line[30])
    end

    assert_question("Did you pay any foreign taxes?", false)
    assert_no_lines('1099-DIV', 6)
    assert_no_lines('1099-INT', 6)

    line[32] = 0
    line[33] = line[31] - line[32]

    assert_no_forms(4972, '1040 Schedule J')
    line[34] = form(1040).sum_lines(44, 46) - form(1040).line[48, :opt]
    line[35] = [ 0, line[33] - line[34] ].max

  end

  def compute_part_iii
    line[36] = line[30]

    line[37] = compute_from_worksheets(6, 13) { BlankZero }

    with_or_without_form('1040 Schedule D') do |sd|
      line[38] = sd ? sd.line[19, :opt] : BlankZero
    end

    with_or_without_form('Schedule D Tax Worksheet') do |sdtw|
      if sdtw
        line[39] = [ sum_lines(37, 38), sdtw.line[10] ].min
      else
        line[39] = line[37]
      end
    end

    line[40] = [ line[36], line[39] ].min
    line[41] = line[36] - line[40]

    line[42] = amt_tax(line[41])

    line[43] = form(1040).status.amt_cg_exempt
    line[44] = compute_from_worksheets(7, 14) {
      [ 0, form(1040).line(43) ].max
    }

    line[45] = [ 0, line[43] - line[44] ].max
    line[46] = [ line[36], line[37] ].min
    line[47] = [ line[45], line[46] ].min
    line[48] = line[46] - line[47]

    line[49] = form(1040).status.amt_cg_upper

    line[50] = line[45]
    line[51] = compute_from_worksheets(7, 19) {
      [ 0, form(1040).line(43) ].max
    }

    line[52] = sum_lines(50, 51)
    line[53] = [ 0, line[49] - line[52] ].max
    line[54] = [ line[48], line[53] ].min
    line[55] = (line[54] * 0.15).round
    line[56] = sum_lines(47, 54)

    if line[56] != line[36]
      line[57] = line[46] - line[56]
      line[58] = (line[57] * 0.2).round
      if line[38] != 0
        line[59] = sum_lines(41, 56, 57)
        line[60] = line[36] - line[59]
        line[61] = (line[60] * 0.25).round
      end
    end

    line[62] = sum_lines(42, 55, 58, 61)
    line[63] = amt_tax(line[36])
    line[64] = [ line[62], line[63] ].min
  end

  def amt_tax(amount)
    if amount <= form(1040).status.amt_bracket_max
      return (amount * 0.26).round
    else
      return (amount * 0.28).round - form(1040).status.amt_bracket_sub
    end
  end

  def compute_from_worksheets(qdcgt_line, sdtw_line)
    with_or_without_form(
      'Qualified Dividends and Capital Gains Tax Worksheet'
    ) do |qdcgt|
      if qdcgt
        return qdcgt.line[qdcgt_line]
      else
        with_or_without_form('Schedule D Tax Worksheet') do |sdtw|
          if sdtw
            return sdtw.line[sdtw_line]
          else
            return(yield)
          end
        end
      end
    end
  end

end



class MortgageInterestWorksheet < TaxForm
  def name
    'Home Mortgage Interest Adjustment Worksheet'
  end

  def compute
    sched_a = form('1040 Schedule A')
    line[1] = sched_a.sum_lines(10, 11, 12, 13)
    if line[1] > 0
      assert_question('Were all of your Schedule A mortgage deductions ' + \
                       'for eligible mortages (per form 6251)?', true)
      line[2] = line[1]
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

    if interview('Are you under 24?')
      raise 'Special AMT exemption for children under 24 not implemented'
    end
    line['fill'] = line[6]
  end
end

FilingStatus.set_param('amt_exempt_max', 120700, 160900, :half_mfj, :single,
                       :mfj)
FilingStatus.set_param('amt_exemption', 54300, 84500, :half_mfj, :single, :mfj)
FilingStatus.set_param('amt_exempt_zero', 337900, 498900, :half_mfj, :single,
                       :mfj)
FilingStatus.set_param('amt_bracket_max', :mfj, 187800, :half_mfj, :mfj, :mfj)
FilingStatus.set_param('amt_bracket_sub', :mfj, 3756, :half_mfj, :mfj, :mfj)
FilingStatus.set_param('amt_cg_exempt', 37950, 75900, :single, 50800, :mfj)
FilingStatus.set_param('amt_cg_upper', 418400, 470700, :half_mfj, 444550, :mfj)

