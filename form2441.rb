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

    compute_providers
    compute_qualifying_persons
    compute_benefits
    compute_credit

    # TODO: Rearrange Part III lines

  end

  # Part I
  def compute_providers
    forms('Dependent Care Provider').each do |f|
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
  end

  # Part II
  def compute_qualifying_persons
    qual_persons = forms('Dependent') { |f| age(f) <= 12 }
    # Disabled spouses and other dependents are not considered here.
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
    if line[:tot_expenses!] != line('3d', :sum)
      raise "Inconsistency in dependent care expenses"
    end

  end


  def compute_credit
    #
    # Right now this depends on aspects of Form 1040, which can't work because
    # this form is computed before the 1040.
    #
    raise "FIX THIS"
    return if line[:credit_not_permitted!]

    if line[3, :present]
      line[4] = line[18]
      line[5] = line[19]
    else
      line[3] = line['2b', :all].count >= 2 ? 6000 : 3000
      compute_earned_income(4, 5)
    end

    line[6] = [ line[3], line[4], line[5] ].min
    line[7] = form(1040).line[:agi]
    if line[7] < 43_000
      raise "Dependent Care Credit fraction not implemented"
    end
    line[8] = 20
    line['9a'] = (line[6] * line[8] / 100.0).round
    line['9b'] = BlankZero

    # This implements the Line 10 Credit Limit Worksheet.
    line10 = form(1040).line(:pre_ctc_tax)
  end

  # Part III
  def compute_benefits

    # TODO: Add sole proprietorship/partnership benefits as necessary. See lines
    # 22 and 24 if this is done.
    line[12] = forms('W-2').lines[10, :sum]

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

    return if line[:credit_not_permitted!]

    line[27] = line['2b', :all].count >= 2 ? 6000 : 3000
    line[28] = sum_lines(24, 25)
    line[29] = line[27] - line[28]
    return if line[29] <= 0

    line[30] = line[:tot_expenses!] - line[28]
    line[31] = [ line[29], line[30] ].min

    line[3] = line[31]
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
  def earned_income_for(manager, ssn)
    res = BlankZero
    res += manager.forms('W-2', ssn: ssn).lines(1, :sum)
    manager.with_form('1040 Schedule SE', ssn: ssn) do |f|
      res += f.line[:tot_inc] - f.line[:se_ded]
    end
    return res
  end




  def needed?
    return true if line[11, :present]
    return true if line[12] != 0
    return true if line[13] != 0
    return true if line[14] != 0
    return false
  end

end
