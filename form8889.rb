require 'tax_form'

#
# Health Savings Accounts
#
class Form8889 < TaxForm

  NAME = '8889'

  def year
    2023
  end

  def needed?
    return false unless required?
    line[2] != 0 || line[9] != 0 || line['14a'] != 0 || line[20] != 0
  end

  #
  # Determines if the form is required. It is required in three situations:
  #
  # 1. HSA contributions were made this year
  # 2. HSA distributions were received this year
  # 3. A form 8889 was filed last year, prompting the possibility that this
  #    year's testing period fails
  #
  def required?
    return true if has_form?('HSA Contribution')
    return true if forms('W-2').any? { |f|
      f.line('12.code', :all).include?('W')
    }
    return true if @manager.submanager(:last_year).has_form?(8889)
    return false
  end

  def compute
    return unless required?

    raise "Not updated since 2020"

    set_name_ssn

    compute_coverage
    unless @coverage_months.count == 12
      raise "Partial HSA coverage not implemented"
    end
    line["1_#{@coverage_type}"] = 'X'

    line[2] = forms('HSA Contribution') { |f|
      f.line[:from] == 'self'
    }.lines(:contributions, :sum)

    case @coverage_type
    when :family then line[3] = 7100
    when :individual then line[3] = 3550
    end

    confirm('Neither you nor your spouse has an Archer MSA')
    line[4] = 0
    line[5] = line3 - line4

    allocate_hsa_limit # Line 6

    if age >= 55
      raise "Over-55 HSA contribution increase not implemented"
    end

    line[8] = sum_lines(6, 7)

    line[9] = employer_contributions
    confirm("You received no qualified distribution from an IRA to an HSA")
    line[11] = sum_lines(9, 10)
    line[12] = [ 0, line8 - line11 ].max
    line['13/hsa_ded'] = [ line2, line12 ].min

    #
    # Overcontributions
    compute_excess_contributions

    # Compute Form 5329 to figure any excise tax
    if line[:self_excess!, :present] || line[:employer_excess!, :present]
      compute_more(find_or_compute_form(5329), :hsa)
    end

    #
    # This code for part II implements only HSA distributions for withdrawals of
    # excess contributions.
    #
    assert_no_forms('1099-SA') # Part II, line 14a

    if line[:excess_wd_distrib, :present]
      line['14a'] = line[:excess_wd_distrib]
      line['14b'] = line[:excess_wd_distrib]
      line['14c'] = line['14a'] - line['14b']

      line['16/hsa_tax_distrib'] = line['14c'] - line[15, :opt]
      if line[16] > 0
        raise "Not implemented"
      end
    end

    # Part III is not implemented. If there ever is a need to implement a
    # testing period failure, alias the computed tax line (21 in 2023) to
    # :hsa_testing_tax.

  end

  def compute_coverage
    indiv_months = []
    family_months = []

    (forms('1095-B') + forms('1095-C')).each do |f|
      next unless f.line[:hdhp?]
      months = f.line[:months, :all]
      if months.include?('all')
        months = %w(jan feb mar apr may jun jul aug sep oct nov dec)
      end

      case f.line[:coverage]
      when 'family'
        family_months |= months
      when 'individual'
        indiv_months |= months
      else
        raise "Unknown value for Form 1095-B coverage: #{f.line[:coverage]}"
      end
    end
    indiv_months -= family_months
    if family_months.count >= indiv_months.count
      @coverage_type = :family
      @coverage_months = family_months
    else
      @coverage_type = :individual
      @coverage_months = indiv_months
    end
  end

  def allocate_hsa_limit

    # Check if the spouse has a separate HSA. If so, then we need to allocate
    # the HSA limit, so first we search for a spouse's form 8889. If found, then
    # this 8889 gets whatever is left over. Otherwise, we interview to ask for
    # an allocation.
    #
    # There are two ways for a spouse to have a separate HSA: If there are two
    # HSA forms, or if the status is married filing separately and the spouse's
    # manager contains a form HSA or 8889.
    #
    if forms('HSA Contribution').count > 1
      other_8889_form = forms(8889).find { |f| f != self }
    elsif form(1040).status.is('mfs')
      if @manager.submanager(:spouse).has_form?(8889)
        other_8889_form = @manager.submanager(:spouse).form(8889)
      elsif @manager.submanager(:spouse).has_form?('HSA Contribution')
        other_8889_form = nil
      end
    else
      line[6] = line[5]
      return
    end
    if other_8889_form
      line[6] = line[5] - other_8889_form.line[6]
    else
      line[6] = interview(
        "How much of the HSA limit #{line[5]} do you want to allocate to " + \
        form(1040).line[:first_name] + ":"
      )
      raise "Invalid HSA limit allocation" if line[6] > line[5]
    end

  end

  def employer_contributions
    total = BlankZero
    forms('W-2').each do |f|
      next unless f.line[:a] == form(1040).line[:ssn]
      l12w = f.line['12.code', :all].index('W')
      next unless l12w
      total += f.line[12, :all][l12w]
    end
    total += forms('HSA Contribution') { |f|
      f.line[:from] == 'employer'
    }.lines(:contributions, :sum)
    return total
  end

  def compute_excess_contributions

    #
    # Compute the excess contributions from both self and employer.
    #
    if line[2] > line[13]
      line[:self_excess!] = line[2] - line[13]
    end

    emp_limit = [ line[8] - line[10, :opt], 0 ].max
    if line[9] > emp_limit
      line[:employer_excess!] = line[9] - emp_limit
    end

    #
    # Figure basis and earnings of withdrawal of excess contributions. We need
    # to compute the following:
    #
    # 1. The basis withdrawn against this year's excess contributions (for
    #    figuring what is left in assessing the excise tax)
    # 2. The earnings realized this year from withdrawals against this and last
    #    year's excess contributions (for assessing other income)
    # 3. The total withdrawal amounts realized this year against this and last
    #    year's excess contributions (for filling Form 8889, part II)
    # 4. The carryover amounts that will be needed to compute 2 and 3 next year
    #
    # First, gather last year's numbers that carried to this year, for
    # computations 2 and 3.
    #
    distrib, realized_earnings = @manager.submanager(:last_year).with_form(
      8889, otherwise_return: [ BlankZero, BlankZero ]
    ) { |f|
      e = f.line[:excess_wd_earnings_carry!, :opt]
      [ e + f.line[:excess_wd_basis_carry!, :opt], e ]
    }

    hew_forms = forms('HSA Excess Withdrawal')
    if !hew_forms.empty?
      # Compute basis withdrawn (1)
      line[:excess_wd_basis!] = hew_forms.lines(:basis, :sum)
    end

    hew_by_year = hew_forms.group_by { |f| f.line[:date].year }
    unless (hew_by_year.keys - [ year, year + 1 ]).empty?
      raise "Invalid year in HSA Excess Withdrawal"
    end
    if hew_by_year[year]
      # Compute realized earnings (2)
      e = hew_by_year[year].map(&:line_earnings).sum
      realized_earnings += e

      # Compute realized distribution (3)
      distrib += e + hew_by_year[year].map(&:line_basis).sum
    end

    if hew_by_year[year + 1]
      # Save carryover values for next year (4)
      line[:excess_wd_earnings_carry!] = \
        hew_by_year[year + 1].map(&:line_earnings).sum
      line[:excess_wd_basis_carry!] = \
        hew_by_year[year + 1].map(&:line_basis).sum
    end

    # By analogy to 26 CFR 1.408-11(a)(1) and IRS Notice 2000-39, it appears
    # that the realized earnings can be negative.
    if realized_earnings != 0
      line[:excess_wd_earnings!] = realized_earnings
    end

    if distrib != 0 || realized_earnings != 0
      line[:excess_wd_distrib!] = distrib
    end

  end


  #
  # This is called by Form 1040 Schedule 1, line 8 (Other Income).
  #
  def other_income
    if line[16, :present] && line[16] > 0
      yield("HSA", line[16])
    end

    if line[:excess_wd_earnings!, :present]
      yield("IRC 223(f)(3)(A)(ii)", line[:excess_wd_earnings])
    end

    if line[:employer_excess!, :present]
      yield("Excess employer HSA contrib.", line[:employer_excess!])
    end
  end

end
