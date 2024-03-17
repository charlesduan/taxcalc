require 'tax_form'
require 'form4562'
require 'expense_manager'
require 'asset_manager'
require 'form1065_b1'
require 'form1065_k1'
require 'form7004'

class Form1065 < TaxForm

  NAME = '1065'

  def year
    2023
  end

  def compute

    bio = form('Partnership')
    line['name'] = bio.line(:name)
    line['address'] = bio.line(:address) + \
      (bio.line(:address2, :present) ? " " + bio.line(:address2) : "")
    line['city_zip'] = bio.line(:city_zip)
    line['A'] = bio.line('business')
    line['B'] = bio.line('product')
    line['C'] = bio.line('code')
    line['D/ein'] = bio.line('ein')
    line['E'] = bio.line(:start)

    # Line F need not be filled in if the below condition is true. Schedule B is
    # part of Form 1065.; the conditions are:
    #
    # - Total receipts less than $250k
    # - Total assets less than $1M
    # - Schedules K-1 filed on time
    # - Schedule M-3 not filed
    #
    confirm(
      "Partnership #{line_name} meets the 4 conditions " \
      "in Form 1065 Schedule B, line 4.",
    )

    #
    # These relate to address changes and such.
    #
    confirm(
      "For partnership #{line_name}, no box in Form 1065 line G " \
      "needs to be checked."
    )

    case bio.line('accounting')
    when 'Cash' then line['H.1'] = 'X'
    when 'Accrual' then line['H.2'] = 'X'
    else
      line['H.3'] = 'X'
      line['H.other'] = bio.line('accounting')
    end

    partners = forms('Partner')
    unless partners.all? { |f| f.line[:ein] == bio.line(:ein) }
      raise "Partners' EIN records don't match the partnership's"
    end

    line['I'] = partners.count

    # Line J need not be filled for partnerships with less than $35M in total
    # receipts or $10M in assets, and which has no reportable entity partner (a
    # 50% partner that must file Schedule M-3).
    #
    # Line K only applies if the partnership claims losses.

    assert_no_forms('1099-MISC')
    line['1a'] = forms('1099-NEC').lines(1, :sum)
    line['1c'] = line['1a'] - line['1b', :opt]
    line[3] = line['1c'] - line[2, :opt]
    line['8/tot_inc'] = sum_lines(3, 4, 5, 6, 7)

    @asset_manager = compute_form('Asset Manager')
    if @asset_manager.has_current_assets?
      compute_form(4562)
    end

    @asset_manager.attach_safe_harbor_election(self)

    if @asset_manager.depreciation_total != 0
      line['16a'] = @asset_manager.depreciation_total
      line['16c'] = line['16a'] - line['16b', :opt]
    end

    @expense_manager = compute_form('Business Expense Manager')

    @expense_manager.fill_lines(self, {
      9 => 'Wages',
      11 => 'Repairs',
      12 => 'Debts',
      13 => [ 'Rent_Equipment', 'Rent_Property' ],
      14 => 'Licenses',
      15 => [ 'Mortgage_Interest', 'Other_Interest' ],
      17 => 'Depletion',
      18 => 'Employee_Plans',
      19 => 'Employee_Benefits',
      # 2023: line 20 energy efficient buildings deduction not implemented
    }, other: 21, continuation: 'Line 21 Statement of Business Expenses')

    # Rearrange the lines
    place_lines(9, 10, 11, 12, 13, 14, 15, '16a', '16b', 17, 18, 19, 20, 21)

    line['22/tot_ded'] = sum_lines(
      9, 10, 11, 12, 13, 14, 15, '16c', 17, 18, 19, 20
    )
    line['23/ord_inc'] = line[:tot_inc] - line[:tot_ded]

    # The taxes on lines 24-25 appear to apply only to partnerships that aren't
    # closely held. Line 26 applies to "administrative adjustment requests"
    # under the Bipartisan Budget Act of 2015, which appears to occur only when
    # the partnership seeks to adjust a previous filing.

    ########################################################################
    #
    # SCHEDULE B
    #
    ########################################################################

    case bio.line(:type)
    when 'general' then line['B1a'] = 'X'
    when 'limited' then line['B1b'] = 'X'
    when 'llc' then line['B1c'] = 'X'
    when 'llp' then line['B1d'] = 'X'
    when 'foreign' then line['B1e'] = 'X'
    when /^other: /
      line['B1f'] = 'X'
      line['B1f.text'] = $'
    else
      raise "Invalid partnership type #{bio.line['type']}"
    end

    #
    # Question 2 regards the partnership having 50+% owners, necessitating
    # filing of Schedule B-1. (It is determined automatically.) Question 4
    # relates to the partnership being small, see Line F above; it is answered
    # "yes" if the partnership is small.
    #
    confirm(
      "The answer to every question on Schedule B (other than 2 and 4) is `no'"
    )

    big_indiv, big_inst = partners.map { |f|
      if f.line[:share] >= 0.5 || f.line[:capital] >= 0.5
        f.line[:type]
      else
        nil
      end
    }.compact.partition { |x| %w(Individual Estate).include?(x) }
    line[big_inst.empty? ? 'B2a.no' : 'B2a.yes'] = 'X'
    line[big_indiv.empty? ? 'B2b.no' : 'B2b.yes'] = 'X'
    if line['B2a.yes', :present] || line['B2b.yes', :present]
      compute_form('1065 Schedule B-1')
    end

    line['B3a.no'] = 'X'
    line['B3b.no'] = 'X'
    line['B4.yes'] = 'X'

    # If this were a publicly traded partnership, the line would be called
    # "B5.yes/ptp"
    line['B5.no'] = 'X'
    line['B6.no'] = 'X'
    line['B7.no'] = 'X'
    line['B8.no'] = 'X'
    line['B9.no'] = 'X'
    line['B10a.no'] = 'X'
    line['B10b.no'] = 'X'
    line['B10c.no'] = 'X'
    line['B10d.no'] = 'X'
    line['B12.no'] = 'X'

    # Line 13 is unfilled

    if partners.lines('nationality', :all).any? { |x| x != 'domestic' }
      raise "Foreign partners not currently handled"
    end

    line['B14.no'] = 'X'
    line['B15'] = 0
    line['B16a.no'] = 'X'
    line['B17'] = 0
    line['B18'] = 0
    line['B19.no'] = 'X'
    line['B20.no'] = 'X'
    line['B21.no'] = 'X'
    line['B22.no'] = 'X'
    line['B23.no'] = 'X'

    # Line 24, in 2019, was reversed so the answer is now no.
    line['B24.no'] = 'X'

    line['B25.no'] = 'X'
    line['B26'] = 0

    # Line 27 deals with self-dealing between the partnership and partners.
    line['B27.no'] = 'X'
    line['B28.no'] = 'X'

    # Line 29 applies to partnerships with some relationship to a foreign
    # entity. Line 30 deals with cryptocurrency.
    line['B29a.no'] = 'X'
    line['B29b.no'] = 'X'
    line['B30.no'] = 'X'

    confirm(
      "You do not want to opt out of the centralized partnership audit regime"
    )
    line['B31.no'] = 'X'

    pr_name = bio.line[:rep]
    pr_form = partners.find { |x| x.line['name'] == pr_name }
    unless pr_form
      raise "No partner named #{pr_name} for the partnership representative"
    end
    line['PR.name'] = pr_name
    if pr_form.line['type'] == 'Individual'
      # The TIN is no longer on the form, but still need it for DC
      line['PR.tin!'] = pr_form.line['ssn']
      line['PR.address'] = pr_form.line['address']
      line['PR.address2'] = pr_form.line['address2']
      line['PR.phone'] = pr_form.line['phone']
    else
      raise "No support for non-individual partnership representative"
    end

    ########################################################################
    #
    # SCHEDULE K
    #
    ########################################################################

    line['K1'] = line[:ord_inc]
    line['K5'] = forms('1099-INT').lines(1, :sum)
    assert_no_forms('1099-DIV')
    if has_form?(4562)
      line['K12'] = form(4562).line[12]
    end

    #
    # This needs to follow the worksheet if there are forms of income other than
    # business income.
    #
    line['K14a'] = line['K1']

    partners.each do |p|
      warn("No support for inactive partners") unless p.line[:active?]
      unless p.line[:liability] == 'general'
        warn("No support for limited partners")
      end
      unless p.line[:type] == 'Individual'
        warn("Only individual partners supported")
      end
    end

    line['Analysis.1'] = sum_lines(*%w(K1 K2 K3c K4c K5 K6a K7 K8 K9a K10 K11))\
      - sum_lines(*%w(K12 K13a K13b K13c2 K13d K21))

    line['Analysis.2a(ii)'] = line['Analysis.1']

    # We assumed previously that the Schedule B line 6 answer was yes, so assets
    # are less than $10 million and no M-3 is filed.
    raise "No state in address" unless (line[:city_zip] =~ / ([A-Z]{2}) \d{5}/)
    state = $1
    if %w(
      CT DE DC GA IL IN KY ME MD MA MI NH NJ NY NC OH PA RI SC TN VT VA WV WI
    ).include?(state)
      line[:send_to!] = 'Kansas City MO 64999-0011'
    else
      line[:send_to!] = 'Ogden UT 84201-0011'
    end

    # Keep track of profit-sharing plan contributions.
    psp_contrib = BlankZero

    #
    # Compute Schedule K-1s.
    #
    partners.each do |p|
      k1 = compute_form('1065 Schedule K-1', p)
      psp_contrib += k1.match_table_value(
        '13.code', 13, find: 'R', default: BlankZero
      )
    end

    #
    # This has to be done here because it must follow the computations of the
    # Schedule K-1s. This is not ideal because line 13 is obviously above,
    # suggesting the need for a separate retirement contribution manager as
    # described in the Schedule K-1 program.
    if psp_contrib > 0
      line['K13d.code'] = 'R'
      line['K13d'] = psp_contrib
    end

    #
    # This should be completed separately.
    #
    # compute_form(7004)

  end
end

