require 'tax_form'

class Form1040_2 < TaxForm

  def name
    '1040 Schedule 2'
  end

  def year
    2018
  end

  def compute
    amt_test = @manager.compute_form(AMTTestWorksheet)
    if amt_test.line['fillform'] == 'yes'
      line[45] = @manager.compute_form(Form6251).line[35]
    end

    assert_no_forms('1095-A') # Line 46

    line[47] = sum_lines(45, 46)
  end

  def needed?
    line[47] > 0
  end
end
