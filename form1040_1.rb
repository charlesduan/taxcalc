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
    # Line 10
    assert_no_forms('1099-G')

    line[11] = forms(:Alimony).lines(:amount, :sum)

    assert_no_forms('1099-MISC')
    #line[12] = forms('1040 Schedule C').lines(31, :sum)

    sched_d = compute_form(Form1040D)

    if sched_d
      line[13] = sched_d.line['fill']
    else
      line[13] = BlankZero
    end

    # Line 14 must be zero because we assume no sole proprietorships

    sched_e = @manager.compute_form(Form1040E)
    line[17] = sched_e.line[41]

    line[22] = sum_lines(10, 11, 12, 13, 14, 17, 18, 19, 21)

  end

  def compute_adjustments

    line[25] = forms('HSA').map { |f|
      compute_form(8889, f).line[13]
    }.sum

    sched_se = find_or_compute_form('1040 Schedule SE', Form1040SE)
    line[27] = sched_se.line[13] if sched_se

    ira_analysis.compute_contributions
    line[32] = ira_analysis.line[32]

    line[36] = sum_lines(23, 24, 25, 26, 27, 28, 29, 30, '31a', 32, 33, 34, 35)
  end
end
