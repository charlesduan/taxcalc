require 'tax_form'

#
# Health Savings Accounts
#
class Form8889 < TaxForm

  NAME = '8889'

  def year
    2019
  end

  def initialize(manager, hsa_form)
    super(manager)
    @hsa_form = hsa_form
    @bio = forms('Biographical').find { |f|
      f.line[:ssn] == @hsa_form.line[:ssn]
    }
  end

  def compute
    set_name
    line[:ssn] = @hsa_form.line[:ssn]

    line["1_#{compute_family_or_self}"] = 'X'
    line[2] = @hsa_form.line[:contributions]
    hdhp_last_month_forms = forms('1095-B') { |f|
      f.line[:hdhp?] == true && f.line[:months, :all].include?('dec')
    }
    if hdhp_last_month_forms.any? { |f| f.line[:coverage] == 'family' }
      line[3] = 7000
    elsif hdhp_last_month_forms.any? { |f| f.line[:coverage] == 'individual' }
      line[3] = 3500
    else
      raise "Form 8889, line 3 not implemented where last-month rule not met"
    end

    assert_question('Do you or your spouse have an Archer MSA?', false)
    line[4] = 0
    line[5] = line3 - line4

    allocate_hsa_limit # Line 6

    if age(@bio) >= 55
      raise "Over-55 HSA contribution increase not implemented"
    end

    line[8] = sum_lines(6, 7)

    line[9] = employer_contributions
    assert_question(
      "Did you make a qualified distribution from an IRA to an HSA?", false
    )
    line[11] = sum_lines(9, 10)
    line[12] = line8 - line11
    line[13] = [ line2, line12 ].min
    if line2 > line13
      raise "Excess HSA contribution not implemented"
    end

    assert_no_forms('1099-SA') # Part II

    # Part III is not implemented because it is assumed that the last-month rule
    # was met.

  end

  def compute_family_or_self
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
        return 'family' if months.include?('dec')
        family_months &= months
      when 'individual'
        indiv_months &= months
      else
        raise "Unknown value for Form 1095-B coverage: #{f.line[:coverage]}"
      end
    end
    indiv_months -= family_months
    return family_months.count >= indiv_months.count ? 'family' : 'self'
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
        @bio.line[:first_name] + ":"
      )
      raise "Invalid HSA limit allocation" if line[6] > line[5]
    end

  end

  def employer_contributions
    total = BlankZero
    forms('W-2').each do |f|
      next unless f.line[:a] == @bio.line[:ssn]
      l12w = f.line['12.code', :all].index('W')
      next unless l12w
      total += f.line[12, :all][l12w]
    end
    return total
  end

end
