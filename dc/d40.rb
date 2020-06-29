require 'tax_form'
require 'dc/d40s'
require 'dc/dc_tax_table'
require 'dc/d40wh'
require 'dc/d2210'

class FormD40 < TaxForm
  include DcTaxTable

  def name
    'D-40'
  end

  def year
    2019
  end

  def compute

    # Biographical
    @bio = forms('Biographical').find { |x| x.line[:whose] == 'mine' }
    @sbio = forms('Biographical').find { |x| x.line[:whose] == 'spouse' }

    line[:phone] = @bio.line[:phone]
    line[:tin] = @bio.line[:ssn]
    line[:dob] = @bio.line[:birthday].strftime("%m%d%Y")
    if @sbio
      line[:spouse_tin] = @sbio.line[:ssn]
      line[:spouse_dob] = @sbio.line[:birthday].strftime("%m%d%Y")
    end
    line[:first_name] = @bio.line[:first_name]
    line[:last_name] = @bio.line[:last_name]
    if @sbio
      line[:spouse_first_name] = @sbio.line[:first_name]
      line[:spouse_last_name] = @sbio.line[:last_name]
    end
    line[:address1] = @bio.line[:home_address]
    line[:address2] = @bio.line[:apt_no]
    line[:city], line[:state], line[:zip] = @bio.line[:city_zip].match(
      /^(.*), ([A-Z]{2}) (\d{5})$/
    )[1, 3]

    # Filing status
    line[1] = interview("Enter your DC filing status:")
    unless %w(single mfj mfs dep mfssr hoh qw).include?(line[1])
      raise 'Unknown filing status'
    end



    line['a'] = forms(1040).lines(1, :sum)
    line['b'] = forms('1040 Schedule 1').lines(3, :sum)
    line['c'] = forms(1040).lines(6, :sum)
    line['d'] = forms('1040 Schedule 1').lines(5, :sum)

    hc_months = (forms('1095-B') + forms('1095-C')).map { |f|
      f.line_coverage == 'family' ? f.line_months : []
    }.flatten.uniq
    if hc_months.include?('all') || hc_months.length == 12
      line[3] = 'X'
    else
      raise "DC health coverage forms not implemented"
    end

    line[4] = forms(1040).lines(:agi, :sum)

    # These are on Schedule I. One check is made here.
    if has_form?(4562) and forms(4562).lines(12, :sum) > 25000
      raise "Schedule I, line 3 not implemented"
    end
    assert_question('Do you have any DC income additions or subtractions?',
                    false)

    line[7] = sum_lines(4, 5, 6)

    # State tax refunds
    line[9] = forms('1040 Schedule 1').lines(:taxrefund, :sum)
    # SS income; removed from 1040
    #line[9] = forms(1040).lines('20b', :sum)

    assert_question(
      "Did you file a DC franchise or fiduciary return (D-20, D-30, D-40)?",
      false
    )

    # Line 11
    assert_question('Did you receive income as an annuitant\'s survivor?',
                    false)

    line[14] = sum_lines(*8..13)

    # DC AGI
    line[15] = line[7] - line[14]

    if has_form?('1040 Schedule A')
      line['16itemized'] = 'X'
      line[17] = @manager.compute_form(D40CalculationF).line[:fill!]
    else
      line['16standard'] = 'X'
      raise "Must do Calculation G-1 of Schedule S"
    end

    line[18] = line[15] - line[17]

    # Capital gain from sale of qualified tech company. This can be assumed to
    # be zero if no Schedule D was filed.
    if has_form?('1040 Schedule D')
      raise "DC capital gains for QHTC not implemented"
    else
      line[19] = BlankZero
    end

    line[20] = line[18] - line[19]

    line[21] = compute_tax(line[20])
    if line[19] == 0
      line[22] = BlankZero
    else
      raise "DC tax on QHTC gains not implemented"
    end

    if line[1] == 'mfssr'
      line['23.mfssr'] = 'X'
      line[23] = compute_form(FormD40S).line['J.m']
    else
      line[23] = sum_lines(21, 22)
    end

    # Child care expenses. This is based on DC Code section 47-1806.04(c)(1). My
    # interpretation of that section is that no DC credit may be taken where the
    # federal credit is not "allowed," so I don't think that a federal MFS
    # person could take the credit.
    if has_form?(2441)
      line[24] = 0.32 * forms(2441).lines(9, :sum)
    elsif forms(1040).any? { |f| f.line['status.mfs', :present] }
      line[24] = BlankZero
    else
      raise "Need to implement DC child care expenses eligibility"
    end

    # Line 25: Schedule U credits. We don't have any of these.
    line[26] = sum_lines(24, 25)
    line[27] = [ BlankZero, line[23] - line[26] ].max

    # Line 28: DC health care
    if (line[3, :present])
      line[28] = BlankZero
    else
      raise "DC health care not implemented"
    end

    line[29] = sum_lines(27, 28)

    # Line 30: earned income credit. Assumed that there isn't one.
    # Line 31: Schedule H homeowner/renter property tax credit.
    if forms(1040).any? { |f|
      f.line_agi <= 75_000
    }
      raise "Schedule H may be applicable but not implemented"
    end

    # Line 32: refundable Schedule U credits. Assumed we don't have any.

    # Withholdings
    line[33] = @manager.compute_form(FormD40WH).line['total']

    # Estimated tax
    line[34] = forms('State Estimated Tax') { |f|
      f.line[:state] == 'DC'
    }.lines['amount', :sum]

    # Line 35: extension to file estimated tax paid. Assumed there isn't any.
    # Lines 36-37: amounts relevant to amended returns. Assumed that this isn't
    # one.

    # Total payments and refundable credits.
    line[38] = sum_lines('30d', '30e', 31, 32, 33, 34, 35, 36)

    # If the payments/refunds are less than the total tax, then there is tax
    # due.
    if line[38] < line[29]
      line[39] = line[29] - line[38]
      compute_underpayment
      line[44] = sum_lines(39, 42, 43)

    else
      # Payments/refunds exceed total tax; a refund is due.
      line[40] = line[38] - line[29]
      line[45] = line[40] - sum_lines(41, 42, 43)
      if interview("Is your refund going to an account outside the U.S.?")
        line['38.outside_us.yes'] = 'X'
      else
        line['38.outside_us.no'] = 'X'
      end
    end
  end

  def compute_underpayment
    return if line[39] < 100
    prepayments = sum_lines(33, 34)
    if prepayments < 0.9 * line[29]
      last_year_tax = @manager.submanager(:last_year).form('D-40').line[22]
      if prepayments < 1.1 * last_year_tax
        line['35.check'] = 'X'
        line[35] = @manager.compute_form(FormD2210).line[11]
      end
    end
  end

end

class D40CalculationF < TaxForm
  def name
    'D-40 Calculation F'
  end

  def year
    2019
  end

  def compute
    sch_as = forms('1040 Schedule A')

    line[:a] = sch_as.lines(:total, :sum)
    line[:b] = sch_as.lines(:salt, :sum)
    line[:c] = line_a - line_b
    line[:d] = sch_as.lines(:salt_real, :sum)
    line[:e] = sch_as.lines(:other_tax, :sum)
    line[:f] = sum_lines(:c, :d, :e)

    d40 = form('D-40')
    if d40.line[14] <= (d40.line[1] == 'mfs' ? 100000 : 200000)
      line[:fill!] = line[:f]
      return
    end

    line[:g] = %w(4 9 15).map { |l| sch_as.lines(l, :sum) }.inject(&:+)
    line[:h] = line_f - line_g
    line[:i] = d40.line[15]
    line[:j] = (d40.line[1] == 'mfs' ? 100000 : 200000)
    line[:k] = line_i - line_j
    line[:l] = (line_k * 0.05).round
    line[:m] = [ 0, line_h - line_l ].max
    line[:fill!] = line[:n] = sum_lines(:g, :m)
  end

end

