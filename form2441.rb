require 'tax_form'

#
# Childcare expense credit and income adjustment for child care benefits.
#
class Form2441 < TaxForm

  NAME = '2441'

  def year
    2025
  end

  def compute
    @computed_credit = false

    set_name_ssn

    if form(1040).status.is('mfs')
      mfs_except = interview(
        'Did you live apart from your spouse for the last 6 months of the year?'
      )
      if mfs_except
        line['A/mfs_except'] = 'X'
        line[:credit_not_permitted!] = false
      else
        line[:credit_not_permitted!] = true
      end
    else
      line[:credit_not_permitted!] = false
    end

    #
    # Line B (student/disabled deemed income) not implemented.
    #
    if interview("Were you or your spouse a student or disabled?")
      raise "Student/disabled income not implemented"
      line[:B] = 'X'
      # See Form 2441, line 5 instructions. You will have to compute the
      # spouse's considered monthly income in compute_earned_income.
    end

    #
    # Select qualifying persons. Disabled spouses and other dependents are not
    # considered here. If a child is age 13, then only certain expenses qualify,
    # but those are selected later.
    #
    @qual_persons = forms('Dependent') { |f|
      age(f) <= 13
    }

    line[:benefit_cap!] = case @qual_persons.count
                          when 0 then 0
                          when 1 then 3000
                          else        6000
                          end

    #
    # Part I. Add providers. Because the highest-paid three providers must be
    # listed first, they are sorted this way.
    #
    providers = forms('Dependent Care Provider').sort_by { |f|
      -f.line[:amount]
    }.select { |f|

      #
      # Check that there is a corresponding dependent and that the dependent was
      # less than age 13 when service was provided. First, find the
      # corresponding dependent.
      #
      dep = @qual_persons.find { |p| p.line[:name] == f.line[:dep_name] }
      unless dep
        raise "No qual. person for dependent care provider #{f.line[:name]}"
      end

      #
      # The cutoff is the child's 13th birthday.
      #
      cutoff = dep.line[:dob] >> (13 * 12)
      if f.line[:date] >= cutoff
        warn("Dep. care #{f.line[:name]} provided after age 13")
        false
      else
        true
      end
    }

    # If more than 3 providers, check the box and construct a continuation sheet
    if providers.count > 3
      line['I.over_3_providers'] = 'X'

      addl_list = providers[3..-1].map { |f|
        [
          "1(a): #{f.line[:name]}",
          ".br",
          "1(b): #{f.line[:address]}",
          ".br",
          "1(c): #{f.line[:tin]}",
          ".br",
          "1(d): #{f.line[:employee?] ? 'Yes' : 'No'}",
          ".br",
          "1(e): #{f.line[:amount]}",
          ".sp",
        ]
      }.flatten
      line[:addl_providers_explanation!, :all] = [
        'Additional Dependent Care Providers', *addl_list
      ]
    end

    # For the first three providers, add them onto the form
    providers[0, 3].each do |f|
      add_table_row({
        '1a' => break_lines(f.line[:name], 15),
        '1b' => break_lines(f.line[:address], 28),
        '1c' => f.line[:tin],
        (f.line[:employee?] ? '1d.yes' : '1d.no') => 'X',
        '1e' => f.line[:amount]
      })
    end

    compute_part_iii
  end

  # Part III. Compute employer benefits.
  def compute_part_iii

    line_12 = forms('W-2').lines[10, :sum]
    confirm("No self-employer offered dependent care benefits")

    with_form("Dependent Care Benefit Use") do |form|
      line[13] = form.line[:last_year_grace_period_use]
    end

    # Determine if Part III is required; return otherwise
    return if line_12 == 0 && line[13, :opt] == 0

    # At this point we have to fill in Part III, so set lines and variables
    line[12] = line_12
    place_lines(13)
    @use_form = form("Dependent Care Benefit Use")

    # This is computed early to figure line 14.
    line[16] = forms('Dependent Care Provider').lines(:fsa, :sum)

    # The forfeited/carryover amount is whatever wasn't spent.
    line[14] = sum_lines(12, 13) - line[16]
    line[15] = sum_lines(12, 13) - line[14, :opt]

    place_lines(16)

    line[17] = [ line[15], line[16] ].min

    compute_earned_income(18, 19)

    line[20] = [ line[17], line[18], line[19], 0 ].min
    line[21] = [
      form(1040).status.halve_mfs(5000), @use_form.line[:max_contrib]
    ].min

    line['22.no'] = 'X'
    line[22] = BlankZero
    line[23] = line[15] - line[22]

    line['24/ded_benefit'] = [ line[20], line[21], line[22] ].min
    if line[24] > 0
      raise "Deduction for this benefit must be added to Schedule C, E, or F"
    end

    line['25/excl_benefit'] = [ line[20], line[21] ].min - (
      line['22.no', :present] ? 0 : line[24]
    )
    line['26/tax_benefit'] = [ line[23] - line[25], 0 ].max

    unless line[:credit_not_permitted!]

      line[27] = line[:benefit_cap!]
      line[28] = sum_lines(24, 25)
      line[29] = line[27] - line[28]
      if line[29] > 0

        compute_line_2
        line[30] = line[:tot_expenses!]
        line[31] = [ line[29], line[30] ].min

        line[3] = line[31]
      else
        #
        # No credit is allowed. To implement this, line 3 (qualifying expenses)
        # is set to zero.
        #
        confirm("You didn't pay #{year - 1} child care expenses in #{year}")
        line[3] = BlankZero
      end
    end

  end

  #
  # Computes line 2, qualifying persons. This sets line[:tot_expenses!] when
  # done. It may be called multiple times, but will only run the computation
  # once.
  #
  def compute_line_2
    return if line[:tot_expenses!, :present]
    #
    # Part II, first part.
    #
    # Add qualified persons.
    #
    if @qual_persons.count > 3
      raise "Not implemented"
    end
    @qual_persons.each do |person|
      fname, lname = split_name(person.line[:name])
      add_table_row({
        '2a.first' => fname,
        '2a.last' => lname,
        '2b' => person.line[:ssn],
        '2d' => forms('Dependent Care Provider').map { |provider|
          if provider.line[:dep_name] == person.line[:name]
            [ 0, provider.line[:amount] - provider.line[:fsa, :opt] ].max
          else
            BlankZero
          end
        }.sum
      })
    end
    line[:tot_expenses!] = line('2d', :sum)
  end

  #
  # Computes the dependent care credit, part II.
  #
  def compute_credit
    @computed_credit = true

    if line[:credit_not_permitted!]
      line['11/credit'] = BlankZero
      return
    end

    compute_line_2

    # If employer benefits were computed, then these lines differ
    if line[3, :present]
      line[4] = line[18]
      line[5] = line[19]
    else
      line[3] = [ line[:tot_expenses!], line[:benefit_cap!] ].min
      compute_earned_income(4, 5)
    end

    line[6] = [ line[3], line[4], line[5] ].min
    line[7] = form(1040).line[:agi]

    #
    # The line 8 formula is:
    #
    # - Take 15k off the AGI
    # - Every 2000 corresponds to a step of 1
    # - Max is 35, min is 20
    #
    # We don't need to worry about single-digit values since all values will be
    # between 20 and 35.
    #
    line[8] = [ 34 - ((line[7] - 15000) / 2000).floor, 35, 20 ].sort[1]

    line['9a'] = (line[6] * line[8] / 100.0).round
    line['9b'] = BlankZero
    line['9c'] = sum_lines(*%w(9a 9b))

    # This implements the Line 10 Credit Limit Worksheet.
    line10 = form(1040).line(:pre_ctc_tax) # In 2023, line 18.
    line10 -= form('1040 Schedule 3').line[:foreign_tax_credit, :opt]
    line10 -= form('1040 Schedule 3').line[:pship_tax_adjust, :opt]
    line[10] = [ line10, 0 ].max

    line['11/credit'] = [ line['9c'], line[10] ].min

    place_lines(*12..31)

  end


  #
  # Computes earned income for each individual spouse, and fills in lines
  # accordingly.
  #
  def compute_earned_income(my_line, spouse_line)

    line[my_line] = earned_income_for(@manager, my_ssn)

    status = form(1040).status
    if status.is?(:mfj)
      line[spouse_line] = earned_income_for(@manager, spouse_ssn)
      if line[:B, :present]
        raise "Computation of student/disabled income not implemented"
      end
    elsif status.is?(:mfs)
      if !line[:mfs_except, :present]
        line[spouse_line] = earned_income_for(
          @manager.submanager(:spouse), spouse_ssn
        )
      end
    else
      line[spouse_line] = line[my_line]
    end
  end

  #
  # Returns the earned income from a given FormManager for a given SSN.
  #
  def earned_income_for(manager, ssn)
    res = BlankZero
    res += manager.forms('W-2', ssn: ssn).lines(1, :sum)
    manager.with_form('1040 Schedule SE', ssn: ssn) do |f|
      res += f.line[:tot_inc] - f.line[:se_ded]
    end
    return res
  end


  def needed?
    # Form will be retained while the credit has not been computed.
    return true unless @computed_credit

    return true if line[11, :present] && line[11] != 0
    return true if line[12] != 0
    return true if line[13] != 0
    return true if line[14] != 0
    return false
  end

end
