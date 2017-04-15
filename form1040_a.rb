require 'tax_form'

class Form1040A < TaxForm

  def name
    '1040 Schedule A'
  end

  def compute
    line[5] = forms('State Tax').lines(:amount, :sum) + \
      forms('W-2').lines(17, :sum)
    line['5a'] = 'X'
    line[6] = forms('1098-INT').lines(10, :sum)
    line[9] = sum_lines(5, 6, 7, 8)

    line[10] = forms('1098-INT').lines(1, :sum) + \
      forms('1098-INT').lines(6, :sum)

    assert_no_forms(4952)
    line[15] = sum_lines(10, 11, 12, 13, 14)

    line[16] = forms('Charity Gift').lines(:amount, :sum)
    if line[16] > 0.2 * form(1040).line(38)
      raise "Pub. 526 limit on charitable contributions not implemented"
    end
    line[19] = sum_lines(16, 17, 18)

    # Lines 20, 28
    assert_question('Did you have gambling, casualty, or theft losses?', false)

    if form(1040).line(38) > form(1040).status.itemize_limit
      idw = @manager.compute_form(ItemizedDeductionsWorksheet)
      line['29yes'] = 'X'
      line[29] = idw.line['fill']
    else
      line['29no'] = 'X'
      line[29] = sum_lines(4, 9, 15, 19, 20, 27, 28)
      if form(1040).force_itemize
        line[30] = 'X'
      end
    end
  end
end

FilingStatus.set_param('itemize_limit', 259400, 311300, 155650, 285350, 311300)

class ItemizedDeductionsWorksheet < TaxForm
  def name
    'Itemized Deductions Worksheet'
  end

  def compute
    sched_a = form('1040 Schedule A')
    line[1] = sched_a.sum_lines(4, 9, 15, 19, 20, 27, 28)

    assert_question('Did you have gambling, casualty, or theft losses?', false)
    line[2] = sched_a.sum_lines(4, 14, 20)

    if line[2] >= line[1]
      line['fill'] = line[1]
      return
    end

    line[3] = line[1] - line[2]
    line[4] = (line[3] * 0.8).round
    line[5] = form(1040).line(38)
    line[6] = form(1040).status.itemize_limit

    if line[6] >= line[5]
      line['fill'] = line[1]
      return
    end

    line[7] = line[5] - line[6]
    line[8] = (line[7] * 0.03).round
    line[9] = [ line[4], line[8] ].min
    line['fill'] = line[10] = line[1] - line[9]
  end

end
