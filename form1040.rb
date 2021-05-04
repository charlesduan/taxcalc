require 'date'

require_relative 'tax_table'
require_relative 'tax_form'
require_relative 'filing_status'
require_relative 'form1040_1'
require_relative 'form1040_2'
require_relative 'form1040_3'
require_relative 'form1040_a'
require_relative 'form1040_b'
require_relative 'form1040_c'
require_relative 'form1040_d'
require_relative 'form1040_e'
require_relative 'form1040_se'
require_relative 'form6251'
require_relative 'form8959'
require_relative 'form8960'
require_relative 'form8995'
require_relative 'form8995a'
require_relative 'ira_analysis'
require_relative 'qbi_manager'
require_relative 'amt_test_worksheet'

class Form1040 < TaxForm

  NAME = '1040'

  def year
    2020
  end

  MONTHS = %w(jan feb mar apr may jun jul aug sep oct nov dec)

  def initialize(manager)
    super(manager)
  end

  attr_reader :force_itemize

  attr_reader :status, :bio, :sbio

  def full_name
    line[:first_name] + ' ' + line[:last_name]
  end

  #
  # Some schedules are used in so many different places that it makes sense to
  # compute them early so that other forms can be sure that they exist if
  # needed.
  #
  def compute_early_schedules
    compute_form('1040 Schedule C')
    compute_form('1040 Schedule SE')
  end

  def compute


    @bio = forms('Biographical').find { |x| x.line[:whose] == 'mine' }
    @sbio = forms('Biographical').find { |x| x.line[:whose] == 'spouse' }

    @status = FilingStatus.for(interview("Enter your filing status:"))
    line["status.#{status.name}"] = 'X'

    if @status.is('mfs')
      line["status.name"] = @sbio.line[:first_name] + ' ' + \
        @sbio.line['last_name']
    elsif status.is('hoh')
      line['status.name'] = interview(
        'Name of head-of-household qualifying child, if not a dependent:'
      )
    end

    copy_line(:first_name, @bio)
    copy_line(:last_name, @bio)

    line[:ssn] = @bio.line[:ssn]

    if @status.is('mfj')
      copy_line(:first_name, @sbio)
      copy_line(:last_name, @sbio)
    end
    if @status.is(%w(mfj mfs))
      line[:spouse_ssn] = @sbio.line[:ssn]
      box_line(:spouse_ssn, 3, '-')
    end

    copy_line('home_address', @bio)
    copy_line('apt_no', @bio)
    copy_line('city_zip', @bio)
    copy_line('foreign_country', @bio)
    copy_line('foreign_state', @bio)
    copy_line('foreign_zip', @bio)

    line['campaign.you'] = 'X' if interview(
      'Do you want to donate to the Presidential Election Campaign?'
    )
    line['campaign.spouse'] = 'X' if @status.is('mfj') && interview(
      'Does your spouse want to donate to the Presidential Election Campaign?'
    )

    line['more_than_4_deps'] = 'X' if forms('Dependent').count > 4

    if interview("Can someone claim you as a dependent?")
      line['ysd.dependent'] = 'X'
    end
    if interview("Can someone claim your spouse as a dependent?")
      line['ssd.dependent'] = 'X'
    end

    if interview("Did you transact in virtual currency?")
      line['bitcoin.yes'] = 'X'
    else
      line['bitcoin.no'] = 'X'
    end

    @force_itemize = false
    if status.is('mfs')
      itemize = interview('Do you want to itemize deductions?')
      @force_itemize = true if itemize
      line['ssd.isrdsa'] = 'X' if itemize || interview(
        'Are you a dual-status alien?'
      )
    end

    if @bio.line[:birthday] < Date.new(@manager.year - 64, 1, 2)
      line['ysd.65yo'] = 'X'
    end
    line['ysd.blind?'] = 'X' if @bio.line[:blind?]
    if @sbio.line[:birthday] < Date.new(@manager.year - 64, 1, 2)
      line['ssd.65yo'] = 'X'
    end
    line['ssd.blind?'] = 'X' if @sbio.line[:blind?]

    #unless (MONTHS - forms('1095-B').lines[:months, :all]).empty?
    #  assert_question('Did you have health insurance the whole year?', true)
    #end
    #line['fyhcc'] = 'X'

    #
    # Dependents
    #

    forms('Dependent').each do |dep|
      ssn_parts = dep.line[:ssn].split(/-/)
      # TODO: Figure out boxed lines for tables
      row = {
        :dep_1 => dep.line[:name],
        :dep_2_1 => ssn_parts[0],
        :dep_2_2 => ssn_parts[1],
        :dep_2_3 => ssn_parts[2],
        :dep_3 => dep.line[:relationship],
      }
      case dep.line[:qualifying]
      when 'child' then row[:dep_4_ctc] = 'X'
      when 'other' then row[:dep_4_other] = 'X'
      when 'none'
      else raise "Unknown dependent qualifying type #{dep.line[:qualifying]}"
      end
      add_table_row(row)
    end

    compute_early_schedules

    # Wages, salaries, tips
    line['1/wages'] = forms('W-2').lines(1, :sum)

    if has_form?(8958) && has_form?('Explanation of 8958')
      line['1*note'] = 'From Form 8958, Line 1'
    end

    sched_b = compute_form('1040 Schedule B')

    assert_no_forms('1099-OID')

    # Tax-exempt interest
    line['2a'] = forms('1099-INT').lines[8, :sum] + \
      forms('1099-DIV').lines[10, :sum]
    # Taxable interest
    line['2b/taxable_int'] = sched_b.line[4]

    # Qualified dividends
    line['3a/qualdiv'] = forms('1099-DIV') { |f|
      f.line['1b', :present]
    }.map { |f|
      unless f.line[:qexception?, :present]
        raise "Indicate that no exception applies to 1099-DIV " + \
          "with qualified dividends, using the qexception? line"
      end
      f.line[:qexception?] ? 0 : f.line['1b']
    }.inject(:+) + forms('1065 Schedule K-1').lines('6b', :sum)
    # Ordinary dividends
    line['3b/taxable_div'] = sched_b.line[6]

    # IRAs, pensions, and annuities
    ira_analysis = compute_form('IRA Analysis')
    line['4a'] = ira_analysis.line_total_distribs
    line['4b/taxable_ira'] = ira_analysis.line_taxable_distribs

    # Pensions and annuities
    assert_no_forms('SSA-1099', 'RRB-1099')
    #line['5b/taxable_pension'] = BlankZero
    #line['6b/taxable_ss'] = BlankZero

    # Capital gains/losses
    find_or_compute_form('1040 Schedule D') do |sched_d|
      line['7/cap_gain'] = sched_d.line[:fill!]
    end

    # Other income, Schedule 1
    sched_1 = compute_form('1040 Schedule 1')
    line[8] = sched_1.line[:add_inc]

    # Total income
    line['9/tot_inc'] = sum_lines(*%w(1 2b 3b 4b 5b 6b 7 8))

    #
    # Standard or itemized deduction. This needs to be done first in view of
    # line 10b.
    #
    choose_itemize = false
    unless @force_itemize
      if interview('Do you want the computer to choose whether to itemize?')
        choose_itemize = true
      else
        itemize = interview('Do you want to itemize deductions?')
        @force_itemize = true if itemize
      end
    end

    # Compute standard deduction
    %w(
      ysd.dependent ysd.65yo ysd.blind? ssd.dependent ssd.65yo ssd.blind?
    ).each do |l|
      if line[l, :present]
        raise "Cannot handle special standard deduction for #{l}"
      end
    end
    sd = status.standard_deduction

    # Compute Schedule A, the presence of which will indicate whether deductions
    # are to be itemized.
    if itemize || choose_itemize
      sched_a = compute_form('1040 Schedule A')
      unless itemize || sched_a.line[17] > sd
        @manager.remove_form(sched_a)
      end
    end

    #
    # Now continue with line 10.
    #
    line['10a'] = sched_1.line[:adj_inc]
    line['10b'] = sd_charitable_contributions
    line['10c'] = sched_1.sum_lines('10a', '10b')
    line['11/agi'] = line[9] - line['10c']

    line['12/deduction'] = sched_a ? sched_a.line_total : sd

    # Qualified business income deduction
    taxable_income = line_agi - line_deduction; # AGI minus deduction
    line['13/qbid'] = compute_form('QBI Manager').line[:deduction]

    # Total deductions
    line[14] = sum_lines(12, 13)
    # Taxable income
    line['15/taxinc'] = [ line[11] - line[14], 0 ].max

    #
    # PAGE 2
    #

    # Tax
    line['16/tax'] = compute_form('Tax Computation').line[:fill!]

    sched_2 = compute_form('1040 Schedule 2')
    line[17] = sched_2.line[:add_tax] if sched_2
    line['18/pre_ctc_tax'] = sum_lines(16, 17)

    # Child tax credit and other credits
    ctcw = compute_form('Child Tax Credit Worksheet')
    line[19] = ctcw.line[:fill!]

    sched_3 = find_or_compute_form('1040 Schedule 3')
    line[20] = sched_3.line[:nref_credits] if sched_3
    line[21] = sum_lines(19, 20)

    line[22] = [ line[18] - line[21], 0 ].max

    line[23] = sched_2.line[:other_tax] if sched_2

    line['24/tot_tax'] = sum_lines(22, 23)


    line['25a'] = forms('W-2').lines(2, :sum)
    line['25b'] = [
      forms('1099-MISC').lines(4, :sum),
      forms('1099-INT').lines(4, :sum),
      forms('1099-DIV').lines(4, :sum),
      forms('1099-NEC').lines(4, :sum),
    ].sum
    with_form(8959) do |f|
      line['25c'] = f.line[:mc_wh]
    end
    line['25d'] = sum_lines(*%w(25a 25b 25c 25d))

    line[26] = forms('Estimated Tax').lines('amount', :sum) + \
      @manager.submanager(:last_year).form(1040).line(:refund_applied, :opt)

    # 27: earned income credit. Inapplicable for mfs status.
    # 28: refundable child tax credit.
    if ctcw.line['11.yes', :present] || ctcw.line['12.yes', :present]
      raise "Refundable child tax credit not implemented"
    end
    # 29: American Opportunity (education) credit. Inapplicable for mfs status.
    with_or_without_form('1040 Schedule 3') do |f|
      line['18d'] = f.line[14] if f
    end
    # Recovery rebate credit.
    max_eip = status.double_mfj(1200) +
      500 * line[:dep_4_ctc, :all].count { |x| x == 'X' }
    if (line[:agi] - status.rrc_threshold) * 0.05 < max_eip
      raise "Recovery rebate credit not implemented"
    end

    line[31] = sched_3.line[:ref_credits] if sched_3

    line[32] = sum_lines(*27..31)
    line[33] = sum_lines('25d', 26, 32)

    if line[33] > line[24]

      # Refund
      line[34] = line[33] - line[24]
      line['35a'] = line[34] # Assume it's all refunded
      if interview("Do you want your refund direct deposited?")
        line['35b'] = interview("Direct deposit routing number:")
        if interview("Direct deposit is to checking?")
          line['35c.checking'] = 'X'
        else
          line['35c.savings'] = 'X'
        end
        line['35d'] = interview("Direct deposit account number:")
      end
      line['36/refund_applied'] = line[34] - line['35a']
    else

      # Amount owed
      line[37] = line[24] - line[33]
      compute_penalty
    end

    line[:occupation] = @bio.line[:occupation]
    if @status.is('mfj')
      line[:spouse_occupation] = @sbio.line[:occupation]
    end
    copy_line('phone', @bio)

  end

  #
  # Computes the charitable contributions income adjustment if the standard
  # deduction is taken. This is a separate method because it is also used by the
  # Pub. 590-A Worksheet 1-1 computation.
  #
  def sd_charitable_contributions
    if !sched_a && has_form?("Charity Gift")
      raise "Line 10b charitable contribution adjustment not implemented"
    end
    return BlankZero
  end

  include TaxComputation

  #
  # These follow the instructions for the estimated tax penalty.
  #
  def compute_penalty

    # Under the definition of "tax shown on your return," these forms are
    # listed, but they are not implemented in this program.
    [ 7202, 8828, 4137, 5329, 8885, 8919 ].each do |f|
      raise "Penalty with form #{f} not implemented" if has_form?(f)
    end

    # Defined as "tax shown on your return" in the instructions
    tax_shown = line[:tot_tax] - sum_lines(*%w(17 18 19 30))
    with_form('1040 Schedule 3') do |f| tax_shown -= f.sum_lines(8, 11) end

    # The first test is given in the first bullet under "You may owe this
    # penalty"
    if line[37] > 1000 && line[37] > 0.1 * tax_shown

      ly = @manager.submanager(:last_year)
      # Last year's tax shown, defined under "tax shown on your 20xx return"
      last_year_tax = ly.form(1040).line_16 - \
        ly.form(1040).sum_lines(*%w(18a, 18b, 18c)) - \
        ly.form('1040 Schedule 3').sum_lines(9, 12)

      # First test under the exception.
      unless last_year_tax == 0

        # Second test under the exception: calculate threshold
        penalty_threshold = last_year_tax
        last_year_agi = ly.form(1040).line[7]
        if last_year_agi > status.halve_mfs(150000)
          penalty_threshold = (1.1 * last_year_tax)
        end

        # Second test: Calculate payments
        tax_paid = sum_lines('25d', 26)
        with_form('1040 Schedule 3') do |f|
          tax_paid += line[10, :opt]
        end

        # Second test: comparison
        unless tax_paid >= penalty_threshold
          warn "Penalty computation not implemented"
        end

      end
    end
  end

