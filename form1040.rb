require 'tax_table'
require 'tax_form'
require 'filing_status'
require 'form1040_1'
require 'form1040_2'
require 'form1040_3'
require 'form1040_4'
require 'form1040_5'
require 'form1040_a'
require 'form1040_b'
require 'form1040_d'
require 'form1040_e'
require 'form1040_se'
require 'form6251'
require 'form8959'
require 'form8960'
require 'ira_analysis'
require 'date'
require 'qbi_simplified_worksheet'
require 'amt_test_worksheet'

class Form1040 < TaxForm

  def name
    '1040'
  end

  def year
    2018
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

  def ssn
    %w(ssn_1 ssn_2 ssn_3).map { |x| line[x] }.join("-")
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

    line[:ssn_1], line[:ssn_2], line[:ssn_3] = @bio.line[:ssn].split(/-/)

    if interview("Can someone claim you as a dependent?")
      line['ysd.dependent'] = 'X'
    end
    if @bio.line[:birthday] < Date.new(@manager.year - 64, 1, 2)
      line['ysd.65yo'] = 'X'
    end
    line['ysd.blind?'] = 'X' if @bio.line[:blind?]

    if @status.is('mfj')
      copy_line(:first_name, @sbio)
      copy_line(:last_name, @sbio)
    end
    if @status.is(%w(mfj mfs))
      line[:spouse_ssn_1], line[:spouse_ssn_2], line[:spouse_ssn_3] = \
        @sbio.line[:ssn].split(/-/)
    end

    if interview("Can someone claim your spouse as a dependent?")
      line['ssd.dependent'] = 'X'
    end
    if @sbio.line[:birthday] < Date.new(@manager.year - 64, 1, 2)
      line['ssd.65yo'] = 'X'
    end
    line['ssd.blind?'] = 'X' if @sbio.line[:blind?]

    @force_itemize = false
    if status.is('mfs')
      itemize = interview('Do you want to itemize deductions?')
      @force_itemize = true if itemize
      line['ssd.isrdsa'] = 'X' if itemize || interview(
        'Are you a dual-status alien?'
      )
    end
    unless (MONTHS - forms('1095-B').lines[:months, :all]).empty?
      assert_question('Did you have health insurance the whole year?', true)
    end
    line['fyhcc'] = 'X'

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

    #
    # Dependents
    #

    line['more_than_4_deps'] = 'X' if forms('Dependent').count > 4
    forms('Dependent').each do |dep|
      ssn_parts = dep.line[:ssn].split(/-/)
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


    #
    # PAGE 2
    #

    line[1] = forms('W-2').lines(1, :sum)

    sched_b = compute_form(Form1040B)

    # Interest
    assert_no_forms('1099-OID')
    line['2a'] = forms('1099-INT').lines[8, :sum] + \
      forms('1099-DIV').lines[10, :sum]
    line['2b'] = sched_b.line[4]

    # Dividends
    line['3a'] = forms('1099-DIV') { |f| f.line['1b', :present] }.map { |f|
      unless f.line[:qexception?, :present]
        raise "Indicate that no exception applies to 1099-DIV " + \
          "with qualified dividends, using the qexception? line"
      end
      f.line[:qexception?] ? 0 : f.line['1b']
    }.inject(:+)
    line['3b'] = sched_b.line[6]

    # IRAs, pensions, and annuities
    ira_analysis = compute_form(IraAnalysis)
    line['4a'] = ira_analysis.sum_lines('15a', '16a')
    line['4b'] = ira_analysis.sum_lines('15b', '16b')

    assert_no_forms('SSA-1099', 'RRB-1099')

    sched_1 = compute_form(Form1040_1)

    # Total income
    line['6.add'] = sched_1.line[22]
    line[6] = sum_lines(*%w(1 2b 3b 4b 5b 6.add))

    # AGI
    sched_1.compute_adjustments
    line[7] = line6 - sched_1.line36

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

    %w(
      ysd.dependent ysd.65yo ysd.blind? ssd.dependent ssd.65yo ssd.blind?
    ).each do |l|
      if line[l, :present]
        raise "Cannot handle special standard deduction for #{l}"
      end
    end
    sd = status.standard_deduction
    if itemize || choose_itemize
      sched_a = compute_form(Form1040A)

      if itemize || sched_a.line[17] > sd
        line[8] = sched_a.line[17]
      else
        @manager.remove_form(sched_a)
        line[8] = sd
      end

    else
      line[8] = sd
    end

    # Qualified business income deduction
    taxable_income = line[7] - line[8]
    if taxable_income <= status.double_mfj(157_500)
      line[9] = compute_form(QBISimplifiedWorksheet).line[15]
    end
    line[10] = line[7] - sum_lines(8, 9)

    # Tax
    line['11a'] = compute_tax

    sched_2 = compute_form(Form1040_2)
    if sched_2
      line['11b'] = 'X'
      line[11] = line['11a'] + sched_2.line[47]
    else
      line[11] = line['11a']
    end

    compute_form(Form1040_3)

    # Child tax credit and other credits
    line['12a'] = @manager.compute_form(ChildTaxCreditWorksheet).line['fill']
    with_or_without_form('1040 Schedule 3') do |f|
      if f
        line['12b'] = 'X'
        line[12] = line['12a'] + f.line[55]
      else
        line[12] = line['12a']
      end
    end

    line[13] = line[11] - line[12]

    line[14] = compute_form(Form1040_4).line[64]

    line[15] = sum_lines(13, 14)
    line[16] = forms('W-2').lines(2, :sum)

    # 17a: earned income credit. Inapplicable for mfs status.
    # 17b: child credit.
    with_form('Child Tax Credit Worksheet') do |f|
      if f.line['11.yes', :present] || f.line['12.yes', :present]
        raise "Refundable child tax credit not implemented"
      end
    end
    # 17c: American Opportunity (education) credit. Inapplicable for mfs status.

    line['17_sch5'] = compute_form(Form1040_5).line[75]

    line[17] = sum_lines(*%w(17a 17b 17c 17_sch5))

    # Total payments
    line[18] = sum_lines(16, 17)

    if line[18] > line[15]

      # Refund
      line[19] = line[18] - line[15]
      line['20a'] = line[19]
      if interview("Do you want your refund direct deposited?")
        line['20b'] = interview("Direct deposit routing number:")
        if interview("Direct deposit is to checking?")
          line['20c.checking'] = 'X'
        else
          line['20c.savings'] = 'X'
        end
        line['20d'] = interview("Direct deposit account number:")
      end
    else

      # Amount owed
      line[22] = line[15] - line[18]
      compute_penalty
    end


  end


  def compute_tax
    if unearned_income > 2100
      raise "Form 8615 is not implemented"
    end

    if has_form?('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      if sched_d.line['20no', :present]
        line[:tax_method] = 'Sch D'
        return compute_tax_schedule_d # Not implemented; raises error
      elsif sched_d.line[15] > 0 && sched_d.line[16] > 0
        line[:tax_method] = 'QDCGTW'
        return compute_tax_qdcgt
      end
    elsif line['3a', :present] or form('1040 Schedule 1').line[13, :present]
      return compute_tax_qdcgt
    end

    # Default computation method
    return compute_tax_standard(line[10])
  end

  def unearned_income
    total = sum_lines(*%w(2b 3b))
    with_form('1040 Schedule 1') do |f|
      total += f.sum_lines(13, 14)
    end
    with_form('1040 Schedule E') do |f|
      total += f.sum_lines(26, '29a.h', '34a.d')
    end
    return total
  end

  def compute_tax_standard(income)
    if income < 100000
      line[:tax_method] = 'Table' unless line[:tax_method, :present]
      return compute_tax_table(income, status)
    else
      line[:tax_method] = 'TCW' unless line[:tax_method, :present]
      return compute_tax_worksheet(income)
    end
  end

  include TaxTable # This adds compute_tax_table

  def compute_tax_worksheet(income)
    raise 'Worksheet not applicable for less than $100,000' if income < 100000
    brackets = @status.tax_brackets
    raise "Cannot compute tax worksheet for your filing status" unless brackets
    brackets.each do |limit, rate, subtract|
      next if limit && income > limit
      return (income * rate - subtract).round
    end
    raise "No suitable tax bracket found"
  end

  def compute_tax_qdcgt
    f = @manager.compute_form(QdcgtWorksheet)
    return f.line[27]
  end

  def compute_penalty
    assert_no_forms(8828, 4137, 5329, 8885, 8919)
    tax_shown = line[15] - sum_lines(*%w(17a 17b 17c))
    with_form('1040 Schedule 4') do |f| tax_shown -= f.line[61, :opt] end
    with_form('1040 Schedule 5') do |f| tax_shown -= f.sum_lines(70, 73) end

    # Test if a penalty is owed. First check if the amount owed is over $1000
    # and also over 10% of tax shown.
    if line[22] > 1000 && line[22] > 0.1 * tax_shown

      ly1040 = @manager.submanager(:last_year).form(1040)
      # Last year's tax shown
      last_year_tax = ly1040.line[63] - \
        ly1040.sum_lines(*%w(61 66a 67 68 69 72))

      unless last_year_tax == 0
        penalty_threshold = last_year_tax
        last_year_agi = ly1040.line[37]
        if last_year_agi > status.halve_mfs(150000)
          penalty_threshold = (1.1 * last_year_tax)
        end

        unless sum_lines(64, 65, 71) >= penalty_threshold
          warn "Penalty computation not implemented"
        end

      end
    end
  end

end

class QdcgtWorksheet < TaxForm
  def name
    'Qualified Dividends and Capital Gains Tax Worksheet'
  end

  def compute
    f1040 = form(1040)
    assert_no_forms(2555, '2555-EZ')
    line[1] = f1040.line[10]
    line[2] = f1040.line['3a']
    if has_form?('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      line['3yes'] = 'X'
      line[3] = [ 0, [ sched_d.line[15], sched_d.line[16] ].min ].max
    else
      line['3no'] = 'X'
      line[3] = form('1040 Schedule 1').line[13]
    end

    line[4] = line[2] + line[3]
    if has_form?(4952)
      line[5] = form(4952).line['4g']
    else
      line[5] = 0
    end
    line[6] = [ 0, line[4] - line[5] ].max
    line[7] = [ 0, line[1] - line[6] ].max
    line[8] = f1040.status.qdcgt_exemption
    line[9] = [ line[1], line[8] ].min
    line[10] = [ line[7], line[9] ].min
    line[11] = line[9] - line[10]

    line[12] = [ line[1], line[6] ].min
    line[13] = line[11]
    line[14] = line[12] - line[13]

    line[15] = f1040.status.qdcgt_cap
    line[16] = [ line[1], line[15] ].min
    line[17] = sum_lines(7, 11)
    line[18] = [ 0, line[16] - line[17] ].max
    line[19] = [ line[14], line[18] ].min
    line[20] = (line[19] * 0.15).round
    line[21] = sum_lines(11, 19)
    line[22] = line[12] - line[21]
    line[23] = (line[22] * 0.2).round

    line[24] = form(1040).compute_tax_standard(line[7])
    line[25] = sum_lines(20, 23, 24)
    line[26] = form(1040).compute_tax_standard(line[1])
    line[27] = [ line[25], line[26] ].min
  end
end

class ChildTaxCreditWorksheet < TaxForm
  def name
    'Child Tax Credit Worksheet'
  end

  def year
    2018
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
      line[:fill] = 0
      return
    end

    # Income limits
    line[4] = f1040.line[7]
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
      line[:fill] = BlankZero
      return
    end

    line[9] = f1040.line[11]

    with_form('1040 Schedule 3') do |f|
      line['10_3_48'] = f.line[48, :opt]
      line['10_3_49'] = f.line[49, :opt]
      line['10_3_50'] = f.line[50, :opt]
      line['10_3_51'] = f.line[51, :opt]
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
      10_3_48 10_3_49 10_3_50 10_3_51 10_5695_30 10_8910_15 10_8936_23 10_r_22
    ))

    if line[10] >= line[9]
      line['11.yes'] = 'X'
      line[:fill] = 0
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

    line[:fill] = line[12]

  end
