require_relative 'tax_form'
require_relative 'form1040_e'
require_relative 'pub560'

#
# Form 1040 Schedule 1: Additional Income and Adjustments
#
class Form1040_1 < TaxForm

  NAME = '1040 Schedule 1'

  def year
    2023
  end

  def compute
    set_name_ssn

    #
    # Part I: Additional Income
    #

    if @manager.has_form?('1099-G')
      line['1/taxrefund'] = compute_1099g
    end
    # If this line ever includes refunds for taxes other than income taxes, line
    # 2b on Form 6251 (AMT) needs to be adjusted

    if has_form?(:Alimony)
      raise "Alimony forms not implemented"
      #line['2a'] = forms(:Alimony).lines(:amount, :sum)
    else
      line['2a/alimony'] = BlankZero
    end

    with_form('1040 Schedule C') do |sch_c|
      line['3/bus_inc'] = sch_c.line(:net_profit)
    end

    # Line 4 is assumed to be zero; otherwise implement Form 4797
    confirm("No business property was sold or lost")
    line['4/other_gains'] = BlankZero

    with_form('1040 Schedule E') do |sched_e|
      line['5/rrerpst'] = sched_e.line[:tot_inc]
    end

    other_income

    # If line 8z ever includes tax refunds, give them line alias :other_tax,
    # because the AMT test worksheet uses it.

    line['10/add_inc'] = sum_lines(1, '2a', 3, 4, 5, 6, 7, 9)

  end

  #
  # Computes other income from various sources. A better way to implement this
  # would be to allow other forms to transmit callback procs to this form.
  #
  def other_income
    @expls, @amt = [], BlankZero

    #
    # Other income from Form 8889, HSA excess contributions
    #
    with_form(8889) do |f|
      f.other_income do |desc, amt|
        add_other_income(desc, amt)
      end
    end

    line['8z.expl/other_inc_expl'] = @expls.join("; ")
    line['8z/other_inc'] = @amt
    line[9] = sum_lines(*"8a".."8z")
  end

  def add_other_income(expl, amt)
    return if amt == 0
    @amt += amt
    @expls.push("#{expl}: #{amt}")
  end

  def compute_adjustments
    #
    # Part II: Adjustments
    #
    # This is in a separate method because ira_analysis.continue_computation
    # depends on Form 1040, line tot_inc, which depends on Schedule 1, line
    # add_inc computed above.
    #

    with_form(8889) do |f|
      line['13/hsa_adj'] = f.line[:hsa_ded]
    end

    if has_form?('1040 Schedule SE')
      line['15/se_tax_ded'] = forms('1040 Schedule SE').lines(:se_ded, :sum)
    end

    #
    # For the qualified plans deduction, we assume that any partnership
    # contributions were computed correctly (since they used the Pub. 560
    # Worksheet computation), and that there are no Schedule C businesses that
    # could make further contributions.
    #
    line[16] = forms('1065 Schedule K-1').sum { |f|
      f.match_table_value('13.code', 13, find: 'R', default: 0)
    }
    with_form('1040 Schedule C') { |f|
      raise "Schedule C qualified plans deduction not implemented"
    }

    # As a convenience to the IRA calculation, sum up all the adjustments so
    # far. The important feature is that the student loan interest deduction is
    # not included. See Pub. 590A, Worksheet 1-1.
    line['pre_ira_adjust!'] = sum_lines('19a', *11..18)

    ira_analysis = form('IRA Analysis')
    compute_more(ira_analysis, :continuation)
    line['20/ira_ded'] = ira_analysis.line[:deductible_contrib]

    student_loan_magi = form(1040).line[:tot_inc] - sum_lines(*11..20)
    if !form(1040).status.is(:mfs) && student_loan_magi < 185_000
      raise "Student loan interest deduction not implemented"
    end

    line['26/adj_inc'] = sum_lines('19a', *11..25)
  end

  #
  # Computes the taxable portion of any state tax refund. Generally this is
  # going to be zero, because the deductible portion of SALT is so small that
  # the SALT paid after the refund will still exceed the deductible portion. If
  # that is not the case, see the comment below.
  #
  def compute_1099g
    assert_no_lines('1099-G', 1, 4, 5, 6, 7, 9, 11)
    salt_recovery = forms('1099-G').lines(2, :sum)
    lym = @manager.submanager(:last_year)
    return BlankZero unless lym.has_form?('1040 Schedule A')
    lysa = lym.form('1040 Schedule A')

    # For 2021, change these to the named line number values
    if lysa.line_5d - salt_recovery < lysa.line_5e
      raise "SALT tax recovery not implemented"
      #
      # In case you need to implement this: Look at IRS Publication 525 and
      # Revenue Ruling 2019-11:
      #
      #   https://www.irs.gov/pub/irs-drop/rr-19-11.pdf
      #
      # Basically you need to figure what deduction would have been available
      # has the proper tax been paid, and the recovery income should be the
      # difference.
      #
    end
    return BlankZero
  end

end
