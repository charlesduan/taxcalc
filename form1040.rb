require 'tax_table'
require 'tax_form'
require 'filing_status'
require 'form1040_a'
require 'form1040_b'
require 'form1040_d'
require 'form1040_e'
require 'form1040_se'
require 'form6251'
require 'form8959'
require 'form8960'

class Form1040 < TaxForm

  def name
    '1040'
  end

  def initialize(manager)
    super(manager)
  end

  attr_reader :force_itemize

  def status
    @status
  end

  def compute

    assert_no_forms(2555, '2555-EZ')

    @status = FilingStatus.for(interview("Enter your filing status:"))

    line[status.checkbox_1040] = 'X'
    extra = status.checkbox_1040_extra
    if extra
      line["#{status.checkbox_1040}text"] = interview("Enter your #{extra}:")
    end

    unless interview("Can someone claim you as a dependent?")
      line['6a'] = 'X'
    end

    status.visit(SpouseExemption.new, line)

    line['6c1', :all] = forms('Dependent').lines['name']
    line['6c2', :all] = forms('Dependent').lines['ssn']
    line['6c3', :all] = forms('Dependent').lines['relationship']
    line['6c4', :all] = forms('Dependent').lines['qualifying'].map { |x|
      x == 'yes' ? 'X' : ''
    }
    line['6a6b'] = (line['6a', :present] ? 1 : 0) + \
      (line['6b', :present] ? 1 : 0)
    line['6c.lived'] = forms('Dependent').lines['where'].select { |x|
      x == 'with'
    }.count
    line['6c.divorced'] = forms('Dependent').lines['where'].select { |x|
      x == 'divorced'
    }.count
    line['6c.other'] = forms('Dependent').count - line['6c.lived'] - \
      line['6c.divorced']

    line['6d'] = sum_lines('6a6b', '6c.lived', '6c.divorced', '6c.other')

    line[7] = forms('W-2').lines(1, :sum)

    sched_b = @manager.compute_form(Form1040B)

    line['8a'] = sched_b.line[4]
    line['8b'] = forms('1099-INT').lines[8, :sum] + \
      forms('1099-DIV').lines[10, :sum]

    line['9a'] = sched_b.line[6]
    line['9b'] = forms('1099-DIV').lines['1b', :sum]

    assert_no_forms('1099-G')

    alimony = interview("Enter any amount you received as alimony:")
    line[11] = alimony if alimony > 0

    line[12] = forms('1040 Schedule C').lines(31, :sum)

    sched_d = find_or_compute_form('1040 Schedule D', Form1040D)

    if sched_d
      line[13] = sched_d.line['fill']
    else
      line[13] = BlankZero
    end

    assert_no_forms(4797)

    line15 = forms('1099-R').lines(1, :sum)
    if line15 > 0
      if interview('Do any of the line 15a exceptions apply to you?')
        raise 'Not implemented'
      end
      line['15b'] = line15
    end

    if interview('Did you receive any pension or annuity distributions?')
      raise 'Not implemented'
    end

    sched_e = @manager.compute_form(Form1040E)
    line[17] = sched_e.line[41]

    assert_no_forms('SSA-1099', 'RRB-1099')

    line[22] = sum_lines(7, '8a', '9a', 10, 11, 12, 13, 14, '15b', '16b', 17,
                         18, 19, '20b', 21)

    sched_se = find_or_compute_form('1040 Schedule SE', Form1040SE)
    line[27] = sched_se.line[13] if sched_se

    line[36] = sum_lines(23, 24, 25, 26, 27, 28, 29, 30, '31a', 32, 33, 34, 35)
    line[37] = line[22] - line[36]

    line[38] = line[37]

    assert_question('Were you or your spouse born before 1952 or blind?',
                    false)
    assert_question('Can someone claim you as a dependent?', false)
    line['39a'] = 0

    @force_itemize = false
    choose_itemize = false
    if status.is('mfs')
      itemize = interview('Do you want to itemize deductions?')
      @force_itemize = true if itemize
      line['39b'] = 'X' if itemize || interview('Are you a dual-status alien?')

    else
      if interview('Do you want the computer to choose whether to itemize?')
        choose_itemize = true
      else
        itemize = interview('Do you want to itemize deductions?')
        @force_itemize = true if itemize
      end
    end

    sd = status.standard_deduction
    if itemize || choose_itemize


      sched_a = @manager.compute_form(Form1040A)

      if itemize || sched_a.line[29] > sd
        line[40] = sched_a.line[29]
      else
        @manager.remove_form(sched_a)
        line[40] = sd
      end

    else
      line[40] = sd
    end

    line[41] = line[38] - line[40]

    if line[38] <= status.exemption_threshold
      line[42] = 4050 * line['6d']
    else
      edw = @manager.compute_form(ExemptionsDeductionsWorksheet)
      line[42] = edw.line['fill']
    end

    line[43] = [ line[41] - line[42], 0 ].max

    line[44] = compute_tax

    amt_test = @manager.compute_form(AMTTestWorksheet)
    if amt_test.line['fillform'] == 'yes'
      line[45] = @manager.compute_form(Form6251).line[35]
    end

    assert_no_forms('1095-A') # Line 46

    line[47] = sum_lines(44, 45, 46)

    # Line 48
    assert_question("Did you pay any foreign taxes?", false)
    assert_no_lines('1099-DIV', 6)
    assert_no_lines('1099-INT', 6)

    unless status.is('mfs')
      # Line 49
      assert_question('Did you pay child care expenses?', false)

      # Line 50
      assert_question("Did you pay education expenses?", false)
    end

    # Line 51
    if line[38] <= status.line_51_credit
      raise 'Retirement Savings Contributions Credit not implemented'
    end

    # Line 52
    line[52] = @manager.compute_form(ChildTaxCreditWorksheet).line['fill']

    # Line 53
    assert_no_forms(5695)

    line[55] = sum_lines(*48..54)
    line[56] = [ 0, line[47] - line[55] ].max

    if has_form?('1040 Schedule SE')
      line[57] = form('1040 Schedule SE').line[12]
    end

    assert_question('Did you have health insurance the whole year?', true)
    line['61box'] = 'X'

    line[62] = BlankZero
    f8959 = @manager.compute_form(Form8959)
    if f8959 && f8959.needed?
      line['62a'] = 'X'
      line[62] += f8959.line[18]
    end

    if line[38] > status.niit_threshold
      f8960 = @manager.compute_form(Form8960)
      line['62b'] = 'X'
      line[62] += f8960.line[17]
    end
    line[63] = sum_lines(56, 57, 58, 59, '60a', '60b', 61, 62)

    line[64] = forms('W-2').lines(2, :sum)
    line[65] = forms('Estimated Tax').lines('amount', :sum)

    ss_tax_paid = forms('W-2').lines[4].map { |x|
      [ x, 7347 ].min
     }.inject(:+)
     if ss_tax_paid > 7347
       line[71] = ss_tax_paid - 7347
     end

    line[74] = sum_lines(64, 65, '66a', 67, 68, 69, 70, 71, 72, 73)

    if line[74] > line[63]
      line[75] = line[74] - line[63]
      line['76a'] = line[75]
    else
      line[78] = line[63] - line[74]

      assert_no_forms(8828, 4137, 5329, 8885, 8919)
      tax_shown = line[63] - sum_lines(61, '66a', 67, 68, 69, 72)

      if line[78] > 1000 && line[78] > 0.1 * tax_shown

        last_year_tax = interview('Enter your last year\'s tax shown:')
        unless last_year_tax == 0
          penalty_threshold = last_year_tax
          last_year_agi = interview('Enter your last year\'s AGI:')
          if last_year_agi > status.penalty_threshold
            penalty_threshold = (1.1 * last_year_tax)
          end

          unless sum_lines(64, 65, 71) >= penalty_threshold
            warn "Penalty computation not implemented"
          end

        end
      end
    end


  end


  def compute_tax
    if has_form?('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      if sched_d.line['20no', :present]
        return compute_tax_schedule_d
      elsif sched_d.line[15] > 0 && sched_d.line[16] > 0
        return compute_tax_qdcgt
      end
    elsif line['9b', :present] or line[13, :present]
      return compute_tax_qdcgt
    else
      return compute_tax_standard(line[43])
    end
  end

  def compute_tax_standard(income)
    if income < 100000
      return compute_tax_table(income, status)
    else
      return compute_tax_worksheet(income)
    end
  end

  include TaxTable

  def compute_tax_worksheet(income)
    if income < 100000
      raise 'Worksheet not applicable for less than $100,000'
    elsif income <= 190150
      return (income * 0.28 - 6963.25).round
    elsif income <= 413350
      return (income * 0.33 - 16470.75).round
    elsif income <= 415050
      return (income * 0.35 - 24737.75).round
    else
      return (income * 0.396 - 43830.05).round
    end
  end

  def compute_tax_qdcgt
    f = @manager.compute_form(QdcgtWorksheet)
    return f.line[27]
  end

end

class QdcgtWorksheet < TaxForm
  def name
    '1040 Qualified Dividends and Capital Gains Tax Worksheet'
  end

  def compute
    f1040 = form(1040)
    line[1] = f1040.line[43]
    line[2] = f1040.line['9b']
    if has_form?('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      line['3yes'] = 'X'
      line[3] = [ 0, [ sched_d.line[15], sched_d.line[16] ].min ].max
    else
      line['3no'] = 'X'
      line[3] = f1040.line[13]
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

class AMTTestWorksheet < TaxForm
  def name
    "Worksheet to See If You Should Fill In Form 6251"
  end

  def compute
    f1040 = form(1040)
    with_or_without_form('1040 Schedule A') do |sched_a|
      if sched_a
        line['1yes'] = 'X'
        line[1] = f1040.line[41]
        line[3] = sched_a.sum_lines(9, 27)
        line[4] = sum_lines(1, 2, 3)
      else
        line[4] = form(1040).line(38)
      end
    end

    line[5] = f1040.sum_lines(10, 21)
    if has_form?('Itemized Deduction Worksheet')
      line[6] = form('Itemized Deduction Worksheet').line[9]
    end
    line[7] = sum_lines(5, 6)
    line[8] = line[4] - line[7]
    line[9] = f1040.status.amt_exemption
    if line[8] <= line[9]
      line['10no'] = 'X'
      line['fillform'] = 'no'
      return
    end
    line['10yes'] = 'X'
    line[10] = line[8] - line[9]
    line[11] = f1040.status.amt_exemption_2
    if line[8] <= line[11]
      line['12no'] = 'X'
      line[12] = 0
      line[14] = line[10]
    else
      line['12yes'] = 'X'
      line[12] = line[8] - line[11]
      line[13] = [ line[9], (line[12] * 0.25).round ].min
      line[14] = line[10] + line[13]
    end
    if line[14] > f1040.status.halve_mfs(186300)
      line['15yes'] = 'X'
      line['fillform'] = 'yes'
      return
    else
      line['15no'] = 'X'
      line[15] = (line[14] * 0.26).round
    end
    line[16] = f1040.sum_lines(44, 46)
    if line[15] > line[16]
      line['fillform'] = 'yes'
    else
      line['fillform'] = 'no'
    end
  end
end

class ChildTaxCreditWorksheet < TaxForm
  def name
    'Child Tax Credit Worksheet'
  end

  def compute
    line['1num'] = form(1040).line['6c4', :all].select { |x| x == 'X' }.count
    if line['1num'] == 0
      line['fill'] = BlankZero
      return
    end

    line[1] = line['1num'] * 1000
    line[2] = form(1040).line[38]
    line[3] = form(1040).status.child_tax_limit
    if line[2] > line[3]
      line[5] = 0
    else
      l4 = line[2] - line[3]
      if l4 % 1000 == 0
        line[4] = l4
      else
        line[4] = l4.round(-3) + 1000
      end
      line[5] = line[4] / 20
    end
    if line[1] <= line[5]
      raise 'Child tax credit not implemented'
    else
      line['fill'] = BlankZero
      return
    end
  end
end

class ExemptionsDeductionsWorksheet < TaxForm
  def name
    'Deduction for Exemptions Worksheet'
  end

  def compute
    line[2] = form(1040).line['6d'] * 4050
    line[3] = form(1040).line(38)
    line[4] = form(1040).status.exemption_threshold
    line[5] = line[3] - line[4]

    if line[5] > form(1040).status.halve_mfs(122500)
      line['fill'] = 0
      return
    end

    line[6] = (line[5] / form(1040).status.halve_mfs(2500.0)).ceil
    line[7] = (line[6] * 0.02).round(3)
    line[8] = (line[2] * line[7]).round
    line['fill'] = line[9] = line[2] - line[8]
  end
end


FilingStatus.set_param('qdcgt_exemption', 37650, 75300, 37650, 50400, 75300)
FilingStatus.set_param('qdcgt_cap', 415050, 466950, 233475, 441000, 466950)
FilingStatus.set_param('amt_exemption', 53900, 83800, 41900, 53900, 83800)
FilingStatus.set_param('amt_exemption_2', 119700, 159700, 79850, 119700, 159700)
FilingStatus.set_param('line_51_credit', 30750, 61500, 30750, 46125, 30750)
FilingStatus.set_param('child_tax_limit', 75000, 110000, 55000, 75000, 75000)
FilingStatus.set_param('niit_threshold', 200000, 250000, 125000, 200000, 250000)
FilingStatus.set_param('penalty_threshold', 150000, 150000, 75000, 150000,
                       150000)
FilingStatus.set_param('exemption_threshold', 259400, 311300, 155650, 285350,
                       311300)

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