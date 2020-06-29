require 'tax_form'

class Pub590BWorksheet1_1 < TaxForm

  def name
    "Pub. 590-B Worksheet 1-1"
  end

  def year
    2019
  end

  def compute
    analysis = form('IRA Analysis')

    # Last year's basis
    line[1] = @manager.submanager(:last_year).form(8606).line[14]
    line[2] = analysis.line[:this_year_contrib]
    line[3] = sum_lines(1, 2)

    line[4] = interview(
      'Enter the value of all traditional IRAs as of Dec. 31 of this year:'
    )

    # Line 5 is the sum of line 1 of those 1099-R forms that are traditional
    # IRA distributions
    line[5] = analysis.line[:total_distribs]

    line[6] = sum_lines(4, 5)
    line[7] = [ 1.0, line[3].to_f / line[6] ].min.round(5)
    line[8] = (line[5] * line[7]).round

    line[9] = line[5] - line[8]

    if analysis.line[:distrib_roth] > 0
      line10frac = analysis.line[:distrib_roth].to_f / line[5]
      line[10] = (line10frac * line[9]).round

      line[11] = line[9] - line[10]

      line[:taxable_distribs] = line[11]
    else
      line[:taxable_distribs] = line[9]
    end

  end

end


