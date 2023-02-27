require 'tax_form'
require 'home_office'

class Form1040SE < TaxForm

  NAME = '1040 Schedule SE'

  def year
    2022
  end

  def initialize(manager, ssn)
    super(manager)
    @ssn = ssn
  end

  def compute

    ho_mgr = find_or_compute_form('Home Office Manager')

    bios = forms('Biographical') { |f| f.line['ssn'] == @ssn }
    raise "Ambiguous SSN for Schedule SE" if bios.count != 1
    @bio = bios.first
    line[:name] = @bio.line[:first_name] + ' ' + bio.line[:last_name]
    line[:ssn] = @ssn

    #
    # This always uses the long form Schedule SE, because the short-form one
    # doesn't deduct W-2 wages from the extra social security wages tax.
    #
    se_inc = forms('1065 Schedule K-1') { |f|
      f.line[:ssn] == @ssn
    }.lines(14, :sum)
    se_inc += forms('1040 Schedule C') { |f|
      f.line[:ssn] == @ssn
    }.lines(:net_profit, :sum)

    #
    # We now need to subtract out unreimbursed partnership expenses, per the
    # instructions on Form 1065 Schedule K1, line 14. This was previously done
    # based on Form 1040 Schedule E. However, Schedule SE needs to be computed
    # in the process of filing Form 1065 to compute the proper profit-sharing
    # contribution to a 401(k). As a result, the subtracted amount is computed
    # based on the input data for Schedule E.
    #
    se_reduce = forms('Unreimbursed Partnership Expense') { |f|
      f.line[:ssn] == @ssn
    }.lines(:amount, :sum)

    se_reduce += ho_mgr.each_match(
      :type => 'partnership',
      :ssn => @ssn,
    )

    line[2] = se_inc - se_reduce
    if se_reduce >= 0
      line['2*note'] = 'Line 2 reduced based on ' + \
        'unreimbursed partnership expenses'
    end

    line['3/tot_inc'] = sum_lines('1a', '1b', 2)

    line['4a'] = line[3] <= 0 ? line[3] : (line[3] * 0.9235).round

    line['4c'] = sum_lines('4a', '4b')
    if line['4c'] < 400
      line['6/se_inc'] = BlankZero
      line['12/se_tax'] = BlankZero
      line['13/se_ded'] = BlankZero
      return
    end

    # Assuming no church employee income

    line['6/se_inc'] = sum_lines('4c', '5b')
    line['7!'] = 147_700 # Maximum social security wages, 2022

    relevant_w2 = forms('W-2') { |f|
      f.line[:a] == @ssn
    }
    line['8a'] = relevant_w2.lines(3, :sum) + relevant_w2.lines(7, :sum)

    # Lines 8b and 8c relate to unreported tips and employee wages
    # miscategorized as independent contractor payments. These two assertions
    # ensure that neither occurred.
    confirm('You received no unreported tips')
    if has_form?('1099-MISC') or has_form?('1099-NEC')
      confirm("None of your independent contractor pay was mischaracterized")
    end

    line['8d'] = sum_lines('8a', '8b', '8c')

    l9 = line['7!'] - line['8d']
    if l9 <= 0
      line[9] = 0
      line[10] = 0
    else
      line[9] = l9
      line[10] = ([ line[6], line[9] ].min * 0.124).round
    end
    line[11] = (line[6] * 0.029).round
    line['12/se_tax'] = sum_lines(10, 11)
    line['13/se_ded'] = (line[12] * 0.5).round
  end

  def needed?
    return line[:tot_inc] > 0
  end

end
