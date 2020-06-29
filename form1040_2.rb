require 'tax_form'

class Form1040_2 < TaxForm

  def name
    '1040 Schedule 2'
  end

  def year
    2019
  end

  def compute
    set_name_ssn

    # Bizarrely, Form 6251 requires Schedule 2, Line 2. So it is computed
    # first.
    assert_no_forms('1095-A') # Line 2; advance health premium credit
    line[2] = BlankZero

    amt_test = @manager.compute_form(AMTTestWorksheet)
    if amt_test.line[:fill_yes, :present]
      line[1] = @manager.compute_form(Form6251).line[11]
    end

    place_lines(2)

    line[3] = sum_lines(1, 2)

    #
    # Part II
    #
    sched_se = find_or_compute_form('1040 Schedule SE', Form1040SE)
    if sched_se
      line[4] = sched_se.line[12]
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
    f8959 = compute_form(Form8959)
    if f8959
      line['8a'] = 'X'
      l8 += f8959.line[18]
    end

    if form(1040).line_agi > form(1040).status.niit_threshold
      f8960 = @manager.compute_form(Form8960)
      line['8b'] = 'X'
      l8 += f8960.line[17]
    end
    line[8] = l8

    line[10] = sum_lines(4, 5, 6, '7a', '7b', 8)
  end

  def needed?
    # Schedule 2 is needed, even if it reports zero, if the AMT computation is
    # performed.
    line[3] > 0 || has_form?(6251) || line[10] > 0
  end
end

# Not inflation adjusted
FilingStatus.set_param('niit_threshold', 200000, 250000, 125000, 200000, 250000)
