require_relative 'tax_form'
require_relative 'form1040_e'

#
# Form 1040 Schedule 1: Additional Income and Adjustments
#
class Form1040_1 < TaxForm

  NAME = '1040 Schedule 1'

  def year
    2020
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

    # Line 4 is assumed to be zero; otherwise implement line 4797
    confirm("No business property was sold or lost")
    line['4/other_gains'] = BlankZero

    with_form('1040 Schedule E') do |sched_e|
      line['5/rrerpst'] = sched_e.line[:tot_inc]
    end

    other_income
    line['9/add_inc'] = sum_lines(1, '2a', 3, 4, 5, 6, 7, 8)

  end

  #
  # Computes other income from various sources. A better way to implement this
  # would be to allow other forms to transmit callback procs to this form.
  #
  def other_income
    @expls, @amt = [], BlankZero

    #
    # Other income from Form 8889
    #
    with_form(8889) do |f|
      f.other_income do |desc, amt|
        add_other_income(desc, amt)
      end
    end

    line['8.expl/other_tax_expl'] = @expls.join("; ")
    line['8/other_tax'] = @amt
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
      line[12] = f.line[:hsa_ded]
    end

    with_form('1040 Schedule SE') do |sched_se|
      line[14] = sched_se.line[:se_ded]
    end

    # Line 15 is where the self-employment IRA contributions go
    if year > 2020
      raise("Implement solo 401(k) here")
      raise("Also implement Form 5500-EZ at this time")
    end

    ira_analysis = form('IRA Analysis')
    compute_more(ira_analysis, :continuation)
    line[19] = ira_analysis.line[:deductible_contrib]

    # Line 20
    if !form(1040).status.is(:mfs)
      raise "Student loan interest deduction not implemented"
    end

    line['22/adj_inc'] = sum_lines(
      10, 11, 12, 13, 14, 15, 16, 17, '18a', 19, 20, 21
    )
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
