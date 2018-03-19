require 'tax_form'
require 'filing_status'

class IraAnalysis < TaxForm

  def name
    'IRA Analysis'
  end

  attr_reader :form8606, :pub590a_w1_1, :pub590a_w1_2, :pub590b_w1_1

  def get_contributions
    line[:this_year_contrib] = interview(
      'Enter this year\'s traditional IRA contributions:'
    ) unless line[:this_year_contrib, :present]
  end

  def compute

    return unless has_form?('1099-R')
    all_distribs = forms('1099-R').lines(1, :sum)

    # No IRA rollovers, QCD, HFD
    assert_question("Did you do an IRA rollover, qualified charitable " + \
                    "distribution, or HSA funding distribution?", false)

    # Were there contributions?
    get_contributions

    # Was it a Roth conversion?
    if interview('Were all your 1099-R distributions for Roth conversions?')
      line[:roth_conversion] = all_distribs
    else
      line[:roth_conversion] = interview(
        'Enter the amount converted from traditional/SEP/SIMPLE to Roth IRAs:'
      )
    end

    if line[:this_year_contrib] == 0

      # Distributions only. Terminate unless Form 8606 is needed.
      unless line[:roth_conversion] > 0 or \
        interview('Do you need to file Form 8606 (see 1040 line 15a)?')

        line['15b'] = all_distribs
        return
      end

    else

      # Both contributions and distributions.
      # Follow Pub. 590-B, Worksheet 1-1 and instructions
      @pub590b_w1_1 = @manager.compute_form(
        Pub590BWorksheet1_1.new(@manager, self)
      )
    end

    # Compute form 8606 (just distributions)
    @form8606 = @manager.compute_form(Form8606.new(@manager, self))
    line['15a'] = all_distribs
    line['15b'] = @form8606.sum_lines(15, 18, 25)

  end

  def compute_contributions
    get_contributions
    return unless line[:this_year_contrib] > 0

    @pub590a_w1_1 = @manager.compute_form(
      Pub590AWorksheet1_1.new(@manager, self)
    )
    @pub590a_w1_2 = @manager.compute_form(
      Pub590AWorksheet1_2.new(@manager, self)
    )

    line[32] = @pub590a_w1_2.line[7]

    if @form8606
      @form8606.compute_contributions
    else
      @form8606 = Form8606.new(@manager, self)
      @manager.add_form(@form8606)
      @form8606.compute_contributions
    end
  end

  class Pub590BWorksheet1_1 < TaxForm

    def initialize(manager, ira_analysis)
      super(manager)
      @ira_analysis = ira_analysis
    end

    def name
      "Pub. 590-B Worksheet 1-1"
    end

    def compute
      analysis = @ira_analysis
      line[1] = interview(
        'Enter your traditional IRA basis from Dec. 31 of last year:'
      )
      line[2] = analysis.line[:this_year_contrib]
      line[3] = sum_lines(1, 2)

      line[4] = interview(
        'Enter the value of all traditional IRAs as of Dec. 31 of this year:'
      )
      line[5] = forms('1099-R').select { |f|
        [ 1, 2, 3, 4, 5, 7 ].include?(f.line[7])
      }.lines(1, :sum)
      line[6] = sum_lines(4, 5)
      line[7] = [ 1.0, line[3].to_f / line[6] ].min.round(3)
      line[8] = (line[5] * line[7]).round

      line[9] = line[5] - line[8]

      line10frac = analysis.line[:roth_conversion].to_f / line[5]
      line[10] = (line10frac * line[9]).round

      line[11] = line[9] - line[10]
    end

  end

  class Form8606 < TaxForm

    def initialize(manager, ira_analysis)
      super(manager)
      @ira_analysis = ira_analysis
    end

    def name
      '8606'
    end

    def compute

      if @ira_analysis.pub590b_w1_1
        w1_1 = @ira_analysis.pub590b_w1_1
        line[13] = line[17] = w1_1.line[8]
        line[18] = w1_1.line[10] if w1_1.line[10, :present]
        line[15] = w1_1.line[11, :present] ? w1_1.line[11] : w1_1.line[9]
        line['note'] = 'Line 13 from Pub. 590-B Worksheet 1-1'
      elsif @ira_analysis.line[:this_year_contrib] == 0
        line[1] = 0
        compute_2_to_3
        if has_form?('1099-R')
          raise 'Not implemented'
        end
      end
      compute_part_iii
    end

    def compute_contributions
      w1_1 = @ira_analysis.pub590b_w1_1
      line[1] = @ira_analysis.pub590a_w1_2.line[8]
      if w1_1
        compute_2_to_3
        compute_4_to_5

        if line[5] < w1_1.line[8]
          compute_6_to_15
        else
          line[14] = line[3] - line[13]
        end
      else
        # If Pub. 590-B Worksheet 1-1 was not computed, then there were no IRA
        # distributions.
        compute_2_to_3
        line[14] = line[3]
        compute_part_iii
      end

    end

    def compute_2_to_3
      line[2] = interview('Enter your total basis in traditional IRAs:')
      line[3] = sum_lines(1, 2)
    end

    def compute_4_to_5
      line[4] = [
        interview('Enter your IRA contributions after Jan. 1:'),
        line[1]
      ].min

      line[5] = line[3] - line[4]
    end

    def compute_6_to_15
      raise 'Not implemented'
    end

    def compute_part_iii
      roth_forms = forms('1099-R').select { |f|
        [ 'B', 'J', 'T' ].include?(f.line[7])
      }
      return if roth_forms.empty?
      raise 'Form 8606 part III is not implemented'
    end

  end

  class Pub590AWorksheet1_1 < TaxForm
    def name
      "Pub. 590-A Worksheet 1-1"
    end

    def initialize(manager, ira_analysis)
      super(manager)
      @ira_analysis = ira_analysis
    end

    def compute

      # Because the IRS instructions somehow expect you to calculate line 38
      # before line 32, this computation below uses a different approach that
      # appears equivalent.
      line[1] = form(1040).line[22] - form(1040).sum_lines(23, 24, 25, 26, 27,
                                                           28, 29, 30, '31a')
      with_form(2555) do |f|
        line[5] = f.line[45]
        line[6] = f.line[50]
      end
      with_form(8815) do |f|
        line[7] = f.line[14]
      end
      with_form(8839) do |f|
        line[8] = f.line[28]
      end
      line[9] = sum_lines(1, 5, 6, 7, 8)
    end

  end

  class Pub590AWorksheet1_2 < TaxForm
    def name
      "Pub. 590-A Worksheet 1-2"
    end

    def initialize(manager, ira_analysis)
      super(manager)
      @ira_analysis = ira_analysis
    end

    def compute

      status = form(1040).status
      ret_limits = nil

      covered = forms('W-2').lines('13ret?').any? { |x| x == true }
      if covered
        ret_limits = status.ira_limit
      elsif status.is('mfs') or status.is('mfj')
        if interview('Is your spouse covered by a work retirement plan?')
          ret_limits = form(1040).status.ira_limit_spouse
        end
      end

      if ret_limits.nil?
        compute_no_limit
        return
      end

      magi = @ira_analysis.pub590a_w1_1.line[9]
      if magi <= ret_limits[0]
        compute_no_limit
        return
      end

      if magi >= ret_limits[1]
        compute_5_to_6
        line[7] = 0
        line[8] = [ line[5], line[6] ].min - line[7]
        return
      end

      line[1] = ret_limits[1]
      line[2] = magi
      line[3] = line[1] - line[2]
      line[4] = line[3]

      over50 = interview('Are you age 50 or older?')
      line4frac = over50 ? 0.65 : 0.55
      if covered && (status.is('mfj') || status.is('qw'))
        line4frac = over50 ? 0.325 : 0.275
      end
      line[4] = [ 200, (line[3] * line4frac / 10).ceil * 10 ].max
      compute_5_to_6
      line[7] = [ line[4], line[5], line[6] ].min
      line[8] = [ line[5], line[6] ].min - line[7]
    end

    def compute_5_to_6
      over50 = interview('Are you age 50 or older?')
      line[5] = form(1040).line[7] - form(1040).sum_lines(27, 28)
      with_form('1040 Schedule SE') do |f|
        line[5] += [ f.line[6], 0 ].max
      end
      line[6] = [
        @ira_analysis.line[:this_year_contrib],
        over50 ? 6500 : 5500
      ].min
    end

    def compute_no_limit
      compute_5_to_6
      line[7] = [ line[5], line[6] ].min
      line[8] = 0
    end

  end

end

FilingStatus.set_param('ira_limit', [ 61000, 71000 ], [ 98000, 118000 ],
                       [ 0, 10000 ], [ 61000, 71000 ], [ 98000, 118000 ])

FilingStatus.set_param('ira_limit', nil, [ 184000, 194000 ], [ 0, 10000 ], nil,
                       nil)

