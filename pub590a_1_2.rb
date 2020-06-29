class Pub590AWorksheet1_2 < TaxForm
  def name
    "Pub. 590-A Worksheet 1-2"
  end

  def year
    2019
  end

  def compute
    @ira_analysis = form('IRA Analysis')

    status = form(1040).status

    @over50 = (age >= 50)
    ret_limits = nil

    covered = forms('W-2').lines('13ret?', :present)
    if covered
      # IRA deduction MAGI limits if you are covered by a retirement plan
      ret_limits = status.ira_deduction_limit

    elsif status.is('mfs') or status.is('mfj') && \
      submanager(:spouse).forms('W-2').lines('13ret?').any? { |x| x == true }

      # Limits if spouse is covered by a plan
      ret_limits = form(1040).status.ira_deduction_limit_spouse
    else
      # No limits apply if neither spouse or a single person is covered by a
      # retirement plan.
      compute_no_limit
      return
    end

    # Determine whether the MAGI is between the limits. If it is below the lower
    # bound limit, then compute as if there were no limit.
    magi = @manager.compute_form(Pub590AWorksheet1_1).line[8]
    if magi <= ret_limits[0]
      compute_no_limit
      return
    end

    line[1] = ret_limits[1]
    line[2] = magi

    if magi >= ret_limits[1]
      compute_5_to_6
      line[7] = 0
      line[8] = [ line[5], line[6] ].min - line[7]
      return
    end

    line[3] = line[1] - line[2]
    line4frac = @over50 ? 0.65 : 0.55
    if covered && (status.is('mfj') || status.is('qw'))
      line4frac = @over50 ? 0.325 : 0.275
    end
    line[4] = [ 200, (line[3] * line4frac / 10).ceil * 10 ].max

    compute_no_limit
  end

  def compute_5_to_6

    # Compensation minus self-employment tax and SEP/SIMPLE/qualified plans
    line5 = form(1040).line[1]
    with_form('1040 Schedule 1') do |f|
      line5 -= f.sum_lines(27, 28)
    end
    if form(1040).status.is('mfj')
      # TODO: If spouse's income is greater, then add it minus spouse's IRA
      # contributions
    end
    line[5] = line5

    # IRA contributions for this year
    line[6] = @ira_analysis.line[:this_year_contrib]
    if line[6] > (@over50 ? 7000 : 6000)
      raise "Excess contributions to traditional IRA not implemented"
    end
  end

  def compute_no_limit
    compute_5_to_6
    if line[4, :present]
      line[7] = [ line[4], line[5], line[6] ].min
    else
      line[7] = [ line[5], line[6] ].min
    end
    line[8] = [ line[5], line[6] ].min - line[7]
  end

end

# Traditional IRA deduction limits for modified AGI, per worksheet line 1.
FilingStatus.set_param(
  'ira_deduction_limit',
  [ 64_000, 74_000 ], [ 103_000, 123_000 ], [ 0, 10_000 ], :single, :mfj
)
FilingStatus.set_param(
  'ira_deduction_limit_spouse',
  nil, [ 193_000, 203_000 ], [ 0, 10_000 ], nil, nil
)

