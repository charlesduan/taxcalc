require_relative 'tax_form'
require_relative 'form1040_r'
require_relative 'foreign_tax_credit'
require_relative 'form8863'

#
# Additional credits and payments
#
class Form1040_3 < TaxForm

  NAME = '1040 Schedule 3'

  def year
    2020
  end

  # Social security tax withholding threshold. This is from Line 10, and must be
  # updated every year.
  SS_THRESHOLD = 8537

  def compute
    set_name_ssn

    # Foreign tax credit
    ftc_form = find_or_compute_form('Foreign Tax Credit')
    line[1] = ftc_form.line[:fill!] if ftc_form

    # Child care expenses
    with_form(2441) do |f|
      unless f.line[:credit_not_permitted!]
        line[2] = f.line[:credit]
      end
    end

    # Education credits
    compute_form(8863) do |f|
      line[3] = f.line[19]
    end

    # Retirement savings credit
    if form(1040).line_agi <= form(1040).status.qrsc_limit
      raise 'Line 51 retirement savings credit not implemented'
    end

    # Line 5, energy saving
    confirm("You installed no any energy saving devices")

    # Line 6: Other credits.
    # - Form 3800: None of the general business credits seem applicable.
    # - Form 8801: AMT credit only applies to depreciation or other deferrals.
    # - Mortgage interest credit: requires certificate.
    # - Schedule R is for people over 65.
    compute_form('1040 Schedule R') && raise("Can't handle Schedule R")
    # None of the other credits seem relevant.

    line['7/nref_credits'] = sum_lines(*1..6)

    #
    # Part II
    #
    # 8: net premium tax credit. For health care purchased on marketplace (Form
    # 1095-A).
    #
    # 9: Amount paid with extension to file.

    # 10: Social security excess
    ss_tax_paid = forms('W-2').lines[4].map { |x|
      warn "Employer withheld too much social security tax" if x > SS_THRESHOLD
      [ x, SS_THRESHOLD ].min
    }.inject(:+)
    # The next line isn't exactly correct for mfj filers
    tot_sst = form(1040).status.is(:mfj) ? SS_THRESHOLD * 2 : SS_THRESHOLD
    if ss_tax_paid > tot_sst
      line[11] = ss_tax_paid - tot_sst
    end

    # 11: fuel tax credit.
    # 12: Other credits.

    line['13/ref_credits'] = sum_lines(*8..13)
  end

  def needed?
    line[:nref_credits] != 0 || line[:ref_credits] != 0
  end

end

FilingStatus.set_param('qrsc_limit',
                       single: 32_500, mfj: 65_000, mfs: :single,
                       hoh: 48_750, qw: :single)
