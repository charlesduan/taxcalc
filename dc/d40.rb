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
    2018
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
    line['b'] = forms('1040 Schedule 1').lines(12, :sum)
    line['c'] = forms('1040 Schedule 1').lines(13, :sum)
    line['d'] = forms('1040 Schedule 1').lines(17, :sum)

    line[3] = forms(1040).lines(7, :sum)

    # These are on Schedule I. One check is made here.
    if forms(4562).lines(12, :sum) > 25000
      raise "Schedule I, line 3 not implemented"
    end
    assert_question('Do you have any DC income additions or subtractions?',
                    false)

    line[6] = sum_lines(3, 4, 5)

    # State tax refunds
    line[8] = forms('1040 Schedule 1').lines(10, :sum)
    # SS income; removed from 1040
    #line[9] = forms(1040).lines('20b', :sum)

    assert_question(
      "Did you file a DC franchise or fiduciary return (D-20, D-30, D-40)?",
      false
    )

    # Line 11
    assert_question('Did you receive income as an annuitant\'s survivor?',
                    false)

    line[13] = sum_lines(*7..12)
    line[14] = line[6] - line[13]

    if has_form?('1040 Schedule A')
      line['15itemized'] = 'X'
      line[16] = @manager.compute_form(D40CalculationF).line[:fill!]
    else
      line['15standard'] = 'X'
      raise "Must do Calculation G-1 of Schedule S"
    end

    line[17] = line[14] - line[16]

    if line[1] == 'mfssr'
      line['18.mfssr'] = 'X'
      line[18] = compute_form(FormD40S).line['J.i']
    else
      line[18] = compute_tax(line[17])
    end

    # Child care expenses. This is based on DC Code section 47-1806.04(c)(1). My
    # interpretation of that section is that no DC credit may be taken where the
    # federal credit is not "allowed," so I don't think that a federal MFS
    # person could take the credit.
    line[19] = forms('1040 Schedule 3').lines(49, :sum)

    # Line 20: Schedule U credits. We don't have any of these.
    line[21] = sum_lines(19, 20)
    line[22] = [ BlankZero, line[18] - line[21] ].max

    # Line 23: earned income credit. Assumed that there isn't one.
    # Line 24: Schedule H homeowner/renter property tax credit.
    if forms(1040).lines(7, :sum) <= 62000
      raise "Schedule H may be applicable but not implemented"
    end
    # Line 25: refundable Schedule U credits. Assumed we don't have any.
    line[26] = @manager.compute_form(FormD40WH).line['total']

    line[27] = forms('State Estimated Tax') { |f|
      f.line[:state] == 'DC'
    }.lines['amount', :sum]

    # Line 28: extension to file estimated tax paid. Assumed there isn't any.
    # Lines 29-30: amounts relevant to amended returns. Assumed that this isn't
    # one.

    # Total payments and refundable credits.
    line[31] = sum_lines('23d', '23e', 24, 25, 26, 27, 28, 29)

    # If the payments/refunds are less than the total tax, then there is tax
    # due.
    if line[31] < line[22]
      line[32] = line[22] - line[31]

      if line[32] >= 100
        prepayments = sum_lines(26, 27)
        if prepayments < 0.9 * line[22]
          last_year_tax = @manager.submanager(:last_year).form('D-40').line[26]
          if prepayments < 1.1 * last_year_tax
            line['35.check'] = 'X'
            line[35] = @manager.compute_form(FormD2210).line[11]
          end
        end
      end

      line[37] = sum_lines(32, 35, 36)

    else
      # Payments/refunds exceed total tax; a refund is due.
      line[33] = line[31] - line[22]
      line[38] = line[33] - sum_lines(34, 35, 36)
      if interview("Is your refund going to an account outside the U.S.?")
        line['38.outside_us.yes'] = 'X'
      else
        line['38.outside_us.no'] = 'X'
      end
    end
  end

end

class D40CalculationF < TaxForm
  def name
    'D-40 Calculation F'
  end

  def year
    2018
  end

  def compute
    sch_as = forms('1040 Schedule A')

    line[:a] = sch_as.lines(17, :sum)
    line[:b] = sch_as.lines(7, :sum)
    line[:c] = line_a - line_b
    line[:d] = sch_as.lines('5b', :sum)
    line[:e] = sch_as.lines(6, :sum)
    line[:f] = sum_lines(:c, :d, :e)

    d40 = form('D-40')
    if d40.line[14] <= (d40.line[1] == 'mfs' ? 100000 : 200000)
      line[:fill!] = line[:f]
      return
    end

    line[:g] = %w(4 9 15).map { |l| sch_as.lines(l, :sum) }.inject(&:+)
    line[:h] = line_f - line_g
    line[:i] = d40.line[14]
    line[:j] = (d40.line[1] == 'mfs' ? 100000 : 200000)
    line[:k] = line_i - line_j
    line[:l] = (line_k * 0.05).round
    line[:m] = [ 0, line_h - line_l ].max
    line[:fill!] = line[:n] = sum_lines(:g, :m)
  end

end

