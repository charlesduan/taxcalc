require 'tax_form'

class Form1040_4 < TaxForm

  def name
    '1040 Schedule 4'
  end

  def year
    2018
  end

  def compute
    sched_se = find_or_compute_form('1040 Schedule SE', Form1040SE)
    if sched_se
      line[57] = sched_se.line[12]
    end

    # Line 58: unreported social security/medicare tax
    # Assumed that there were no tips earned
    forms('W-2').each do |f|
      if f.line[3, :opt] > 0 && f.line[4, :opt] == 0
        raise "Possibly need Form 8919"
      end
      if f.line[5, :opt] > 0 && f.line[6, :opt] == 0
        raise "Possibly need Form 8919"
      end
    end

    l62 = BlankZero
    f8959 = compute_form(Form8959)
    if f8959
      line['62a'] = 'X'
      l62 += f8959.line[18]
    end

    if form(1040).line[7] > form(1040).status.niit_threshold
      f8960 = @manager.compute_form(Form8960)
      line['62b'] = 'X'
      l62 += f8960.line[17]
    end
    line[62] = l62

    line[64] = sum_lines(57, 58, 59, '60a', '60b', 61, 62)

  end
end

# Not inflation adjusted
FilingStatus.set_param('niit_threshold', 200000, 250000, 125000, 200000, 250000)
