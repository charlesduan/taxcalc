require 'tax_form'
require 'form8889'
require 'form1040_e'

# Because the adjustments computation can depend on the income computation, this
# form must be computed in two parts.
class Form1040_1 < TaxForm

  NAME = '1040 Schedule 1'

  def year
    2019
  end

  def compute
    set_name_ssn

    assert_question("Did you have any interest in virtual currency?", false)
    line['bitcoin.no'] = 'X'

    # Line 10
    if @manager.has_form?('1099-G')
      line['1/taxrefund'] = compute_1099g
    end
    # If this line ever includes refunds for taxes other than income taxes, line
    # 2b on Form 6251 (AMT) needs to be adjusted

    if has_form?(:Alimony)
      raise "Alimony forms not implemented"
      #line['2a'] = forms(:Alimony).lines(:amount, :sum)
    end

    assert_no_forms('1099-MISC')
    #line[3] = forms('1040 Schedule C').lines(31, :sum)

    # Line 4 is assumed to be zero; otherwise implement line 4797
    confirm("No business property was sold or lost")
    line['4/other_gains'] = BlankZero

    sched_e = @manager.compute_form('1040 Schedule E')
    line['5/rrerpst'] = sched_e.line[41]

    line[9] = sum_lines(1, '2a', 3, 4, 5, 6, 7, 8)

  end

  def compute_1099g
    assert_no_lines('1099-G', 1, 4, 5, 6, 7, 9, 11)
    salt_recovery = forms('1099-G').lines(2, :sum)
    lym = @manager.submanager(:last_year)
    return BlankZero unless lym.has_form?('1040 Schedule A')
    lysa = lym.form('1040 Schedule A')
    if lysa.line_5d - salt_recovery < lysa.line_5e
      raise "SALT tax recovery not implemented"
      #
      # In case you need to implement this: Look at IRS Publication 525 and
      # Revenue Ruling 2019-11:
      #
      #   https://www.irs.gov/pub/irs-drop/rr-19-11.pdf
      #
      # Basically you need to figure what deduction would have been available
      # has the proper tax been paid, and the recovery income should be the
      # difference.
      #
    end
    return BlankZero
  end

  def compute_adjustments

    line[12] = forms('HSA Contribution').map { |f|
      compute_form(8889, f).line[13]
    }.inject(BlankZero, :+)

    sched_se = find_or_compute_form('1040 Schedule SE')
    line[14] = sched_se.line[13] if sched_se

    ira_analysis = form('IRA Analysis')
    ira_analysis.continue_computation
    line[19] = ira_analysis.line[:deductible_contribs]

    line[22] = sum_lines(10, 11, 12, 13, 14, 15, 16, 17, '18a', 19, 20, 21)
  end
end
