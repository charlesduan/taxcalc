require 'tax_form'

class Form1040A < TaxForm
  def compute
    line[5] = forms('State Taxes').line(:amount, :sum) + \
      forms('W-2').lines(17, :sum)
    line['5a'] = 'X'
    line[6] = forms('Real Estate Taxes').line(:amount) + \
      forms('1098-INT').lines(10, :sum)
    line[9] = sum_lines(5, 6, 7, 8)

    line[10] = forms('1098-INT').lines(1, :sum) + \
      forms('1098-INT').lines(6, :sum)

    assert_no_forms(4952)
    line[15] = sum_lines(10, 11, 12, 13, 14)

    line[16] = forms('Gifts to Charity').lines(:amount, :sum)
    if line[16] > 0.2 * form(1040).line(38)
      raise "Pub. 526 limit on charitable contributions not implemented"
    end
    line[19] = sum_lines(16, 17, 18)

    assert_no_forms(4684)

    if form(1040).line(38) > 155650
      raise "Itemized Deductions Worksheet not implemented"
    end
    line['29.no'] = 'X'
    line[29] = sum_lines(4, 9, 15, 19, 20, 27, 28)
    if form(1040).force_itemize
      line[30] = 'X'
    end
  end
end
