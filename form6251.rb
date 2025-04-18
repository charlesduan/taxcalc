require 'tax_form'
require 'date'
require 'foreign_tax_credit'

#
# Alternative Minimum Tax
#
class Form6251 < TaxForm

  NAME = '6251'

  def year
    2024
  end

  def compute
    set_name_ssn

    # If there are 1065 K-1 forms, ensure that they contain no AMT adjustments.
    with_forms('1065 Schedule K-1') do |f|
      if f.line[17, :present]
        raise "Partnership adjustments for AMT not implemented."
      end
    end

    line[1] = form(1040).line[:taxinc]

    # Schedule A tax deduction, or 1040 standard deduction.
    line['2a'] = with_form('1040 Schedule A', otherwise: proc {
      form(1040).line[:deduction]
    }) do |f|
      f.line[:salt]
    end

    with_form('1040 Schedule 1') do |f|
      # 2b: undoing income attributed to state/local income tax refunds
      if f.line[:taxrefund, :present]
        # It is assumed that all amounts in Schedule 1, line 1 relate to income
        # taxes, because that is all that is presently implemented. There is a
        # comment in that form as a reminder to update this computation if that
        # changes.

        # We do a very coarse check for whether other tax on Schedule 1 includes
        # SALT refunds.
        if f.line[:other_inc, :present] && f.line[:other_inc_expl] =~ /refund/i
          raise "AMT adjustment for Schedule 1, line 8 not implemented"
          # This is also relevant to line 2e below
        end
        line['2b'] = -f.line[:taxrefund] - f.line[:other_tax, :opt]
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
      %w(I II).each do |f_part|
        f_line, g_line = "#{f_part}.1f", "#{f_part}.1g"
        if f.line[f_line, :present] && f.line[f_line, :all].include?("Q")
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
    %w(4797 4684).each do |f|
      raise "Line 2k not implemented with form #{f}" if has_form?(f)
    end

    if has_form?(8949)
      #
      # Sales of stock purchased via an ISO have a different basis for AMT
      # purposes, which would have been reported on a previous year's Form 3921.
      # Ideally, the stock sale form should include the AMT basis, or this
      # program should look back to previous Form 3921s received.
      #
      if interview("Did you sell any ISO-purchased stock?")
        raise "Like 2k not implemented with form 8949"
      end
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
    confirm("You have no other adjustments for AMT (line 3)")

    line['4/amt_inc'] = sum_lines(1, 3, *'2a'..'2z')
    if form(1040).status.is('mfs') && line[4] > 875_950
      raise "Form 6251 Line 4 adjustment not implemented"
    end
    with_form('1040 Schedule E') do |f|
      if f.line['38c', :present]
        raise "Form 6251 Line 4 REMIC adjustment not implemented"
      end
    end

    # AMT computation

    # Several things depend on the foreign tax credit computation.
    @ftc_form = find_or_compute_form('Foreign Tax Credit')

    # Compute the exemption.
    if line[4] > form(1040).status.amt_exempt_max
      line[5] = compute_form('6251 Line 5 Exemption Worksheet').line[:exemption]
    else
      line[5] = form(1040).status.amt_exemption
    end

    # Compute the balance over the exemption.
    line[6] = [ 0, line[4] - line[5] ].max
    if line[6] == 0
      line[9] = line[7] = 0
      compute_line_10
      line['11/amt_tax'] = 0
      return
    end

    # Line 7
    confirm("You have no foreign income")
    l7test = false
    l7test = true if form(1040).line[:qualdiv] > 0
    l7test = true if form(1040).line[:cap_gain] > 0
    with_form('1040 Schedule D') do |f|
      l7test = true if f.line[:lt_gain] > 0 and f.line[:tot_gain] > 0
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
    l10 = form(1040).line[:tax]
    with_form(4972) do |f|
      if f.line[30, :present]
        l10 -= f.line[30]
      elsif f.line[7, :present]
        l10 -= f.line[7]
      end
    end
    with_form('1040 Schedule 2') do |f|
      l10 += f.line[:aptc]
    end
    #
    # The line 10 instructions specify to subtract Schedule 3, line 1. But
    # Schedule 3 likely has not been calculated yet, since AMT is computed
    # during Schedule 2. Since Schedule 3, line 1 is simply the foreign tax
    # credit, that number is accounted for directly here.
    #
    l10 -= @ftc_form.line[:fill!] if @ftc_form

    confirm("You are not a farmer or fisherman")

    line[10] = l10
  end

  def compute_part_iii
    line[12] = line[6]

    check_line_13_conds
    # If the Schedule D worksheet is ever implemented, the 13 below should be
    # changed to an appropriate alias.
    line[13] = compute_from_worksheets(:tot_qdcg, 13) { BlankZero }

    line[14] = with_form('1040 Schedule D', otherwise: BlankZero) do |sd|
      sd.line[19, :opt]
    end
    line[15] = with_form(
      '1040 Schedule D Tax Worksheet', otherwise: line[13]
    ) do |sdtw|
      [ sum_lines(13, 14), sdtw.line[10] ].min
    end

    line[16] = [ line[12], line[15] ].min
    line[17] = line[12] - line[16]

    line[18] = amt_tax(line[17])

    line[19] = form(1040).status.amt_cg_exempt
    line[20] = compute_from_worksheets(:inc_no_qdcg, 14) {
      [ 0, form(1040).line[:taxinc] ].max
    }

    line[21] = [ 0, line[19] - line[20] ].max
    line[22] = [ line[12], line[13] ].min
    line[23] = [ line[21], line[22] ].min
    line[24] = line[22] - line[23]

    line[25] = form(1040).status.amt_cg_upper

    line[26] = line[21]
    line[27] = compute_from_worksheets(:inc_no_qdcg, 21) {
      [ 0, form(1040).line[:taxinc] ].max
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
    cond2 = (form(1040).line[:taxinc] == 0)
    cond3 = false
    with_form('1041 Schedule K-1') do |f|
      cond3 = true if !(line['12.code', :all] & %w(B C D E F)).empty?
    end
    if cond1 or cond2 or cond3
      raise "Nonstandard Form 6251, Line 13 not implemented"
    end
  end

  def amt_tax(amount)
    if amount <= form(1040).status.halve_mfs(232_600)
      return (amount * 0.26).round
    else
      return (amount * 0.28).round - form(1040).status.halve_mfs(4652)
    end
  end

  #
  # Returns the requested line from the QDCGT worksheet if that's present; if
  # not returns the requested line from the Schedule D Tax Worksheet if that's
  # present; if not yields and returns that.
  #
  def compute_from_worksheets(qdcgt_line, sdtw_line)
    with_form('1040 QDCGT Worksheet') do |qdcgt|
      return qdcgt.line[qdcgt_line]
    end
    with_form('1040 Schedule D Tax Worksheet') do |sdtw|
      return sdtw.line[sdtw_line]
    end
    return(yield)
  end

end



class Line5ExemptionWorksheet < TaxForm
  NAME = '6251 Line 5 Exemption Worksheet'

  def year
    2024
  end

  def compute
    if form(6251).line[4] > form(1040).status.amt_exempt_zero
      line['6/exemption'] = 0
      return
    end
    line[1] = form(1040).status.amt_exemption
    line[2] = form(6251).line[:amt_inc]
    line[3] = form(1040).status.amt_exempt_max
    line[4] = [ 0, line[2] - line[3] ].max
    line[5] = (line[4] * 0.25).round
    line['6/exemption'] = [ 0, line[1] - line[5] ].max

    if age < 24
      raise 'Special AMT exemption for children under 24 not implemented'
    end
  end
end

#
# On these parameters, see also amt_test_worksheet.rb, which is called in Form
# 1040 Schedule 2.
#

#
# Used on AMT test worksheet, line 8 and Form 6251, line 5.
#
FilingStatus.set_param('amt_exempt_max',
                       single: 609_350, mfj: 1_218_700, mfs: :half_mfj,
                       hoh: :single, qw: :mfj)

#
# Used on the AMT test worksheet, line 6, and Form 6251, line 5.
#
FilingStatus.set_param('amt_exemption',
                       single: 85_700, mfj: 133_300, mfs: :half_mfj, hoh:
                       :single, qw: :mfj)

#
# Used in the initial test prior to filling out the line 5 worksheet.
#
FilingStatus.set_param('amt_exempt_zero',
                       single: 952_150, mfj: 1_751_900, mfs: :half_mfj,
                       hoh: :single, qw: :mfj)

# Exemption for income excluding capital gains, for Form 6251, line 19.
FilingStatus.set_param('amt_cg_exempt',
                       single: 47_025, mfj: 94_050, mfs: :single,
                       hoh: 63_000, qw: :mfj)

# Limit for income excluding capital gains, for Form 6251, line 25.
FilingStatus.set_param('amt_cg_upper',
                       single: 518_900, mfj: 583_750, mfs: :half_mfj,
                       hoh: 551_350, qw: :mfj)

