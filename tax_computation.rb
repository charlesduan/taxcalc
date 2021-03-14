require 'tax_table'

module TaxComputation

  def compute_tax

    # Form for rich kids (under 24)
    if age < 24
      raise "Form 8615 is not implemented"
    end

    with_or_without_form('1040 Schedule D') do |sched_d|
      if sched_d
        if sched_d.line['20no', :present]
          line[:tax_method!] = 'Sch D'
          return compute_tax_schedule_d # Not implemented; raises error
        elsif sched_d.line[15] > 0 && sched_d.line[16] > 0
          line[:tax_method!] = 'QDCGTW'
          return compute_tax_qdcgt
        end
      elsif line['3a', :present] or line[6, :opt] != 0
        line[:tax_method!] = 'QDCGTW'
        return compute_tax_qdcgt
      end
    end

    # Default computation method
    return compute_tax_standard(line[10])
  end

  def compute_tax_standard(income)
    if income < 100000
      line[:tax_method!] = 'Table' unless line[:tax_method!, :present]
      return compute_tax_table(income, status)
    else
      line[:tax_method!] = 'TCW' unless line[:tax_method!, :present]
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
    f = @manager.compute_form(
      'Qualified Dividends and Capital Gains Tax Worksheet'
    )
    return f.line[27]
  end

end

class QdcgtWorksheet < TaxForm
  NAME = 'Qualified Dividends and Capital Gains Tax Worksheet'

  def year
    2019
  end

  def compute
    f1040 = form(1040)
    assert_question("Did you have any foreign income?", false)
    line[1] = f1040.line_taxinc
    line[2] = f1040.line_qualdiv
    if has_form?('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      line['3yes'] = 'X'
      line[3] = [ 0, [ sched_d.line[15], sched_d.line[16] ].min ].max
    else
      line['3no'] = 'X'
      line[3] = f1040.line_6
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

FilingStatus.set_param('qdcgt_exemption', 39_375, 78_750, :single, 52_750, :mfj)
FilingStatus.set_param('qdcgt_cap', 434_550, 488_850, 244_425, 461_700, :mfj)

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
    [ 160725, 0.24, 5825.50 ],
    [ 204100, 0.32, 18683.50 ],
    [ 306175, 0.35, 24806.50 ],
    [ nil, 0.37, 30930.00 ],
  ],
  nil,
  nil
)

