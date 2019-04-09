require 'tax_form'
require 'date'
require 'foreign_tax_credit'

class Form6251 < TaxForm

  def name
    '6251'
  end

  def year
    2018
  end

  def compute
    set_name_ssn

    # If there are 1065 K-1 forms, ensure that they contain no AMT adjustments.
    with_forms('1065 Schedule K-1') do |f|
      if f.line[17, :present]
        raise "Partnership adjustments for AMT not implemented."
      end
    end

    line[1] = form(1040).line[10]

    # Schedule A tax deduction, or 1040 standard deduction.
    with_or_without_form('1040 Schedule A') do |f|
      if f
        line['2a'] = f.line[7]
      else
        line['2a'] = form(1040).line[8]
      end
    end

    with_form('1040 Schedule 1') do |f|
      if f.line[10, :present]
        assert_question(
          "Are all the amounts on Schedule 1, line 10 for state/local taxes?",
          true
        )
        if f.line[21, :present]
          raise "AMT adjustment for Schedule 1, line 21 not implemented"
          # This is also relevant to line 2e below
        end
        line['2b'] = -f.line[10]
      end
    end

    with_form(4952) do |f|
      raise "Form 6251, line 2c (Form 4952 Investment Interest) not implemented"
    end

    # 2d: Depletion not implemented; only for mining, timber, etc.
    # 2e: NOL deduction not implemented; we assumed Schedule 1 line 21 is blank.
    #     (Net operating loss refers to situations where deductions exceed
    #     income.)
    # 2f: ATNOL not implemented so no deduction can be taken.

    # 2g: Private activity bonds
    line['2g'] = forms('1099-INT').lines(9, :sum) + \
      forms('1099-DIV').lines(12, :sum)
    if has_form?(8814)
      raise "Form 6251, line 2g inclusion of From 8814 not implemented"
    end

    # 2h: qualified small business stock
    l2h = BlankZero
    with_forms(8949) do |f|
      %w(I II).each do |part|
        f_line, g_line = "#{part}.1f", "#{part}.1g"
        next unless f.line[f_part, :present]
        f.line[f_part, :all].zip(f.line[g_part, :all]).each do |x|
          l2h += x[1] if x[0] == 'Q' # line 1f flag for QSBS exclusion
        end
      end
    end
    line['2h'] = l2h

    # 2i: incentive stock options.
    if has_form?(3921)
      raise "Incentive stock options not implemented"
    end

    # 2j: estates/trusts
    l2j = BlankZero
    with_forms('1041 Schedule K-1') do |f|
      if f.line[12, :present]
        f.line['12.code', :all].zip(f.line[12, :all]).each do |x|
          l2j += x[1] if x[1] == 'A'
        end
      end
    end
    line['2j'] = l2j

    # 2l: depreciation adjustments.
    with_form(4562) do |f|
      %w(
        14 15 16 17 19a.g 19b.g 19c.g 19d.g 19e.g 19f.g 19h.g 19i.g 20a.g 20b.g
        20c.g 20d.g 21
      ).each do |l|
        if f.line[l, :present]
          raise "AMT depreciation adjustment not implemented"
        end
      end
    end
    line['2l'] = BlankZero

    # 2k: adjustments for disposition of property. I think that this should be
    # zero if lines 2i and 2l are zero.
    #
    raise "Line 2k not implemented" if %w(2i 2l).any? { |l|
      line[l, :present] && line[l] != 0
    }
    line['2k'] = BlankZero

    place_lines('2l')

    # 2m: passive activity loss. It is assumed that there aren't any passive
    # activities.
    # 2n: loss limitations. It is assumed that no losses were posted; if they
    # were, then any limitations on losses need to be recalculated.
    # 2o: circulation costs. It is assumed that the individual owns no
    # periodicals.
    # 2p: long-term contracts. These are contracts for the construction of
    # property that will take more than a year. It is assumed there are none.
    # 2q: mining costs. Assumed there are none.
    # 2r: research/experimental costs. Assumed there are none.
    # 2s: installment sales in 1986. Assumed there are none.
    # 2t: intangible drilling costs. Assumed there are none.
    #
    # 3: Other adjustments. Assumed there aren't any. The Related Adjustments
    # might be affected but this is unlikely.
    %w(2c 2d 2h 2i 2k 2l 2m 2n 2o 2p 2q 2r 2s 2t).each do |l|
      if line[l, :present] && line[l] != 0
        raise "Line 3 Related Adjustments may need to be computed"
      end
    end

    line[4] = sum_lines(*%w(
      1 2a 2b 2c 2d 2e 2f 2g 2h 2i 2j 2k 2l 2m 2n 2o 2p 2q 2r 2s 2t 3
    ))
    if form(1040).status.is('mfs') && line[4] > 718800
      raise "Form 6251 Line 4 adjustment not implemented"
    end
    with_form('1040 Schedule E') do |f|
      if f.line['38c', :present]
        raise "Form 6251 Line 4 REMIC adjustment not implemented"
      end
    end

    # AMT computation

    # Several things depend on the foreign tax credit computation.
    @ftc_form = compute_form(ForeignTaxCredit)

    # Compute the exemption.
    if line[4] > form(1040).status.amt_exempt_max
      line[5] = @manager.compute_form(Line5ExemptionWorksheet).line['fill']
    else
      line[5] = form(1040).status.amt_exemption
    end

    # Compute the balance over the exemption.
    line[6] = [ 0, line[4] - line[5] ].max
    if line[6] == 0
      line[9] = line[7] = 0
      compute_line_10
      line[11] = 0
      return
    end

    # Line 7
    if has_form?(2555)
      raise "Form 6251 does not implement Form 2555 computation"
    end
    l7test = false
    if form(1040).line['3a'] > 0
      l7test = true
    else
      with_form('1040 Schedule 1') do |f|
        l7test = true if f.line[13] > 0
      end
      with_form('1040 Schedule D') do |f|
        l7test = true if f.line[15] > 0 and f.line[16] > 0
      end
    end

    if l7test
      compute_part_iii
      line[7] = line[40]
    else
      line[7] = amt_tax(line[6])
    end

    # AMT foreign tax credit
    if @ftc_form
      if has_form?(1116)
        raise "AMT foreign tax credit with Form 1116 not implemented"
      else
        line[8] = @ftc_form.line[:send]
      end
    end

    # AMT
    line[9] = line[7] - line[8, :opt]

    compute_line_10

    # AMT additional tax
    line[11] = [ 0, line[9] - line[10] ].max

    place_lines(*12..40) if line[12, :present]

  end

  def compute_line_10
    l10 = form(1040).line['11a']
    with_form(4972) do |f|
      if f.line[30, :present]
        l10 -= f.line[30]
      elsif f.line[7, :present]
        l10 -= f.line[7]
      end
    end
    with_form('1040 Schedule 2') do |f|
      l10 += f.line[46]
    end
    l10 -= @ftc_form.send if @ftc_form
    if has_form?('1040 Schedule J')
      raise 'Form 6251, Line 10 does not implement Schedule J computation'
    end
    line[10] = l10
  end

  def compute_part_iii
    line[12] = line[6]

    check_line_13_conds
    line[13] = compute_from_worksheets(6, 13) { BlankZero }
    with_or_without_form('1040 Schedule D') do |sd|
      line[14] = sd ? sd.line[19, :opt] : BlankZero
    end
    with_or_without_form('Schedule D Tax Worksheet') do |sdtw|
      if sdtw
        line[15] = [ sum_lines(13, 14), sdtw.line[10] ].min
      else
        line[15] = line[13]
      end
    end

    line[16] = [ line[12], line[15] ].min
    line[17] = line[12] - line[16]

    line[18] = amt_tax(line[17])

    line[19] = form(1040).status.amt_cg_exempt
    line[20] = compute_from_worksheets(7, 14) {
      [ 0, form(1040).line(10) ].max
    }

    line[21] = [ 0, line[19] - line[20] ].max
    line[22] = [ line[12], line[13] ].min
    line[23] = [ line[21], line[22] ].min
    line[24] = line[22] - line[23]

    line[25] = form(1040).status.amt_cg_upper

    line[26] = line[21]
    line[27] = compute_from_worksheets(7, 19) {
      [ 0, form(1040).line(10) ].max
    }

    line[28] = sum_lines(26, 27)
    line[29] = [ 0, line[25] - line[28] ].max
    line[30] = [ line[24], line[29] ].min
    line[31] = (line[30] * 0.15).round
    line[32] = sum_lines(23, 30)

    if line[32] != line[12]
      line[33] = line[22] - line[32]
      line[34] = (line[33] * 0.2).round
      if line[14] != 0
        line[35] = sum_lines(17, 32, 33)
        line[36] = line[12] - line[35]
        line[37] = (line[36] * 0.25).round
      end
    end

    line[38] = sum_lines(18, 31, 34, 37)
    line[39] = amt_tax(line[12])
    line[40] = [ line[38], line[39] ].min
  end

  def check_line_13_conds
    cond1 = (line['2l', :opt] != 0 || line['2i', :opt] != 0)
    cond2 = (form(1040).line[10] == 0)
    cond3 = false
    with_form('1041 Schedule K-1') do |f|
      cond3 = true if !(line['12.code', :all] & %w(B C D E F)).empty?
    end
    if cond1 or cond2 or cond3
      raise "Nonstandard Form 6251, Line 13 not implemented"
    end
  end

  def amt_tax(amount)
    if amount <= form(1040).status.halve_mfs(191100)
      return (amount * 0.26).round
    else
      return (amount * 0.28).round - form(1040).status.halve_mfs(3822)
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



