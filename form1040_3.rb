require 'tax_form'
require 'form1040_r'
require 'foreign_tax_credit'
require 'form2441'
require 'form8863'

#
# Additional credits and payments
#
class Form1040_3 < TaxForm

  def name
    '1040 Schedule 3'
  end

  def year
    2019
  end

  def compute
    set_name_ssn

    # Foreign tax credit
    ftc_form = find_or_compute_form('Foreign Tax Credit', ForeignTaxCredit)
    line[1] = ftc_form.line[:fill!] if ftc_form

    # Child care expenses
    compute_form(Form2441)
    with_form(2441) do |f|
      line[2] = f.line[11]
    end

    # Education credits
    compute_form(Form8863)
    with_form(8863) do |f|
      line[3] = f.line[19]
    end

    # Retirement savings credit
    if form(1040).line_8b <= form(1040).status.qrsc_limit
      raise 'Line 51 retirement savings credit not implemented'
    end

    # Line 5, energy saving
    assert_question("Did you install any energy saving devices?", false)

    # Line 6: Other credits.
    # - Form 3800: None of the general business credits seem applicable.
    # - Form 8801: AMT credit only applies to depreciation or other deferrals.
    # - Mortgage interest credit: requires certificate.
    # - Schedule R is for people over 65.
    compute_form(Form1040R) && raise("Can't handle Schedule R")
    # None of the other credits seem relevant.

    line[7] = sum_lines(*1..6)

    #
    # Part II
    #
    # Estimated tax payments
    line[8] = forms('Estimated Tax').lines('amount', :sum) + \
      @manager.submanager(:last_year).form(1040).line(21, :opt)

    # 9: net premium tax credit. For health care purchased on marketplace (Form
    # 1095-A).
    #
    # 10: Amount paid with extension to file.

    # 11: Social security excess
    ss_threshold = 8240
    ss_tax_paid = forms('W-2').lines[4].map { |x|
      warn "Employer withheld too much social security tax" if x > ss_threshold
      [ x, ss_threshold ].min
     }.inject(:+)
     # The next line isn't exactly correct for mfj filers
     ss_threshold *= 2 if form(1040).status.is('mfj')
     if ss_tax_paid > ss_threshold
       line[11] = ss_tax_paid - ss_threshold
     end

     # 12: fuel tax credit.
     # 13: Other credits.

     line[14] = sum_lines(*8..13)
  end

  def needed?
    line[7] != 0 || line[14] != 0
  end

end

FilingStatus.set_param('qrsc_limit', 32_000, 64_000, :single, 48_000, :single)
