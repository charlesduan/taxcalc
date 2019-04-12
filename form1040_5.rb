require 'tax_form'

class Form1040_5 < TaxForm

  def name
    "1040 Schedule 5"
  end

  def year
    2018
  end

  def compute
    set_name_ssn

    # Estimated tax payments
    line[66] = forms('Estimated Tax').lines('amount', :sum)

    # 70: net premium tax credit. For health care purchased on marketplace (Form
    # 1095-A).
    #
    # 71: Amount paid with extension to file.

    # 72: Social security excess
    ss_threshold = 7961
    ss_tax_paid = forms('W-2').lines[4].map { |x|
      warn "Employer withheld too much social security tax" if x > ss_threshold
      [ x, ss_threshold ].min
     }.inject(:+)
     # The next line isn't exactly correct for mfj filers
     ss_threshold *= 2 if form(1040).status.is('mfj')
     if ss_tax_paid > ss_threshold
       line[72] = ss_tax_paid - ss_threshold
     end

     # 73: fuel tax credit.
     # 74: Other credits.

     line[75] = sum_lines(66, 70, 71, 72, 73, 74)
  end

end
