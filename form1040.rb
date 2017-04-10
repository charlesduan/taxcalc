require 'tax_form'

class Form1040 < TaxForm

  def initialize(manager)
    super(manager)
    @force_itemize = nil
  end

  def force_itemize=(val)
    raise TypeError unless [ true, false ].include?(val)
    @force_itemize = val
  end
  def force_itemize
    @force_itemize
  end

  def status
    @status
  end

  def calculate

    @status = FilingStatus.for(interview("Enter your filing status:"))

    line[status.checkbox_1040] = 'X'
    extra = status.checkbox_1040_extra
    line["#{status.checkbox_1040}text"] = interview(extra) if extra

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

    sched_b = Form1040B.new
    sched_b.compute
    @manager.add_form(sched_b)
    line['8a'] = sched_b.line[4]
    line['8b'] = forms('1099-INT').lines[8, :sum] + \
      forms('1099-DIV').lines[10, :sum]

    line['9a'] = sched_b.line[6]
    line['9b'] = forms('1099-DIV').lines['1b', :sum]

    assert_no_forms('1099-G')

    alimony = interview("Enter any amount you received as alimony:")
    line[11] = alimony if alimony > 0

    line[12] = forms('1040 Schedule C').lines(31, :sum)

    sched_d = Form1040D.new
    sched_d.compute
    @manager.add_form(sched_d)
    line[13] = sched_d.report_1040

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

    sched_e = Form1040E.new
    sched_e.compute
    @manager.add_form(sched_e)
    line[17] = sched_e.line[41]

    assert_no_forms('SSA-1099', 'RRB-1099')

    line[22] = sum_lines(7, '8a', '9a', 10, 11, 12, 13, 14, '15b', '16b', 17,
                         18, 19, '20b', 21)

    sched_se = Form1040SE.new
    sched_se.compute
    @manager.add_form(sched_se) if sched_se.needed?

    if sched_se.needed?
      line[27] = sched_se.line[13]
    end

    line[36] = sum_lines(23, 24, 25, 26, 27, 28, 29, 30, '31a', 32, 33, 34, 35)
    line[37] = line[22] - line[36]

    line[38] = line[37]

    assert_question('Where you or your spouse born before 1952 or blind?',
                    false)
    assert_question('Can someone claim you as a dependent?', false)
    line['39a'] = 0

    if status.is('mfs')
      if @force_itemize.nil?
        raise "Must specify whether to itemize when married filing separately"
      end
      if @force_itemize
        line['39b'] = 'X'
      end
    end

    sched_a = Form1040A.new
    sched_a.compute
    sd = status.standard_deduction

    if @force_itemize.nil?
      @force_itemize = (sched_a.line[29] > sd)
    end

    if @force_itemize
      @manager.add_form(sched_a)
      line[40] = sched_a.line[29]
    else
      line[40] = sd
    end

    line[41] = line[38] - line[40]

    if line[38] <= 155650
      line[42] = 4050 * line['6d']
    else
      raise 'Line 42 for high incomes not implemented'
    end

    line[43] = [ line[41] - line[42], 0 ].max

    line[44] = compute_tax

    amt_test = @manager.compute_form(AMTTestWorksheet)
    if amt_test.line['fillform'] == 'yes'
    
  end


  def compute_tax
    if has_form('1040 Schedule D')
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
      return compute_tax_table(income)
    else
      return compute_tax_worksheet(income)
    end
  end

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
    '1040 Qualified Dividents and Capital Gains Tax Worksheet'
  end

  def compute
    f1040 = form(1040)
    line[1] = f1040.line[43]
    line[2] = f1040.line['9b']
    if has_form('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      line['3yes'] = 'X'
      line[3] = [ 0, [ sched_d.line[15], sched_d.line[16] ].min ].max
    else
      line['3no'] = 'X'
      line[3] = f1040.line[13]
    end

    line[4] = line[2] + line[3]
    if has_form(4952)
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

    line[24] = compute_tax_standard(line[7])
    line[25] = sum_lines(20, 23, 24)
    line[26] = compute_tax_standard(line[1])
    line[27] = [ line[25], line[26] ].min
  end
end

class AMTTestWorksheet < TaxForm
  def name
    "Worksheet to See If You Should Fill In Form 6251"
  end

  def compute
    f1040 = form(1040)
    if has_form('1040 Schedule A')
      sched_a = form('1040 Schedule A')
      line['1yes'] = 'X'
      line[1] = f1040.line[41]
      line[3] = sched_a.sum_lines(9, 27)
      line[4] = sum_lines(1, 2, 3)
      line[5] = f1040.sum_lines(10, 21)
      if has_form('Itemized Deduction Worksheet')
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
      if line[14] > (f1040.status.is('mfs') ? 93150 : 186300)
        line['15yes'] = 'X'
        line['fillform'] = 'yes'
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
end


FilingStatus.set_param('qdcgt_exemption', 37650, 75300, 37650, 50400, 75300)
FilingStatus.set_param('qdcgt_cap', 415050, 466950, 233475, 441000, 466950)
FilingStatus.set_param('amt_exemption', 53900, 83800, 41900, 53900, 83800)
FilingStatus.set_param('amt_exemption_2', 119700, 159700, 79850, 119700, 159700)

class SpouseExemption < FilingStatusVisitor
  def single(line)
  end

  def mfj(line)
    unless interview("Can someone claim your spouse as a dependent?")
      line['6b'] = 'X'
    end
  end

  def mfs(line)
    unless interview("Is your spouse filing a tax return?")
      mfj(line)
    end
  end

  def hoh(line)
    if interview("Are you married?")
      mfs(line)
    end
  end

  def qw(line)
  end
end
