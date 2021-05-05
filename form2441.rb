require 'tax_form'

#
# Childcare expense credit and income adjustment for child care benefits.
#
class Form2441 < TaxForm

  NAME = '2441'

  def year
    2020
  end

  def compute
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
    if line[:credit_not_permitted!]
      line['1a'] = 'None'
      return
    end
    raise "Not implemented"
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
    return if line[12] = 0

    @use_form = form("Dependent Care Benefit Use")
    line[13] = @use_form.line[:last_year_grace_period_use]
    line[14] = @use_form.line[:this_year_unused]
    line[15] = sum_lines(12, 13, 14)

    line[16] = @use_form.line[:qualified_expenses]
    line[17] = [ line[15], line[16] ].min

    if form(1040).status.is?(:mfj)
      raise "Need to implement separation of spouses' earned income"
    end

    line[18] = compute_earned_income(@manager)
    if form(1040).status.is?(:mfs) && !line[:mfs_except, :present]
      line[19] = compute_earned_income(submanager(:spouse))
      line[20] = [ line[17], line[18], line[19] ].min
      line[21] = 2500
    else
      line[19] = line[18]
      line[20] = [ line[17], line[18], line[19] ].min
      line[21] = 5000
    end

    line['22.no'] = 'X'
    line[22] = BlankZero
    line[23] = line[15] - line[22]

    line['24/ded_benefit'] = [ line[20], line[21], line[22] ].min
    l25 = [ line[20], line[21] ].min
    l25 -= line[24] unless line['22.no', :present]
    if line[24] > 0
      raise "Deduction for this benefit must be added to Schedule C, E, or F"
    end

    line['25/excl_benefit'] = l25
    line['26/tax_benefit'] = [ line[23] - line[25], 0 ].max

    return if line[:credit_not_permitted!]
    raise "Lines 27-31 not implemented"

  end

  def compute_earned_income(manager)
    res = 0
    # The instructions here call for using form lines for both spouses, but that
    # would require computing each spouse's forms before getting to this one. To
    # avoid that, the computations are done here based on the raw input forms
    # instead.
    res += manager.forms('W-2').lines(1, :sum)
    res += manager.forms('1065 Schedule K-1').lines(14, :sum)

    if manager.has_form?('1040 Schedule C')
      res += manager.form('1040 Schedule C').line[:tot_inc]
    else
      # Fake a computation of Schedule C
      fake_schedule_c = manager.compute_form('1040 Schedule C')
      if fake_schedule_c
        res += fake_schedule_c.line[:tot_inc]
        manager.remove_form(fake_schedule_c)
      end
    end

    # TODO Should compute a fake Schedule SE if it's not present
    if manager.has_form?('1040 Schedule SE')
      res -= manager.form('1040 Schedule SE').line[:se_ded]
    end
  end



  def needed?
    return true if line[11, :present]
    return true if line[12] != 0
    return false
  end

end
