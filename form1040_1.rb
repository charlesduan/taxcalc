require 'tax_form'
require 'form8889'
require 'form1040_d'
require 'form1040_e'

# Because the adjustments computation can depend on the income computation, this
# form must be computed in two parts.
class Form1040_1 < TaxForm

  def name
    '1040 Schedule 1'
  end

  def year
    2018
  end

  def compute
    set_name_ssn

    # Line 10
    if @manager.has_form?('1099-G')
      line[10] = compute_1099g
    end
    # If this line ever includes refunds for taxes other than income taxes, line
    # 2b on Form 6251 (AMT) needs to be adjusted

    line[11] = forms(:Alimony).lines(:amount, :sum)

    assert_no_forms('1099-MISC')
    #line[12] = forms('1040 Schedule C').lines(31, :sum)

    sched_d = find_or_compute_form('1040 Schedule D', Form1040D)

    if sched_d
      line[13] = sched_d.line[:fill!]
    else
      line[13] = BlankZero
    end

    # Line 14 must be zero because we assume no sole proprietorships

    sched_e = @manager.compute_form(Form1040E)
    line[17] = sched_e.line[41]

    line[22] = sum_lines(10, 11, 12, 13, 14, 17, 18, 19, 21)

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

    line[25] = forms('HSA Contribution').map { |f|
      compute_form(Form8889, f).line[13]
    }.inject(BlankZero, :+)

    sched_se = find_or_compute_form('1040 Schedule SE', Form1040SE)
    line[27] = sched_se.line[13] if sched_se

    ira_analysis = form('IRA Analysis')
    ira_analysis.compute_contributions
    line[32] = ira_analysis.line[:deductible_contribution, :opt]

    line[36] = sum_lines(23, 24, 25, 26, 27, 28, 29, 30, '31a', 32, 33, 34, 35)
  end
end
