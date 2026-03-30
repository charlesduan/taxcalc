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
require_relative 'form2441'
require_relative 'form6251'
require_relative 'form8812'
require_relative 'form8889'
require_relative 'form8959'
require_relative 'form8960'
require_relative 'form8995'
require_relative 'form8995a'
require_relative 'ira_analysis'
require_relative 'qbi_manager'
require_relative 'home_office'
require_relative 'amt_test_worksheet'
require_relative 'tax_computation'

class Form1040 < TaxForm

  NAME = '1040'

  def year
    2025
  end

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
    compute_form('Home Office Manager')

    if has_form?('Sole Proprietorship')
      forms('Sole Proprietorship').each do |sp|
        compute_form('1040 Schedule C', sp)
      end
    else
      assert_no_forms('1099-NEC', '1099-MISC')
      @manager.no_form('1040 Schedule C')
    end

    compute_form('1040 Schedule E')

    compute_form('1040 Schedule SE', @bio.line[:ssn])
    if @status.is?('mfj')
      compute_form('1040 Schedule SE', @sbio.line[:ssn])
    end

    compute_form(2441)
    compute_form(8889)
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
      line[:spouse_first_name] = @sbio.line[:first_name]
      line[:spouse_last_name] = @sbio.line[:last_name]
    end
    if @status.is(%w(mfj mfs))
      line[:spouse_ssn] = @sbio.line[:ssn]
    end

    copy_line('home_address', @bio)
    copy_line('apt_no', @bio)
    copy_line('city_zip', @bio)
    copy_line('foreign_country', @bio)
    copy_line('foreign_state', @bio)
    copy_line('foreign_zip', @bio)

    if line(:foreign_country, :present)
      if interview("Was your main home in the US for over half the year?")
        line[:us_home] = 'X'
      end
    else
      confirm("Your main home was in the US for over half the year")
      line[:us_home] = 'X'
    end

    line['campaign.you'] = 'X' if interview(
      'Do you want to donate to the Presidential Election Campaign?'
    )
    line['campaign.spouse'] = 'X' if @status.is('mfj') && interview(
      'Does your spouse want to donate to the Presidential Election Campaign?'
    )

    line['more_than_4_deps'] = 'X' if forms('Dependent').count > 4

    if interview("Did you transact in digital assets?")
      line['bitcoin.yes'] = 'X'
    else
      line['bitcoin.no'] = 'X'
    end

    #
    # Dependents
    #

    forms('Dependent').each do |dep|
      row = {
        :dep_1 => dep.line[:first_name],
        :dep_2 => dep.line[:last_name],
        :dep_3 => dep.line[:ssn],
        :dep_4 => dep.line[:relationship],
      }
      row[:dep_5a] = 'X' if dep.line[:where, :opt] == 'with'
      if row[:dep_5a] && line[:us_home, :present]
        row[:dep_6b] = 'X'
      end

      row[:dep_6_student] = 'X' if dep.line[:student?]
      row[:dep_6_disabled] = 'X' if dep.line[:disabled?]

      #
      # Is the named dependent a qualifying child? Note that qualifying
      # relatives aren't implemented. Additionally, it is assumed that any named
      # dependent satisfies the other requirements (didn't provide own support,
      # isn't filing a joint return, lived with you for over half the year).
      #
      case
      when age(dep) < 19
      when age(dep) < 24 && dep.line[:student?, :opt]
      when dep.line[:disabled?, :opt]
      else
        warn("#{dep.line[:name]} isn't a qualifying child")
        next
      end

      #
      # The remaining tests for qualifying children are not implemented.
      #
      # The tests for whether a qualifying child is a dependent are
      # not implemented.
      #

      #
      # Determine which credit applies.
      #
      if dep[:ssn, :present]
        if age(dep) < 17
          row[:dep_7_ctc] = 'X'
        else
          row[:dep_7_other] = 'X'
        end
      end

      add_table_row(row)
    end

    compute_early_schedules

    # Wages, salaries, tips
    wages = forms('W-2').lines(1, :sum)

    line['1a/w2s'] = wages
    if forms('W-2').any? { |f| f.line[:cp_split!, :present] }

      line['w2s*note'] = "Line 1 based on community property allocation " \
        "from Form 8958"
    end

    with_form(2441) { |f|
      line['1e'] = f.line[:tax_benefit]
    }

    line['1z/wages'] = sum_lines(*("1a".."1h"))

    sched_b = compute_form('1040 Schedule B')

    # Tax-exempt interest
    line['2a'] = forms('1099-INT').lines[8, :sum] + \
      forms('1099-DIV').lines[12, :sum] + \
      forms('1099-OID').lines[11, :sum]

    # Taxable interest
    line['2b/taxable_int'] = sched_b.line[:ord_int]

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
    line['3b/taxable_div'] = sched_b.line[:ord_div]

    # IRAs, pensions, and annuities
    compute_form('IRA Analysis', @bio.line[:ssn], @sbio && @sbio.line[:ssn])
    if status.is?('mfj')
      compute_form('IRA Analysis', @sbio.line[:ssn], @bio.line[:ssn])
    end
    ira_analyses = forms('IRA Analysis')
    line['4a'] = ira_analyses.lines[:total_distrib, :sum]
    line['4b/taxable_ira'] = ira_analyses.lines[:taxable_distrib, :sum]

    line['4c1'] = 'X' if ira_analyses.any? { |f| f.line[:rollover?] }

    #
    # Not worrying about qualified charitable distributions or HSA distributions
    #

    #
    # Pensions and annuities. If any 1099-Rs are received from a qualified plan,
    # then the IRA Analysis form may need to be generalized to deal with these.
    #
    assert_no_forms('SSA-1099', 'RRB-1099')
    #line['5b/taxable_pension'] = BlankZero
    #line['6b/taxable_ss'] = BlankZero

    # Capital gains/losses
    if has_form?('1099-B')
      compute_form('1040 Schedule D')
      line['7/cap_gain'] = with_form(
        '1040 Schedule D', otherwise: BlankZero
      ) do |sched_d|
        sched_d.line[:tot_gain]
      end
    end

    # Other income, Schedule 1
    sched_1 = compute_form('1040 Schedule 1')
    line[8] = sched_1.line[:add_inc]

    # Total income
    line['9/tot_inc'] = sum_lines(*%w(1z 2b 3b 4b 5b 6b 7 8))

    compute_more(sched_1, :adjustments)
    line[10] = sched_1.line[:adj_inc]
    # line['10b'] = sd_charitable_contributions # Appears to have sunsetted
    # line['10c'] = sched_1.sum_lines('10a', '10b')
    line['11a/agi'] = line[9] - line[10]

    #
    # PAGE 2
    #

    line['11b'] = line['11a']

    if interview("Can someone claim you as a dependent?")
      line['12a.you/ysd.dependent'] = 'X'
    end
    if interview("Can someone claim your spouse as a dependent?")
      line['12a.spouse/ssd.dependent'] = 'X'
    end

    unless status.is('mfj')
      line['12c.dsa'] = 'X' if interview('Are you a dual-status alien?')
    end
    if status.is('mfs')
      line['12c.isr'] = 'X' if interview(
        'Is your spouse itemizing on a separate return?'
      )
    end

    if age(@bio) >= 65
      line['12d.ysd.65yo/ysd.65yo'] = 'X'
    end
    line['12d.ysd.blind/ysd.blind'] = 'X' if @bio.line[:blind?]
    if @sbio
      if age(@sbio) >= 65
        line['12d.ssd.65yo/ssd.65yo'] = 'X'
      end
      line['12d.ssd.blind/ssd.blind'] = 'X' if @sbio.line[:blind?]
    end

    # Compute Schedule A, the presence of which will indicate whether deductions
    # are to be itemized.
    sched_a = compute_form('1040 Schedule A')
    if sched_a
      line['12e/deduction'] = sched_a.line[:total]
    else
      %w(
        ysd.dependent ysd.65yo ysd.blind ssd.dependent ssd.65yo ssd.blind
      ).each do |l|
        if line[l, :present]
          raise "Cannot handle special standard deduction for #{l}"
        end
      end
      line['12e/deduction'] = status.standard_deduction
    end

    # This line seems spurious
    # taxable_income = line_agi - line_deduction; # AGI minus deduction

    # Qualified business income deduction
    #
    line['13a/qbid'] = compute_form('QBI Manager').line[:deduction]

    # No Schedule 1-A deductions for line 13b

    # Total deductions
    line[14] = sum_lines('12e', '13a', '13b')
    # Taxable income
    line['15/taxinc'] = [ line['11b'] - line[14], 0 ].max

    # Tax
    line['16/tax'] = compute_form('Tax Computation').line[:tax]

    sched_2 = compute_form('1040 Schedule 2')
    line[17] = sched_2.line[:add_tax] if sched_2
    line['18/pre_ctc_tax'] = sum_lines(16, 17)

    # Form 8812 depends on Schedule 3.
    sched_3 = find_or_compute_form('1040 Schedule 3')

    # Child tax credit and other credits
    form8812 = compute_form('1040 Schedule 8812')
    line[19] = form8812.line[:ctc] if form8812

    line['20/nref_credits'] = sched_3.line[:nref_credits] if sched_3
    line[21] = sum_lines(19, 20)

    line['22/tax_after_credits'] = [ line[18] - line[21], 0 ].max

    line['23/other_tax'] = sched_2.line[:other_tax] if sched_2

    line['24/tot_tax'] = sum_lines(22, 23)


    line['25a'] = forms('W-2').lines(2, :sum)
    if forms('W-2').any? { |f| f.line[:cp_split!, :present] }
      line['25a*note'] = "Line 25a based on community property allocation " \
        "from Form 8958"
    end
    line['25b'] = [
      forms('1099-MISC').lines(4, :sum),
      forms('1099-INT').lines(4, :sum),
      forms('1099-DIV').lines(4, :sum),
      forms('1099-NEC').lines(4, :sum),
    ].sum
    with_form(8959) do |f|
      line['25c'] = f.line[:mc_wh]
    end
    line['25d/withholding'] = sum_lines(*%w(25a 25b 25c))

    line['26/est_tax'] = forms('Estimated Tax').lines('amount', :sum) + \
      @manager.submanager(:last_year).form(1040).line(:refund_applied, :opt)

    # 27a: earned income credit. Inapplicable for mfs status.
    unless status.is?('mfj')
      if line[:agi] < 68_675
        raise "Earned income credit not implemented"
      end
    end

    # 28: refundable child tax credit.
    if form8812
      compute_more(form8812, :actc)
      line[28] = form8812.line[:actc]
    end

    # 29: American Opportunity (education) credit. Inapplicable for mfs status.
    # Limit is based on Form 8863.
    unless status.is?('mfs')
      if line[:agi] < 180_000
        raise "American Opportunity Credit not implemented"
      end
    end

    # 30: adoption expenses

    line[31] = sched_3.line[:ref_credits] if sched_3

    line['32/ref_credits'] = sum_lines('27a', *28..31)
    line[33] = sum_lines('25d', 26, 32)

    compute_form("Penalty Analysis")

    if line[33] > line[24]

      # Refund
      line['34/tax_refund'] = line[33] - line[24]
      line['35a'] = line[34] # Assume it's all refunded
      
      with_form('Refund Direct Deposit') do |f|
        line['35b'] = f.line[:routing]
        line["35c.#{f.line[:type]}"] = 'X'
        line['35d'] = f.line[:account]
      end
      line['36/refund_applied'] = line[34] - line['35a']
    else

      # Amount owed
      f2210 = compute_form(2210)
      if f2210
        line['37/tax_owed'] = line[24] - line[33] + f2210.line[:penalty]
        line[38] = f2210.line[:penalty]
      else
        line['37/tax_owed'] = line[24] - line[33]
      end
    end

    line[:occupation] = @bio.line[:occupation]
    if @status.is('mfj')
      line[:spouse_occupation] = @sbio.line[:occupation]
    end
    copy_line('phone', @bio)

  end

end


FilingStatus.set_param('standard_deduction',
                       single: 15_750, mfj: 31_500, mfs: :single,
                       hoh: 23_625, qw: :mfj)

