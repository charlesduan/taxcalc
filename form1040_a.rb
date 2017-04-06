require 'tax_form'

class Form1040A < TaxForm
  def calculate
    line[5] = form('State Taxes').line(:amount, :sum) + \
      forms('W-2').lines(17, :sum)
    line['5a'] = 'X'
    line[6] = form('Real Estate Taxes').line(:amount)
    line[9] = sum_lines(5, 6, 7, 8)

    line[10] = forms(1098).lines(1, :sum)
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
    always_itemize = interview("Do you want to always itemize deductions?")
  end
end
