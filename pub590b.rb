require 'tax_form'

class Pub590BWorksheet1_1 < TaxForm

  NAME = "Pub. 590-B Worksheet 1-1"

  def year
    2024
  end

  def initialize(manager, ssn, spouse_ssn)
    super(manager)
    @ssn = ssn
    @spouse_ssn = spouse_ssn
  end

  def compute
    line[:ssn] = @ssn

    analysis = form('IRA Analysis', ssn: @ssn)

    line[1] = analysis.line[:last_year_basis]
    line[2] = analysis.line[:this_year_contrib]
    line[3] = sum_lines(1, 2)

    line[4] = form('End-of-year Traditional IRA Value', ssn: @ssn).line[:amount]

    # Line 5 is the sum of line 1 of those 1099-R forms that are traditional
    # IRA distributions
    line[5] = analysis.line[:total_distrib]

    line[6] = sum_lines(4, 5)
    line[7] = [ 1.0, line[3].to_f / line[6] ].min.round(5)
    line['8/nontax_distrib'] = (line[5] * line[7]).round

    line[9] = line[5] - line[8]

    if analysis.line[:distrib_roth] > 0
      line10frac = analysis.line[:distrib_roth].to_f / line[5]
      line['10/taxable_roth_conv'] = (line10frac * line[9]).round

      line[11] = line[9] - line[10]

      line[:taxable_distrib] = line[11]
    else
      line[:taxable_distrib] = line[9]
    end

  end

end


