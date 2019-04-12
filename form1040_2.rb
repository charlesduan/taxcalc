require 'tax_form'

class Form1040_2 < TaxForm

  def name
    '1040 Schedule 2'
  end

  def year
    2018
  end

  def compute
    set_name_ssn

    # Bizarrely, Form 6251 requires Schedule 2, Line 46. So it is computed
    # first.
    assert_no_forms('1095-A') # Line 46
    line[46] = BlankZero

    amt_test = @manager.compute_form(AMTTestWorksheet)
    if amt_test.line[:fill_yes, :present]
      line[45] = @manager.compute_form(Form6251).line[11]
    end

    place_lines(46)

    line[47] = sum_lines(45, 46)
  end

  def needed?
    # Schedule 2 is needed, even if it reports zero, if the AMT computation is
    # performed.
    line[47] > 0 || has_form?(6251)
  end
end
