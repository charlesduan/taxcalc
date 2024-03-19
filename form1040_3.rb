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
    2023
  end

  # Social security tax withholding threshold. This is from Line 10, and must be
  # updated every year.
  SS_THRESHOLD = 9932

  def compute
    set_name_ssn

    # Foreign tax credit
    ftc_form = find_or_compute_form('Foreign Tax Credit')
    line['1/foreign_tax_credit'] = ftc_form.line[:fill!] if ftc_form

    #
    # If a partnership files Form 8986, then Form 8978 must be prepared and the
    # result reported on line 6l/pship_tax_adjust. However, this affects the
    # computation of Form 2441, so to the extent that Form 8978 is to be
    # computed, then it must be done here.
    #
    assert_no_forms(8986)

    # Child care expenses
    with_form(2441) do |f|
      compute_more(f, :credit)
      line['2/childcare_credit'] = f.line[:credit]
    end

    # Education credits
    compute_form(8863) do |f|
      line['3/educ_credit'] = f.line[:credit]
    end

    # Retirement savings credit
    if form(1040).line[:agi] <= form(1040).status.qrsc_limit
      raise 'Line 4 retirement savings credit not implemented'
      # Line 4/savers_credit
    end

    # Line 5a/energy_credit
    # Line 5b/energy_imp_credit, energy saving credits
    confirm("You installed no any energy saving devices")

    # Line 6: Other credits.
    # - Form 3800: None of the general business credits seem applicable.
    # - Form 8801: AMT credit only applies to depreciation or other deferrals.
    # - Mortgage interest credit: requires certificate.
    # - Schedule R is for people over 65. It will set line 6d
    compute_form('1040 Schedule R') && raise("Can't handle Schedule R")
    # None of the other credits seem relevant.
    line[7] = sum_lines(*"6a".."6z")

    # As a convenience for Form 8812, the items for Credit Limit Worksheet A are
    # summed here. (This is done here so that, to the extent the line numbers
    # change, it is easier to identify the need for adjustment.)
    line[:form_8812_exclusions!] = sum_lines(
      1, 2, 3, 4, '5b', '6d', '6f', '6l', '6m'
    )

    line[:form_8812_worksheet_b_needed!] = (
      line['6g', :present] || # Mortgage interest credit
      line['6c', :present] || # Adoption credit
      line['5a', :present] || # Residential clean energy credit
      line['6h', :present]    # DC homebuyer credit
    )

    line['8/nref_credits'] = sum_lines(*1..7)

    #
    # Part II
    #
    # 9: net premium tax credit. For health care purchased on marketplace (Form
    # 1095-A).
    #
    # 10: Amount paid with extension to file.

    #
    # 11: Social security excess. For each person on this filing, compute all
    # the social security withholdings, add them up, and determine the excess
    # over the maximum withholding. The sum of those excesses is line 11.
    #
    ss_tax_paid = Hash.new(BlankZero)
    forms('W-2').each do |w2|
      ss_wh = w2.line[4]
      warn "Employer withheld too much social security tax" if x > SS_THRESHOLD
      ss_wh = [ x, SS_THRESHOLD ].min
      ss_tax_paid[w2.line[:ssn]] += ss_wh
    end
    line[11] = ss_tax_paid.values.map { |ss_tax|
      [ BlankZero, ss_tax - SS_THRESHOLD ].max
    }.sum

    # 12: fuel tax credit.
    # 13: Other credits.
    line[14] = sum_lines(*"13a".."13z")

    line['15/ref_credits'] = sum_lines(*8..14)
  end

  def needed?
    line[:nref_credits] != 0 || line[:ref_credits] != 0
  end

end

FilingStatus.set_param('qrsc_limit',
                       single: 36_500, mfj: 73_000, mfs: :single,
                       hoh: 54_750, qw: :single)