class Line5ExemptionWorksheet < TaxForm
  def name
    'Line 5 Exemption Worksheet'
  end

  def year
    2018
  end

  def compute
    if form(6251).line[28] > form(1040).status.amt_exempt_zero
      line['fill'] = 0
      return
    end
    line[1] = form(1040).status.amt_exemption
    line[2] = form(6251).line[4]
    line[3] = form(1040).status.amt_exempt_max
    line[4] = [ 0, line[2] - line[3] ].max
    line[5] = (line[4] * 0.25).round
    line[6] = [ 0, line[1] - line[5] ].max

    if age < 24
      raise 'Special AMT exemption for children under 24 not implemented'
    end
    line['fill'] = line[6]
  end
end

FilingStatus.set_param('amt_exempt_max', 500000, 1000000, :half_mfj, :single,
                       :mfj)
FilingStatus.set_param('amt_exemption', 70300, 109400, :half_mfj, :single, :mfj)
FilingStatus.set_param('amt_exempt_zero', 781200, 1437600, :half_mfj, :single,
                       :mfj)
FilingStatus.set_param('amt_cg_exempt', 38600, 77200, :single, 51700, :mfj)
FilingStatus.set_param('amt_cg_upper', 425800, 479000, :half_mfj, 452400, :mfj)
