require 'tax_form'

#
# Childcare expense credit and income adjustment for child care benefits.
#
class Form2441 < TaxForm

  NAME = '2441'

  def year
    2023
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
    qual_persons = forms('Dependent') { |f| age(f) <= 12 }

    #
    # Part I. Add providers.
    #
    forms('Dependent Care Provider').each do |f|
      unless qual_persons.map { |p| p.line[:ssn] }.include?(f.line[:dep_ssn])
        raise "Dependent care provider #{name} not for qualifying person"
      end

      if f.line[:address].length < 30
        address1, address2 = f.line[:address], nil
      elsif f.line[:address] = /\A.{0,30}\s+/
        address1, address2 = $&, $'
      else
        address1, address2 = f.line[:address][0, 30], f.line[:address][30..-1]
      end
      add_table_row({
        '1a' => f.line[:name],
        '1b.top' => address1,
        '1b.bot' => address2,
        '1c' => f.line[:tin],
        '1d.yes' => f.line[:employee?] ? 'X' : nil,
        '1d.no' => f.line[:employee?] ? nil : 'X',
        '1e' => f.line[:amount]
      }.compact)
    end

    #
    # Part II, first part.
    #
    # Add qualified persons. It is unclear whether the amounts in line 2d should
    # reflect the entire amount expended for each qualified person, or the
    # amounts less employer benefits as the line 30 instructions specify.
    #
    qual_persons.each do |p|
      fname, lname = p.line[:name].reverse.split(/\s+/, 2).map(
        &:reverse
      ).reverse
      add_table_row({
        '2a.first' => fname,
        '2a.last' => lname,
        '2b' => p.line[:ssn],
        '2d' => forms('Dependent Care Provider') { |f|
          f.line[:dep_ssn] == p.line[:ssn]
        }.lines(:amount, :sum)
      })
    end

    line[:tot_expenses!] = line('2d', :sum)
    if line[:tot_expenses!] != line('1e', :sum)
      raise "Inconsistency in dependent care expenses"
    end

    # Part III. Compute employer benefits.

    line[12] = forms('W-2').lines[10, :sum]

    confirm("No self-employer offered dependent care benefits")

    @use_form = form("Dependent Care Benefit Use")
    line[13] = @use_form.line[:last_year_grace_period_use]
    line[14] = @use_form.line[:this_year_unused]
    line[15] = sum_lines(12, 13) - line[14, :opt]

    line[16] = line[:tot_expenses!, :sum]
    line[17] = [ line[15], line[16] ].min

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

      line[27] = line['2b', :all].count >= 2 ? 6000 : 3000
      line[28] = sum_lines(24, 25)
      line[29] = line[27] - line[28]
      if line[29] > 0

        line[30] = line[:tot_expenses!] - line[28]
        line[31] = [ line[29], line[30] ].min

        line[3] = line[31]
      else
        #
        # No credit is allowed. To implement this, line 3 (qualifying expenses)
        # is set to zero.
        #
        confirm("You didn't pay 2022 child care expenses in 2023")
        line[3] = BlankZero
      end
    end

  end

  #
  # Computes the dependent care credit, part II.
  #
  def compute_credit
    @computed_credit = true

    if line[:credit_not_permitted!]
      line['11/credit'] = BlankZero
    end

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
