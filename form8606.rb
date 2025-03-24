require 'tax_form'
require 'date'

#
# Nondeductible IRA contributions and distributions. Computations of this form
# are controlled by the IraAnalysis form, so that one should be reviewed first.
#
class Form8606 < TaxForm

  NAME = '8606'

  def year
    2024
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

  def initialize(manager, ssn)
    super(manager)
    @ssn = ssn
  end

  #
  # This only computes distributions. Contributions are computed later.
  def compute

    line[:name] = with_form('Biographical', ssn: @ssn) { |f|
      f.line[:first_name] + ' ' + f.line[:last_name]
    }
    line[:ssn] = @ssn

    @ira_analysis = form('IRA Analysis', ssn: @ssn)

    # Lines 1-5 will be computed by the IRA Analysis.
    line[1] = @ira_analysis.line[:nondeductible_contrib]
    copy_analysis_line(2)
    copy_analysis_line(3)
    copy_analysis_line(4)
    copy_analysis_line(5)

    if @ira_analysis.line[:compute_8606_rest?]
      line[6] = form(
        'End-of-year Traditional IRA Value', ssn: @ssn
      ).line[:amount]
      line[7] = @ira_analysis.line[:distrib_cash]
      line[8] = @ira_analysis.line[:distrib_roth]
      line[9] = sum_lines(6, 7, 8)
      line[10] = [ (1.0 * line[5] / line[9]).round(8), 1.0 ].min
      line[11] = (line[8] * line[10]).round
      line[12] = (line[7] * line[10]).round
    end

    copy_analysis_line(13) { sum_lines(11, 12) }
    line['14/tot_basis'] = line[3] - line[13]
    copy_analysis_line('15a')  { line[12] - line[7] }
    copy_analysis_line('15b')  { BlankZero }
    copy_analysis_line('15c') { line['15a'] - line['15b'] }

    compute_part_ii
    compute_part_iii
  end

  def compute_part_ii
    if @ira_analysis.line['8606_16', :present]
      copy_analysis_line(16)
      copy_analysis_line(17)
      copy_analysis_line(18)
    elsif @ira_analysis.line[:compute_8606_rest?]
      line[16] = line[8]
      line[17] = line[11]
      line[18] = line[16] - line[17]
    else
      # This situation will never happen for me, because I have made
      # nondeductible contributions to a traditional IRA in previous years and
      # therefore will always complete Part I.
      raise "Form 8606, Part II not implemented in this condition"
    end
  end

  def compute_part_iii
    return unless @ira_analysis.line['8606_25c', :present]
    raise "Not implemented"
  end

end


