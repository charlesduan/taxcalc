require 'tax_form'

#
# Health Savings Accounts
#
class Form8889 < TaxForm

  NAME = '8889'

  def year
    2020
  end

  def compute
    set_name_ssn

    compute_coverage
    unless @coverage_months.count == 12
      raise "Partial HSA coverage not implemented"
    end
    line["1_#{@coverage_type}"] = 'X'

    line[2] = forms('HSA Contribution').lines(:contributions, :sum)

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
    line[12] = line8 - line11
    line['13/hsa_ded'] = [ line2, line12 ].min
    if line2 > line13
      raise "Excess HSA contribution not implemented"
    end

    assert_no_forms('1099-SA') # Part II

    # Part III is not implemented because it is assumed that the last-month rule
    # was met.

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
    return total
  end

end
