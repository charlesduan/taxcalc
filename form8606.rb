require 'tax_form'
require 'date'

class Form8606 < TaxForm

  def initialize(manager, ira_analysis)
    super(manager)
    @ira_analysis = ira_analysis
  end

  def name
    '8606'
  end

  def compute

    set_name_ssn

    if @ira_analysis.pub590b_w1_1
      explain("      Applying Pub. 590-B Worksheet 1-1 analysis")
      w1_1 = @ira_analysis.pub590b_w1_1
      explain("      Taxable IRA distributions, lines 13 and 15a-c, taken" +
              " from worksheet")
      line[13] = w1_1.line[8]
      line['15a'] = w1_1.line[11, :present] ? w1_1.line[11] : w1_1.line[9]
      line['15b'] = 0 # No qualified disaster
      line['15c'] = line['15a'] - line['15b']
      line['note_1'] = 'Line 13 from Pub. 590-B Worksheet 1-1'

      explain("      Roth conversions, lines 17-18, taken from worksheet")
      line[16] = @ira_analysis.line[:roth_conversion]
      line[17] = w1_1.line[8]
      line[18] = w1_1.line[10] if w1_1.line[10, :present]
      line[:note_2] = 'Line 18 from Pub. 590-B Worksheet 1-1'

    elsif @ira_analysis.line[:this_year_contrib] == 0
      explain("      No contribution found for this year")
      line[1] = 0
      compute_2_to_3
      if has_form?('1099-R')
        raise 'Not implemented'
      end
    end
    compute_part_iii
  end

  def compute_contributions
    explain("Computing Form #{name} contributions for #{@manager.name}")
    w1_1 = @ira_analysis.pub590b_w1_1
    line[1] = @ira_analysis.pub590a_w1_2.line[8]
    if w1_1
      explain("      Found Pub. 590-B Worksheet 1-1; computing lines 2 to 5")
      compute_2_to_3
      compute_4_to_5

      if line[5] < w1_1.line[8]
        explain("      Line 5 was less than Worksheet 1-1, line 8")
        explain("      Computing lines 6 to 12")
        compute_6_to_12(w1_1)
      else
        explain("      Line 5 was at least Worksheet 1-1, line 8")
        explain("      Skipping lines 6 to 12")
      end
      place_lines(13, :note_1)
      line[14] = line[3] - line[13]
      place_lines('15a', '15b', '15c')
    else
      explain("      No Pub. 590-B Worksheet 1-1, so no IRA distributions")
      explain("      Setting line 14 to line 3")
      # If Pub. 590-B Worksheet 1-1 was not computed, then there were no IRA
      # distributions.
      compute_2_to_3
      line[14] = line[3]
    end

    place_lines(16, 17, 18, :note_2)

    explain("Done computing Form #{name} contributions")
  end

  def compute_2_to_3
    line[2] = @manager.submanager(:last_year).form(8606).line[14]
    line[3] = sum_lines(1, 2)
  end

  def compute_4_to_5
    line[4] = [
      forms('Traditional IRA Contribution') { |f|
        f.date >= Date.new(Date.today.year, 1, 1)
      }.lines(:amount, :sum),
      line[1]
    ].min

    line[5] = line[3] - line[4]
  end

  def compute_6_to_12(p590b_w1_1)
    line[6] = p590b_w1_1.line[4]
    line[7] = @ira_analysis.line[:cash_distribution]
    line[8] = @ira_analysis.line[:roth_conversion]
    line[9] = sum_lines(6, 7, 8)
    line[10] = [ (1.0 * line[5] / line[9]).round(8), 1.0 ].min
    line[11] = (line[8] * line[10]).round
    line[12] = (line[7] * line[10]).round
  end

  def compute_part_iii
    explain("      Confirming that no Roth IRA distributions were taken")
    roth_forms = forms('1099-R') { |f|
      [ 'B', 'J', 'T' ].include?(f.line[7])
    }
    return if roth_forms.empty?
    raise 'Form 8606 part III is not implemented'
  end

end