end

#
# From Form 1040, line 19 instructions
#
class ChildTaxCreditWorksheet < TaxForm
  NAME = 'Child Tax Credit Worksheet'

  def year
    2020
  end

  def compute
    f1040 = form(1040)

    #
    # Part 1
    #

    if f1040.line[:dep_4_ctc, :present]
      line['1num'] = f1040.line[:dep_4_ctc, :all].count { |x| x == 'X' }
      line[1] = line['1num'] * 2000
    end

    if f1040.line[:dep_4_other, :present]
      line['2num'] = f1040.line[:dep_4_other, :all].count { |x| x == 'X' }
      line[2] = line['2num'] * 500
    end

    line[3] = sum_lines(1, 2)
    # No point in calculating the credit if there won't be one
    if line[3] == 0
      line[:fill!] = 0
      return
    end

    # Income limits
    line[4] = f1040.line_agi
    line[5] = f1040.status.double_mfj(200_000)
    if line[4] > line[5]
      line['6.yes'] = 'X'
      l6 = line[4] - line[5]
      if l6 % 1000 == 0
        line[6] = l6
      else
        line[6] = l6.round(-3) + 1000
      end
      line[7] = (line[6] * 0.05).round
    else
      line['6.no'] = 'X'
      line[7] = 0
    end

    if line[3] > line[7]
      line['8.yes'] = 'X'
      line[8] = line[3] - line[7]
    else
      line['8.no'] = 'X'
      line[:fill!] = BlankZero
      return
    end

    #
    # Part 2
    #

    line[9] = f1040.line[:pre_ctc_tax]

    find_or_compute_form('1040 Schedule 3') do |f|
      line['10_3_1'] = f.line[1, :opt]
      line['10_3_2'] = f.line[2, :opt]
      line['10_3_3'] = f.line[3, :opt]
      line['10_3_4'] = f.line[4, :opt]
    end
    with_form(5695) do |f|
      line['10_5695_30'] = f.line[30, :opt]
    end
    with_form(8910) do |f|
      line['10_8910_15'] = f.line[15, :opt]
    end
    with_form(8936) do |f|
      line['10_8936_23'] = f.line[23, :opt]
    end
    with_form('1040 Schedule R') do |f|
      line['10_r_22'] = f.line[22, :opt]
    end
    line[10] = sum_lines(*%w(
      10_3_1 10_3_2 10_3_3 10_3_4 10_5695_30 10_8910_15 10_8936_23 10_r_22
    ))

    if line[10] >= line[9]
      line['11.yes'] = 'X'
      line[:fill!] = 0
      return
    end
    line['11.no'] = 'X'
    line[11] = line[9] - line[10]

    if line[8] > line[11]
      line['12.yes'] = 'X'
      line[12] = line[11]
    else
      line['12.no'] = 'X'
      line[12] = line[8]
    end

    line[:fill!] = line[12]

  end
end

FilingStatus.set_param('standard_deduction',
                       single: 12_200, mfj: 24_400, mfs: :single,
                       hoh: 18_350, qw: :mfj)

FilingStatus.set_param('rrc_threshold',
                       single: 75_000, mfj: 150_000, mfs: 75_000,
                       hoh: 112_500, qw: 150_000)
