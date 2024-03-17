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

  def compute_credit
    return if line[:credit_not_permitted!]
    raise "Not implemented"
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

    line[16] = line['1e', :sum]
    line[17] = [ line[15], line[16] ].min

    line[18] = compute_earned_income(@manager, my_ssn)

    if form(1040).status.is?(:mfs)
      if !line[:mfs_except, :present]
        line[19] = compute_earned_income(
          @manager.submanager(:spouse), spouse_ssn
        )
      end
    elsif form(1040).status.is?(:mfj)
      line[19] = compute_earned_income(@manager, spouse_ssn)
      if [ line[18], line[19] ].min < 5000
        if interview("Were you or your spouse a student or disabled?")
          raise "Student/disabled income not implemented"
          # See Form 2441, line 5 instructions
        end
      end
    else
      line[19] = line[18]
    end
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
    raise "Lines 27-31 not implemented"

  end

  def compute_earned_income(manager, ssn)
    res = 0
    # The instructions here call for using form lines for both spouses, but that
    # would require computing each spouse's forms before getting to this one. To
    # avoid that, the computations are done here based on the raw input forms
    # instead.
    res += manager.forms('W-2') { |f| f.line[:a] == ssn }.lines(1, :sum)

    manager.forms('1040 Schedule SE') do |f|
      next unless f.line[:ssn] == ssn
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
