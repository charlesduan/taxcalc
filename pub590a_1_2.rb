#
# Computes the deductible and nondeductible portions of an IRA contribution. The
# computation produces two lines :deductible_contrib and :nondeductible_contrib.
#
class Pub590AWorksheet1_2 < TaxForm
  NAME = "Pub. 590-A Worksheet 1-2"

  def year
    2023
  end

  def initialize(ssn, spouse_ssn)
    @ssn = ssn
    @spouse_ssn = spouse_ssn
  end

  #
  # Determines who has a retirement plan. Returns :mine, :spouse, or :none.
  #
  def has_ret_plan
    return :mine if forms('W-2', ssn: @ssn).lines('13ret?', :all).any?
    if @spouse_ssn
      return :spouse if forms('W-2', ssn: @spouse_ssn).lines(
        '13ret?', :all
      ).any?
      if @manager.submanager(:spouse)
        return :spouse if @manager.submanager(:spouse).forms(
          'W-2', ssn: @spouse_ssn
        ).lines('13ret?', :all).any?
      end
    end
    return :none
  end

  def compute
    line[:ssn] = @ssn
    line[:spouse_ssn] = @spouse_ssn

    @ira_analysis = form('IRA Analysis', ssn: @ssn)

    @status = form(1040).status
    skip = false

    case has_ret_plan
    when :mine
      limit = @status.ira_deduction_limit
    when :spouse
      limit = @status.ira_deduction_limit_spouse
    when :none
      # No limits apply if neither spouse or a single person is covered by a
      # retirement plan.
      line[:no_limits_apply] = 'No limits apply'
      compute_all_deductible
      skip = true
    else
      raise "Invalid has_ret_plan value"
    end

    unless skip
      # Determine whether the MAGI is between the limits. If it is below the
      # lower bound limit, then compute as if there were no limit.
      line[1] = limit[1]
      line['2/magi'] = compute_form('Pub. 590-A Worksheet 1-1').line[:magi]
      line[3] = line[1] - line[2]

      # The form asks whether line 3 is $10,000 or more ($20,000 for MFJ etc).
      # This is equivalent to asking whether MAGI is under the limit.
      if line[:magi] <= limit[0]
        compute_all_deductible
      elsif line[:magi] >= limit[1]
        compute_none_deductible
      else
        compute_some_deductible
      end
    end

    line[:deductible_contrib] = line[7]
    line[:nondeductible_contrib] = line[8]
  end

  #
  # Sets line 5/compensation_limit to the limit on IRA contributions. Also
  # returns the value.
  #
  def compute_compensation_limit

    # The computation of compensation is based on Pub. 590-A. However, the
    # definition of compensation is complex, and needs to be updated if unusual
    # forms of compensation are to be included.
    compensation = forms('W-2', ssn: @ssn).lines(1, :sum)

    # These need to be separated out per spouse
    #
    # compensation += form(1040).line[:combat_pay, :opt]
    # Commissions should be included here
    # with_form('1040 Schedule 1') do |f|
    #   compensation += f.line[:alimony]
    # end
    if has_form?('1040 Schedule SE')
      form('1040 Schedule SE', ssn: @ssn) do |f|
        compensation += [ f.line[:tot_inc], 0 ].max
      end
    end

    # The Kay Bailey Hutchinson Spousal IRA Limit computation is not
    # implemented. That computation raises the compensation limit for MFJ
    # returns where the spouse earns enough to contribute to both.

    line['5/compensation_limit'] = compensation
    return compensation
  end

  #
  # Enters into line 6/contribution the amount actually contributed. If the
  # amount is greater than the limits, then an error is raised since excess
  # contributions are not implemented yet.
  #
  def enter_contributions
    line[:age_limit] = (age > 50 ? 7500 : 6500)
    line['6/contribution'] = @ira_analysis.line[:this_year_contrib]
    if line[6] > [ line[:age_limit], line[5] ].min
      raise "Excess contributions to traditional IRA not implemented"
    end
  end

  #
  # Compute on the assumption that the entire contribution is deductible, up to
  # the limit as determined by enter_contributions.
  #
  def compute_all_deductible
    compute_compensation_limit
    enter_contributions
    #
    # Since enter_contributions has already confirmed that the actual
    # contributions do not exceed the limit, the deductible amount is the entire
    # contribution.
    line[7] = line[:contribution]
    line[8] = 0
  end

  #
  # Compute on the assumption that none of the contribution is deductible.
  #
  def compute_none_deductible
    compute_compensation_limit
    enter_contributions
    line[7] = 0
    line[8] = line[:contribution]
  end

  def compute_some_deductible
    #
    # The computation has gotten more complicated than usual here, and to date I
    # do not qualify for any deduction anyway.
    #
    raise "Partially deductible IRA contribution not implemented"
  end

end

# Traditional IRA deduction limits for modified AGI, per worksheet line 1.
FilingStatus.set_param(
  'ira_deduction_limit',
  single: [ 73_000, 83_000 ], mfj: [ 116_000, 136_000 ], mfs: [ 0, 10_000 ],
  hoh: :single, qw: :mfj
)
FilingStatus.set_param(
  'ira_deduction_limit_spouse',
  single: nil, mfj: [ 218_000, 228_000 ], mfs: [ 0, 10_000 ],
  hoh: nil, qw: nil
)

