class Form1040SE < TaxForm

  NAME = '1040 Schedule SE'

  def year
    2020
  end

  def compute

    set_name_ssn

    #
    # This always uses the long form Schedule SE, because the short-form one
    # doesn't deduct W-2 wages from the extra social security wages tax.
    #
    se_inc = forms('1065 Schedule K-1').lines(14, :sum)
    with_form('1040 Schedule C') do |sc|
      se_inc += sc.line[:net_profit]
    end
    #
    # Unreimbursed partnership expenses are not self-employment income
    #
    with_form('1040 Schedule E') do |se|
      break unless se.line['28a', :present] && se.line['28i', :present]
      se.line['28a', :all].zip(se.line['28i', :all]).each do |name, loss|
        se_inc -= loss if name =~ /^UPE/
      end
    end
    line[2] = se_inc

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
    line['7!'] = 137_700 # Maximum social security wages, 2020

    line['8a'] = forms('W-2').lines(3, :sum) + forms('W-2').lines(7, :sum)

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
