require 'tax_form'

#
# Childcare expense credit and income adjustment for child care benefits.
#
class Form2441 < TaxForm

  NAME = '2441'

  def year
    2024
  end

  def compute
    @computed_credit = false

    set_name_ssn

    if form(1040).status.is('mfs')
      mfs_except = interview(
        'Did you live apart from your spouse for the last 6 months of the year?'
      )
      if mfs_except
        line[:mfs_except] = 'X'
        line[:credit_not_permitted!] = false
      else
        line[:credit_not_permitted!] = true
      end
    else
      line[:credit_not_permitted!] = false
    end

    # Disabled spouses and other dependents are not considered here.
    @qual_persons = forms('Dependent') { |f| age(f) <= 12 }

    #
    # Part I. Add providers. Because the highest-paid three providers must be
    # listed first, they are sorted this way.
    #
    providers = forms('Dependent Care Provider').sort_by { |f|
      -f.line[:amount]
    }

    # Check that all providers match a dependent
    providers.each do |f|
      unless @qual_persons.map { |p| p.line[:name] }.include?(f.line[:dep_name])
        raise "Dependent care provider #{name} not for qualifying person"
      end
    end

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
        '1d.yes' => f.line[:employee?] ? 'X' : nil,
        '1d.no' => f.line[:employee?] ? nil : 'X',
        '1e' => f.line[:amount]
      }.compact)
    end
    compute_part_iii
  end

  # Part III. Compute employer benefits.
  def compute_part_iii

    line[12] = forms('W-2').lines[10, :sum]
    confirm("No self-employer offered dependent care benefits")

    @use_form = form("Dependent Care Benefit Use")
    line[13] = @use_form.line[:last_year_grace_period_use]
    line[14] = @use_form.line[:this_year_unused]
    line[15] = sum_lines(12, 13) - line[14, :opt]

    # If there are no relevant benefits, then this section is unnecessary.
    return if (12..15).all? { |l| line[l] == 0 }

    line[16] = forms('Dependent Care Provider').lines(:fsa, :sum)
    line[17] = [ line[15], line[16] ].min
    if line[16] != line[17]
      raise "Dependent care FSA numbers don't add up"
    end

    compute_earned_income(18, 19)

    line[20] = [ line[17], line[18], line[19] ].min
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

      line[27] = @qual_persons.count >= 2 ? 6000 : 3000
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
            provider.line[:amount] - provider.line[:fsa, :opt]
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
    end

    compute_line_2

    # If employer benefits were computed, then these lines differ
    if line[3, :present]
      line[4] = line[18]
      line[5] = line[19]
    else
      line[3] = line['2b', :all].count >= 2 ? 6000 : 3000
      compute_earned_income(4, 5)
    end

    line[6] = [ line[3], line[4], line[5] ].min
    line[7] = form(1040).line[:agi]

    # If AGI is under $43,000, then a scaling fraction of line 8 may be higher.
    # This calculation has not been implemented.
    if line[7] < 43_000
      raise "Dependent Care Credit fraction not implemented"
    end
    line[8] = 20

    line['9a'] = (line[6] * line[8] / 100.0).round
    line['9b'] = BlankZero
    line['9c'] = sum_lines(*%w(9a 9b))

    # This implements the Line 10 Credit Limit Worksheet.
    line10 = form(1040).line(:pre_ctc_tax) # In 2023, line 18.
    line10 -= form('1040 Schedule 3').line[:foreign_tax_credit]
    line10 -= form('1040 Schedule 3').line[:pship_tax_adjust, :opt]
    line[10] = [ line10, 0 ].max

    line['11/credit'] = [ line['9c'], line[10] ].min

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
      if [ line[my_line], line[spouse_line] ].min < 5000
        if interview("Were you or your spouse a student or disabled?")
          raise "Student/disabled income not implemented"
          # See Form 2441, line 5 instructions
        end
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
