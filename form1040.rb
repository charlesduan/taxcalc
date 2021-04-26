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
    2019
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

    # Wages, salaries, tips
    line['1/wages'] = forms('W-2').lines(1, :sum)

    if has_form?(8958) && has_form?('Explanation of 8958')
      line['1*note'] = 'See attached explanation of line 1'
      line['1.explanation!', :all] = [
        'Explanation of Line 1 based on Form 8958'
      ] + form('Explanation of 8958').line[:explanation, :all]
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
    line['4d/taxable_pension'] = BlankZero

    # Capital gains/losses
    sched_d = find_or_compute_form('1040 Schedule D')
    if sched_d
      line['6/capgain'] = sched_d.line[:fill!]
    else
      line['6/capgain'] = BlankZero
    end

    # Other income, Schedule 1
    sched_1 = compute_form('1040 Schedule 1')
    line['7a/other_inc'] = sched_1.line_9

    # Total income
    line['7b'] = sum_lines(*%w(1 2b 3b 4b 5b 6 7a))

    # AGI
    sched_1.compute_adjustments
    line['8a/adjustments'] = sched_1.line_22
    line['8b/agi'] = line_7b - line_8a

    # Standard or itemized deduction
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

    # Compute itemized deduction
    if itemize || choose_itemize
      sched_a = compute_form('1040 Schedule A')

      if itemize || sched_a.line[17] > sd
        line['9/deduction'] = sched_a.line_total
      else
        @manager.remove_form(sched_a)
        line['9/deduction'] = sd
      end

    else
      line['9/deduction'] = sd
    end

    # Qualified business income deduction
    taxable_income = line_agi - line_deduction; # AGI minus deduction
    line['10/qbid'] = compute_form('QBI Manager').line[:deduction]

    # Total deductions
    line['11a'] = sum_lines(9, 10)
    # Taxable income
    line['11b/taxinc'] = [ line_8b - line_11a, 0 ].max

    #
    # PAGE 2
    #

    # Tax
    line['12a/tax'] = compute_tax

    sched_2 = compute_form('1040 Schedule 2')
    if sched_2
      line['12b'] = line['12a'] + sched_2.line[3]
    else
      line['12b'] = line['12a']
    end

    # Child tax credit and other credits
    line['13a'] = @manager.compute_form(
      'Child Tax Credit Worksheet'
    ).line[:fill!]
    compute_form('1040 Schedule 3')
    with_or_without_form('1040 Schedule 3') do |f|
      if f
        line['13b/credits'] = line['13a'] + f.line[7]
      else
        line['13b/credits'] = line['13a']
      end
    end

    line[14] = [ line['12b'] - line['13b'], 0 ].max

    line[15] = sched_2.line_10 if sched_2

    line[16] = sum_lines(14, 15)
    withholdings = forms('W-2').lines(2, :sum)
    with_or_without_form(8959) do |f|
      withholdings += f.line[24, :opt] if f
    end
    line[17] = withholdings

    # 18a: earned income credit. Inapplicable for mfs status.
    # 18b: child credit.
    with_form('Child Tax Credit Worksheet') do |f|
      if f.line['11.yes', :present] || f.line['12.yes', :present]
        raise "Refundable child tax credit not implemented"
      end
    end
    # 18c: American Opportunity (education) credit. Inapplicable for mfs status.
    with_or_without_form('1040 Schedule 3') do |f|
      line['18d'] = f.line[14] if f
    end

    line['18e'] = sum_lines(*%w(18a 18b 18c 18d))

    # Total payments
    line[19] = sum_lines(17, '18e')

    if line[19] > line[16]

      # Refund
      line[20] = line[19] - line[16]
      line['21a'] = line[20]
      if interview("Do you want your refund direct deposited?")
        line['21b'] = interview("Direct deposit routing number:")
        box_line('21b', 9)
        if interview("Direct deposit is to checking?")
          line['21c.checking'] = 'X'
        else
          line['21c.savings'] = 'X'
        end
        line['21d'] = interview("Direct deposit account number:")
        box_line('21d', 17)
      end
      line['22/refund_applied'] = BlankZero
    else

      # Amount owed
      line[23] = line[16] - line[19]
      compute_penalty
    end

    line[:occupation] = @bio.line[:occupation]
    if @status.is('mfj')
      line[:spouse_occupation] = @sbio.line[:occupation]
    end
    copy_line('phone', @bio)

  end

  include TaxComputation

  def compute_penalty
    [ 8828, 4137, 5329, 8885, 8919 ].each do |f|
      raise "Penalty with form #{f} not implemented" if has_form?(f)
    end
    tax_shown = line[16] - sum_lines(*%w(18a 18b 18c))
    with_form('1040 Schedule 3') do |f| tax_shown -= f.sum_lines(9, 12) end

    # Test if a penalty is owed. First check if the amount owed is over $1000
    # and also over 10% of tax shown.
    if line[23] > 1000 && line[23] > 0.1 * tax_shown

      ly = @manager.submanager(:last_year)
      # Last year's tax shown
      last_year_tax = ly.form(1040).line_15 - \
        ly.form(1040).sum_lines(*%w(17a, 17b, 17c)) - \
        ly.form('1040 Schedule 4').line(61, :opt) - \
        ly.form('1040 Schedule 5').sum_lines(70, 73)

      unless last_year_tax == 0
        penalty_threshold = last_year_tax
        last_year_agi = ly.form(1040).line[7]
        if last_year_agi > status.halve_mfs(150000)
          penalty_threshold = (1.1 * last_year_tax)
        end

        tax_paid = line[17]
        with_or_without_form('1040 Schedule 3') do |f|
          tax_paid += f.sum_lines(8, 11) if f
        end
        unless tax_paid >= penalty_threshold
          warn "Penalty computation not implemented"
        end

      end
    end
  end

end

class ChildTaxCreditWorksheet < TaxForm
  NAME = 'Child Tax Credit Worksheet'

  def year
    2019
  end

  def compute
    f1040 = form(1040)
    if f1040.line[:dep_4_ctc, :present]
      line['1num'] = f1040.line[:dep_4_ctc, :all].count { |x| x == 'X' }
      line[1] = line['1num'] * 2000
    end

    if f1040.line[:dep_4_other, :present]
      line['2num'] = f1040.line[:dep_4_other, :all].count { |x| x == 'X' }
      line[2] = line['2num'] * 500
    end

    line[3] = sum_lines(1, 2)
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

    line[9] = f1040.line['12b']

    with_form('1040 Schedule 3') do |f|
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
                       12_200, 24_400, :single, 18_350, :mfj)

