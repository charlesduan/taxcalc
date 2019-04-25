require 'tax_form'

class QBISimplifiedWorksheet < TaxForm

  def name
    'QBI Simplified Worksheet'
  end

  def year
    2018
  end

  def compute

    assert_no_forms('1099-MISC') # which would trigger a Schedule C
    forms('1065 Schedule K-1').each do |f|
      add_table_row(
        '1a' => f.line[:B].sub(/\n.*/, ''),
        '1b' => f.line[:A],
        '1c' => f.line[1]
      )
    end
    line[2] = line['1c', :sum]
    line[4] = sum_lines(2, 3)
    line[5] = (line[4] * 0.2).round
    assert_question(
      'Did you have REIT dividends or publicly traded partnership income?',
      false
    )
    line[10] = sum_lines(5, 9)
    line[11] = form(1040).line[7] - form(1040).line[8]
    l12 = form(1040).line['3a']
    with_or_without_form('1040 Schedule D') do |f|
      if f.nil?
        with_form('1040 Schedule 1') do |f1|
          l12 += f1.line[13]
        end
      else
        l12 += form(1040).line['3a'] + [ [ f.line[15], f.line[16] ].min, 0 ].max
      end
    end
    line[12] = l12
    line[13] = [ 0, line[11] - line[12] ].max
    line[14] = (line[13] * 0.2).round
    line[15] = [ line[10], line[14] ].min

  end
end