end

FilingStatus.set_param('standard_deduction', 12000, 24000, :single, 18000, :mfj)
FilingStatus.set_param('qdcgt_exemption', 38600, 77200, :single, 51700, :mfj)
FilingStatus.set_param('qdcgt_cap', 425800, 479000, 239500, 452400, :mfj)

# Not updated for 2018:
FilingStatus.set_param('line_51_credit', 31000, 62000, 31000, 64500, 31000)

# A one-liner that will convert the tables of the tax brackets worksheet into
# the appropriate forms below:
#
# perl -ne 's/,//g; /(?:not over \$(\d+).*)? \((0\.\d+)\).*\$ *([\d.]+)/; $a = $1 || 'nil'; print "[ $a, $2, $3 ],\n"'
#
FilingStatus.set_param(
  'tax_brackets',
  nil,
  nil,
  [
    [ 157500, 0.24, 5710.50 ],
    [ 200000, 0.32, 18310.50 ],
    [ 300000, 0.35, 24310.50 ],
    [ nil, 0.37, 30310.50 ],
  ],
  nil,
  nil
)
class SpouseExemption < FilingStatusVisitor

  def single(line)
  end

  def mfj(line)
    unless line.form.interview("Can someone claim your spouse as a dependent?")
      line['6b'] = 'X'
    end
  end

  def mfs(line)
    unless line.form.interview("Is your spouse filing a tax return?")
      mfj(line)
    end
  end

  def hoh(line)
    if line.form.interview("Are you married?")
      mfs(line)
    end
  end

  def qw(line)
  end
end
