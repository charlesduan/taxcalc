require 'tax_form'

class Form8995 < TaxForm

  def name
    '8995'
  end

  def year
    2019
  end

  def compute
    set_name_ssn

    qbi_manager = form('QBI Manager')
    qbi_manager.qbi.each do |qbi|
      add_table_row({
        '1a' => qbi.name,
        '1b' => qbi.tin,
        '1c' => qbi.amount
      })
    end
    line[2] = line['1c', :sum]
    #
    # Carryforward loss. In future years, reference last year's Form 8995 line
    # 16. (Unclear where this information is on Form 8995-A.)
    line[3] = BlankZero
    line[4] = [ sum_lines(2, 3), 0 ].max
    line[5] = (0.2 * line[4]).round

    # Lines 7-9
    assert_question(
      'Did you have REIT dividends or publicly traded partnership income?',
      false
    )

    line[10] = sum_lines(5, 9)
    line[11] = qbi_manager.line[:taxable_income]
    with_or_without_form('1040 Schedule D') do |sched_d|
      if sched_d
        line[12] = form(1040).line_3a + [
          [ sched_d.line_15, sched_d.line_16 ].min, 0
        ].max
      else
        line[12] = form(1040).sum_lines('3a', 6)
      end
    end

    line[13] = [ line_11 - line_12, 0 ].max
    line[14] = (0.2 + line_13).round
    line[15] = [ line[10], line[14] ].min
    line[16] = [ sum_lines(2, 3), BlankZero ].min
    line[17] = [ sum_lines(6, 7), BlankZero ].min

  end

end
