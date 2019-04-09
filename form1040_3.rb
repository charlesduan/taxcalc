require 'tax_form'
require 'form1040_r'
require 'foreign_tax_credit'
require 'form2441'
require 'form8863'

class Form1040_3 < TaxForm

  def name
    '1040 Schedule 3'
  end

  def year
    2018
  end

  def compute
    ftc_form = find_or_compute_form('Foreign Tax Credit', ForeignTaxCredit)
    line[48] = ftc_form.line[:send] if ftc_form

    compute_form(Form2441)
    with_form(2441) do |f|
      line[49] = f.line[11]
    end

    compute_form(Form8863)
    with_form(8863) do |f|
      line[50] = f.line[19]
    end

    if form(1040).line[7] <= form(1040).status.qrsc_limit
      raise 'Line 51 retirement savings credit not implemented'
    end

    # Line 53
    assert_question("Did you install any energy saving devices?", false)

    # Line 54: Other credits.
    # - Form 3800: None of the general business credits seem applicable.
    # - Form 8801: AMT credit only applies to depreciation or other deferrals.
    # - Mortgage interest credit: requires certificate.
    compute_form(Form1040R) && raise("Can't handle Schedule R")
    # None of the other credits seem relevant.

    line[55] = sum_lines(48, 49, 50, 51, 53, 54)
  end

end

FilingStatus.set_param('qrsc_limit', 31500, 63000, :single, 47250, :single)
