require_relative '../tax_form'
require_relative 'd40s'
require_relative 'dc_tax_table'
require_relative 'd2210'

class FormD40 < TaxForm
  include DcTaxTable

  NAME = 'D-40'

  def year
    2022
  end

  def compute

    f1040 = forms(1040)
    s1 = forms('1040 Schedule 1')

    # Since I'm just using this to fill in the online form, we'll skip the bio
    # information
    #
    # Biographical
    #@bio = forms('Biographical').find { |x| x.line[:whose] == 'mine' }
    #@sbio = forms('Biographical').find { |x| x.line[:whose] == 'spouse' }

    #line[:phone] = @bio.line[:phone].gsub(/\D+/, '')
    #line[:tin] = @bio.line[:ssn].gsub('-', '')
    #line[:dob] = @bio.line[:birthday].strftime("%m%d%Y")
    #if @sbio
    #  line[:spouse_tin] = @sbio.line[:ssn].gsub('-', '')
    #  line[:spouse_dob] = @sbio.line[:birthday].strftime("%m%d%Y")
    #end
    #line[:first_name] = @bio.line[:first_name]
    #line[:last_name] = @bio.line[:last_name]
    #if @sbio
    #  line[:spouse_first_name] = @sbio.line[:first_name]
    #  line[:spouse_last_name] = @sbio.line[:last_name]
    #end
    #line[:address1] = @bio.line[:home_address]
    #line[:address2] = @bio.line[:apt_no]
    #line[:city], line[:state], line[:zip] = @bio.line[:city_zip].match(
    #  /^(.*), ([A-Z]{2}) (\d{5})$/
    #)[1, 3]

    # Filing status
    if f1040.line['status.mfj', :present] or f1040.line['status.mfs', :present]
      line['1/status'] = 'mfssr'
    else
      raise 'Unknown filing status'
    end

    #
    # Line 3 instructions are on Schedule HSR. Again, since I'm just using this
    # to calculate numbers, I'll assume it was satisfied.
    line[3] = 'X'
    #
    #acceptable_coverage = [ 'family' ]
    #acceptable_coverage.push('individual') if line[:status] == 'single'
    #hc_months = (forms('1095-B') + forms('1095-C')).map { |f|
    #  if acceptable_coverage.include?(f.line[:coverage])
    #    f.line[:months, :all]
    #  else
    #    []
    #  end
    #}.flatten.uniq
    #if hc_months.include?('all') || hc_months.length == 12
    #  line[3] = 'X'
    #else
    #  raise "DC health coverage forms not implemented"
    #end

    line[:a] = f1040.lines(:wages, :sum)
    line[:b] = s1.lines(:bus_inc, :sum)
    if line[:b] > 12_000
      confirm("Your business income is exempt from D-30 filing")
    end
    line[:c] = f1040.lines(:cap_gain, :sum)
    line[:d] = s1.lines(:rrerpst, :sum)

    line[4] = f1040.lines(:agi, :sum)

    confirm('You have no DC income additions or subtractions')

    line[7] = sum_lines(4, 5, 6)

    # State tax refunds
    line[9] = s1.lines(:taxrefund, :sum)
    # SS income
    #line[10] = f1040.lines('6b', :sum)

    # Line 11
    if has_form?('D-20') or has_form?('D-30') or has_form?('D-41')
      raise "Need to implement line 11"
    end

    # Line 12
    #if age(@bio) >= 62
    #  confirm('You received no income as an annuitant\'s survivor')
    #end
    # Line 13, unemployment benefits, assumed to be zero

    # Line 14 assumed to be zero from Schedule I, per above

    line[15] = sum_lines(*8..14)

    # DC AGI
    line['16/agi'] = line[7] - line[15]

    if has_form?('1040 Schedule A')
      line['17itemized'] = 'X'
      line['18/ded'] = compute_form('D-40 Calculation F').line[:ded]
    else
      line['17standard'] = 'X'
      # Assumed no special conditions apply
      line['18/ded'] = case line['status']
                       when 'mfssr', 'mfj', 'qw' then 25900
                       when 'single', 'mfs' then 12950
                       when 'hoh' then 19400
                       else raise "Unknown status"
                       end

    end

    line['19/tax_inc'] = line[16] - line[18]

    # Capital gain from sale of qualified tech company. This can be assumed to
    # be zero if no Schedule D was filed.
    # As of 2020, this deduction has been suspended; code is commented here.
    # if has_form?('1040 Schedule D')
    #   raise "DC capital gains for QHTC not implemented"
    # else
    #   line[20] = BlankZero
    # end
    # line[21] = line[19] - line[20]
    # if line[20] == 0
    #   line[23] = BlankZero
    # else
    #   raise "DC tax on QHTC gains not implemented"
    # end

    if line[:status] == 'mfssr'
      line['20.mfssr'] = 'X'
      line['20/tax'] = compute_form('D-40 Schedule S').line[:calc_j_tax]
    else
      line['20/tax'] = compute_tax(line[19])
    end

    # Child care expenses. This is based on DC Code section 47-1806.04(c)(1). My
    # interpretation of that section is that no DC credit may be taken where the
    # federal credit is not "allowed," so I don't think that a federal MFS
    # person could take the credit.
    if line[:status] != 'mfs'
      if f1040.any? { |f| f.line['status.mfs', :present] }
        line[21] = BlankZero
      else
        line['21.pre'] = forms(2441).lines(:credit, :sum)
        line[21] = (0.32 * line['21.pre']).round
      end
    end

    # Line 22: Schedule U credits. We don't have any of these.
    line[23] = sum_lines(21, 22)
    line['24/pre_hc_tax'] = [ BlankZero, line[20] - line[23] ].max

    # Line 28: DC health care
    if (line[3, :present])
      line[25] = BlankZero
    else
      raise "DC health care not implemented"
    end

    line['26/tot_tax'] = sum_lines(24, 25)

    # Line 27: earned income credit. Assumed that there isn't one.
    # Line 28: Schedule H homeowner/renter property tax credit. The limit
    # appears on Instructions for Schedule H, Eligibility.
    if f1040.any? { |f| f.line[:agi] <= 78_600 }
      raise "Schedule H may be applicable but not implemented"
    end

    # Line 29: refundable Schedule U credits. Assumed we don't have any.

    # Withholdings
    wh = forms('W-2').map { |f|
      f.match_table_value(15, 17, find: 'DC', default: 0)
    }.sum
    wh += forms('1099-MISC').map { |f|
      f.match_table_value(15, 17, find: 'DC', default: 0)
    }.sum
    wh += forms('1099-NEC').map { |f|
      f.match_table_value(6, 5, find: 'DC', default: 0)
    }.sum
    line['31/withholdings'] = wh

    # Estimated tax
    line['32/est_tax'] = forms('State Estimated Tax') { |f|
      f.line[:state] == 'DC'
    }.lines['amount', :sum]

    # Line 33: extension to file estimated tax paid. Assumed there isn't any.
    # Lines 34-35: amounts relevant to amended returns. Assumed that this isn't
    # one.

    # Total payments and refundable credits.
    line['36/payments'] = sum_lines(*(30..35))

    # If the payments/refunds are less than the total tax, then there is tax
    # due.
    if line[:payments] < line[:tot_tax]
      line['37/tax_due'] = line[:tot_tax] - line[:payments]
      if line[:tax_due] >= 100
        d2210 = compute_form('D-2210')
        if d2210
          line['40.check'] = 'X'
          line[40] = d2210.line[:underpay_int]
        end
      end
      line['42/tot_due'] = sum_lines(37, 40, 41)

    else
      # Payments/refunds exceed total tax; a refund is due.
      line['38/tax_refund'] = line[:payments] - line[:tot_tax]
      line[43] = line[38] - sum_lines(39, 40, 41)
      if interview("Is your refund going to an account outside the U.S.?")
        line['43.outside_us.yes'] = 'X'
      else
        line['43.outside_us.no'] = 'X'
      end
      with_form('Refund Direct Deposit') do |f|
        line[:direct_deposit] = 'X'
        line["refund_dd_#{f.line[:type]}"] = 'X'
        line[:routing_number] = f.line[:routing]
        line[:account_number] = f.line[:account]
      end
    end
  end

end

#
# Itemized deductions.
#
class D40CalculationF < TaxForm
  NAME = 'D-40 Calculation F'

  def year
    2020
  end

  def compute
    sch_as = forms('1040 Schedule A')
    d40 = form('D-40')
    line[:ded_cap!] = (d40.line[:status] == 'mfs' ? 100000 : 200000)

    line[:a] = sch_as.lines(:total, :sum)
    line[:b] = sch_as.lines(:salt, :sum)
    line[:c] = line_a - line_b
    line[:d] = sch_as.lines(:salt_real, :sum)
    line[:e] = sch_as.lines(:other_tax, :sum)
    line[:f] = sum_lines(:c, :d, :e)

    if d40.line[:agi] <= line[:ded_cap!]
      line[:fill!] = line[:f]
      return
    end

    line[:g] = %w(med_ded inv_int cas_theft).map { |l|
      sch_as.lines(l, :sum)
    }.inject(&:+)
    line[:h] = line_f - line_g
    line[:i] = d40.line[:agi]
    line[:j] = line[:ded_cap!]
    line[:k] = line_i - line_j
    line[:l] = (line_k * 0.05).round
    line[:m] = [ 0, line_h - line_l ].max
    line['n/ded'] = sum_lines(:g, :m)
  end

end

