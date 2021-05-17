require_relative 'tax_form'

class Form1040_2 < TaxForm

  NAME = '1040 Schedule 2'

  def year
    2020
  end

  def compute
    set_name_ssn

    # Bizarrely, Form 6251 (AMT) requires Schedule 2, Line 2. So it is computed
    # first.
    assert_no_forms('1095-A') # Line 2; advance health premium credit
    line[2] = BlankZero

    amt_test = compute_form(
      "1040 Worksheet to See If You Should Fill In Form 6251"
    )
    if amt_test.line[:fill_yes, :present]
      line[1] = compute_form(6251).line['amt_tax']
      place_lines(2)
    end

    line['3/add_tax'] = sum_lines(1, 2)

    #
    # Part II
    #
    with_form('1040 Schedule SE') do |sched_se|
      line[4] = sched_se.line[:se_tax]
    end

    # Line 5: unreported social security/medicare tax
    # Assumed that there were no tips earned
    forms('W-2').each do |f|
      if f.line[3, :opt] > 0 && f.line[4, :opt] == 0
        raise "Possibly need Form 8919"
      end
      if f.line[5, :opt] > 0 && f.line[6, :opt] == 0
        raise "Possibly need Form 8919"
      end
    end

    # Additional Medicare tax
    l8 = BlankZero
    compute_form(8959) do |f8959|
      line['8a'] = 'X'
      l8 += f8959.line[:add_mc_tax]
    end

    # Net investment income tax
    compute_form(8960) do |f8960|
      line['8b'] = 'X'
      l8 += f8960.line[:niit]
    end
    line[8] = l8

    line['10/other_tax'] = sum_lines(4, 5, 6, '7a', '7b', 8)
  end

  def needed?
    # Schedule 2 is needed, even if it reports zero, if the AMT computation is
    # performed.
    line[3] > 0 || has_form?(6251) || line[10] > 0
  end
end

