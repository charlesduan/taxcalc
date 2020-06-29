require 'tax_form'
require 'date'

#
# Nondeductible IRA contributions and distributions. Computations of this form
# are controlled by the IraAnalysis form, so that one should be reviewed first.
#
class Form8606 < TaxForm

  def name
    '8606'
  end

  def year
    2019
  end

  def copy_analysis_line(to_line)
    from_line = "8606_#{to_line}"
    if @ira_analysis.line[from_line]
      line[to_line] = @ira_analysis.line[from_line]
      if @ira_analysis.line["#{from_line}*note", :present]
        line["#{to_line}*note"] = @ira_analysis.line["#{from_line}*note"]
      end
    else
      raise "IRA analysis lacks line #{to_line}" unless block_given?
      line[to_line] = yield
    end
  end

  #
  # This only computes distributions. Contributions are computed later.
  def compute

    @ira_analysis = form('IRA Analysis')

    set_name_ssn

    # Lines 1-5 will be computed by the IRA Analysis.
    line[1] = @ira_analysis.line[:nondeductible_contribs]
    copy_analysis_line(2)
    copy_analysis_line(3)
    copy_analysis_line(4)
    copy_analysis_line(5)

    if @ira_analysis.line[:compute_8606_rest?]
      compute_lines_6_to_12
    end

    copy_analysis_line(13) { sum_lines(11, 12) }
    line[14] = line[13] - line[3]
    copy_analysis_line('15a')  { line[12] - line[7] }
    copy_analysis_line('15b')  { BlankZero }
    copy_analysis_line('15c') { line['15a'] - line['15b'] }

    compute_part_ii
    compute_part_iii
  end

  def compute_lines_6_to_12

    # Question already asked in Pub. 590-B WS 1-1
    line[6] = interview(
      'Enter the value of all traditional IRAs as of Dec. 31 of this year:'
    )
    line[7] = @ira_analysis.line[:distrib_cash]
    line[8] = @ira_analysis.line[:distrib_roth]
    line[9] = sum_lines(6, 7, 8)
    line[10] = [ (1.0 * line[5] / line[9]).round(8), 1.0 ].min
    line[11] = (line[8] * line[10]).round
    line[12] = (line[7] * line[10]).round
  end

  def compute_part_ii
    copy_analysis_line(16)
    copy_analysis_line(17)
    copy_analysis_line(18)
  end

  def compute_part_iii
    return unless @ira_analysis.line['8606_25c', :present]
    raise "Not implemented"
  end

end


