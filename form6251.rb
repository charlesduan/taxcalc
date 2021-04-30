require 'tax_form'
require 'date'
require 'foreign_tax_credit'

#
# Alternative Minimum Tax
#
class Form6251 < TaxForm

  NAME = '6251'

  def year
    2019
  end

  def compute
    set_name_ssn

    # If there are 1065 K-1 forms, ensure that they contain no AMT adjustments.
    with_forms('1065 Schedule K-1') do |f|
      if f.line[17, :present]
        raise "Partnership adjustments for AMT not implemented."
      end
    end

    line[1] = form(1040).line_taxinc

    # Schedule A tax deduction, or 1040 standard deduction.
    with_or_without_form('1040 Schedule A') do |f|
      if f
        line['2a'] = f.line_salt
      else
        line['2a'] = form(1040).line_deduction
      end
    end

    with_form('1040 Schedule 1') do |f|
      # 2b: undoing income attributed to state/local income tax refunds
      if f.line[:taxrefund, :present]
        # It is assumed that all amounts in Schedule 1, line 1 relate to income
        # taxes, because that is all that is presently implemented. There is a
        # comment in that form as a reminder to update this computation if that
        # changes.

        if f.line[8, :present]
          raise "AMT adjustment for Schedule 1, line 8 not implemented"
          # This is also relevant to line 2e below
        end
        line['2b'] = -f.line_taxrefund
      end
    end

    with_form(4952) do |f|
      raise "Form 6251, line 2c (Form 4952 Investment Interest) not implemented"
    end

    # 2d: Depletion not implemented; only for mining, timber, etc.
    # 2e: NOL deduction not implemented; we assumed Schedule 1 line 8 is blank.
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
    with_forms(8949) do |f|
      %w(I II).each do |part|
        f_line, g_line = "#{part}.1f", "#{part}.1g"
        if f.line[f_part, :all].include?("Q")
          raise "AMT adjustment for QSBS not implemented"
        end
        # Because this appears only to apply to stock acquired before September
        # 28, 2010, this code is unlikely ever to be used, so I am commenting it
        # out so that I don't need to maintain it.
        #
        # next unless f.line[f_part, :present]
        # f.line[f_part, :all].zip(f.line[g_part, :all]).each do |x|
        #   l2h += x[1] if x[0] == 'Q' # line 1f flag for QSBS exclusion
        # end
      end
    end
    # line['2h'] = l2h

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

    # 2k: adjustments for disposition of property.
    #
    %w(4797 4684 8949).each do |f|
      raise "Line 2k not implemented with form #{f}" if has_form?(f)
    end

    # 2l: depreciation adjustments.
    with_form(4562) do |f|
      # These should be all the right-hand columns of Form 4562 starting with
      # Part II.
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
    assert_question("Do you have other adjustments for AMT (line 3)?", false)

    line[4] = sum_lines(*%w(
      1 2a 2b 2c 2d 2e 2f 2g 2h 2i 2j 2k 2l 2m 2n 2o 2p 2q 2r 2s 2t 3
    ))
    if form(1040).status.is('mfs') && line[4] > 733700
      raise "Form 6251 Line 4 adjustment not implemented"
    end
    with_form('1040 Schedule E') do |f|
      if f.line['38c', :present]
        raise "Form 6251 Line 4 REMIC adjustment not implemented"
      end
    end

    # AMT computation

    # Several things depend on the foreign tax credit computation.
    @ftc_form = compute_form('Foreign Tax Credit')

    # Compute the exemption.
    if line[4] > form(1040).status.amt_exempt_max
      line[5] = @manager.compute_form('Line 5 Exemption Worksheet').line[6]
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
    assert_question("Did you have any foreign income?", false)
    l7test = false
    if form(1040).line_qualdiv > 0
      l7test = true
    else
      with_form(1040) do |f|
        l7test = true if f.line[6] > 0
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
        line[8] = @ftc_form.line[:fill!]
      end
    end

    # AMT
    line[9] = line[7] - line[8, :opt]

    compute_line_10

    # AMT additional tax
    line['11/amt_tax'] = [ 0, line[9] - line[10] ].max

    place_lines(*12..40) if line[12, :present]

  end

  def compute_line_10
    l10 = form(1040).line_tax
    with_form(4972) do |f|
      if f.line[30, :present]
        l10 -= f.line[30]
      elsif f.line[7, :present]
        l10 -= f.line[7]
      end
    end
    with_form('1040 Schedule 2') do |f|
      l10 += f.line[2]
    end
    with_form('1040 Schedule 3') do |f|
      l10 -= f.line_1
    end
    l10 -= @ftc_form.line[:fill!] if @ftc_form

    assert_question("Are you a farmer or fisherman?", false)

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
      [ 0, form(1040).line_11b ].max
    }

    line[21] = [ 0, line[19] - line[20] ].max
    line[22] = [ line[12], line[13] ].min
    line[23] = [ line[21], line[22] ].min
    line[24] = line[22] - line[23]

    line[25] = form(1040).status.amt_cg_upper

    line[26] = line[21]
    line[27] = compute_from_worksheets(7, 21) {
      [ 0, form(1040).line_11b ].max
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
    cond2 = (form(1040).line_taxinc == 0)
    cond3 = false
    with_form('1041 Schedule K-1') do |f|
      cond3 = true if !(line['12.code', :all] & %w(B C D E F)).empty?
    end
    if cond1 or cond2 or cond3
      raise "Nonstandard Form 6251, Line 13 not implemented"
    end
  end

  def amt_tax(amount)
    if amount <= form(1040).status.halve_mfs(194_800)
      return (amount * 0.26).round
    else
      return (amount * 0.28).round - form(1040).status.halve_mfs(3896)
    end
  end

  #
  # Returns the requested line from the QDCGT worksheet if that's present; if
  # not returns the requested line from the Schedule D Tax Worksheet if that's
  # present; if not yields and returns that.
  #
  def compute_from_worksheets(qdcgt_line, sdtw_line)
    with_or_without_form(
      'Qualified Dividends and Capital Gains Tax Worksheet'
    ) do |qdcgt|
      return qdcgt.line[qdcgt_line] if qdcgt
    end
    with_or_without_form('Schedule D Tax Worksheet') do |sdtw|
      return sdtw.line[sdtw_line] if sdtw
    end
    return(yield)
  end

end



class Line5ExemptionWorksheet < TaxForm
  NAME = 'Line 5 Exemption Worksheet'

  def year
    2019
  end

  def compute
    if form(6251).line[4] > form(1040).status.amt_exempt_zero
      line[6] = 0
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
  end
end

# Parameter order reminder: set_param(single, mfj, mfs, hoh, qw)
FilingStatus.set_param('amt_exempt_max', 510_300, 1_020_600, :half_mfj, :single,
                       :mfj)
FilingStatus.set_param('amt_exemption', 71_700, 111_700, :half_mfj, :single,
                       :mfj)
FilingStatus.set_param('amt_exempt_zero', 797_100, 1_467_400, :half_mfj,
                       :single, :mfj)
FilingStatus.set_param('amt_cg_exempt', 39_375, 78_750, :single, 52_750, :mfj)
FilingStatus.set_param('amt_cg_upper', 434_550, 488_850, :half_mfj, 461_700,
                       :mfj)

