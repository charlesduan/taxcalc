require 'tax_form'

#
# Tax underpayment penalty.
#

class Form2210 < TaxForm

  NAME = '2210'

  def year
    2024
  end

  ADD_TAX_LINES = [
      4, # SE tax
      8, # IRA distributions
      9, 10,
      11, # Medicare tax
      12, # NIIT
      14, 15, 16,
      '17a', '17c', '17d', '17e', '17f', '17g', '17h', '17i', '17j', '17l',
      '17z',
      19,
  ]

  def compute

    f1040 = form(1040)

    # TODO: replace with alias
    line[1] = f1040.line[22]

    with_form('1040 Schedule 2') do |f|
      line[2] = f.sum_lines(*ADD_TAX_LINES)
    end

    # I don't qualify for any credits, relevant to line 3
    line[4] = sum_lines(1, 2, 3)
    return if line[4] < 1000

    line[5] = (line[4] * 0.9).round
    line[6] = f1040.line[:withholding] + \
      with_form('1040 Schedule 3', otherwise: 0) { |f| f.line[11, :opt] }
    line[7] = line[4] - line[6]
    return if line[7] < 1000

    ly = @manager.submanager(:last_year)

    # TODO: replace with alias. I'm going to use the Tax Shown formula from the
    # 1040 instructions.
    ly.with_form(1040, otherwise: BlankZero) do |f|
      line[:ly_tax!] = f.line[:tot_tax] - f.sum_lines(27, 28, 29) \
        - ly.with_form('1040 Schedule 3', otherwise: BlankZero) { |f3|
          f3.sum_lines(9, 12)
        }

      line[:ly_threshold!] = f1040.line('status.mfs', :present) ? \
        75_000 : 150_000

      if f.line[:agi] > line[:ly_threshold!]
        line[8] = (1.1 * line[:ly_tax!]).round
      else
        line[8] = line[:ly_tax!]
      end
    end

    line[9] = [ line[5], line[8] ].min

    if line[9] > line[6]
      line['9.yes'] = 'X'
    else
      line['9.no'] = 'X'
      return
    end

    last_col = nil
    %w(a b c d).each do |col|
      line["10#{col}"] = (0.25 * line[9])

      # TODO: This needs to include estimated tax payments
      line["11#{col}"] = (0.25 * line[6])

      if last_col.nil?
        line["15#{col}"] = line["11#{col}"]
      else
        line["12#{col}"] = line["18#{last_col}"]
        line["13#{col}"] = line["11#{col}"] + line["12#{col}"]

        line["14#{col}"] = sum_lines("16#{last_col}", "17#{last_col}")
        line["15#{col}"] = [ 0, line["13#{col}"] - line["14#{col}"] ].max

        line["16#{col}"] = line["15#{col}"] == 0 ? \
          line["14#{col}"] - line["13#{col}"] : 0
      end


      if line["10#{col}"] >= line["15#{col}"]
        line["17#{col}"] = line["10#{col}"] - line["15#{col}"]
        line["18#{col}"] = BlankZero
      else
        line["17#{col}"] = BlankZero
        line["18#{col}"] = line["15#{col}"] - line["10#{col}"]
      end
    end


  end
end

class Form2210Worksheet < TaxForm

  NAME = '2210'

  def year
    2024
  end

  def compute
    compute_period(1, 'a', Date.new(this_year, 4, 15))
    compute_period(1, 'b', Date.new(this_year, 6, 15))
    compute_period(2, 'c', Date.new(this_year, 9, 15))
    compute_period(4, 'd', Date.new(this_year + 1, 1, 15))
  end

  def period_end_date(period)
    case period
    when 1 then Date.new(this_year, 6, 30)
    when 2 then Date.new(this_year, 9, 30)
    when 3 then Date.new(this_year, 12, 31)
    when 4 then Date.new(this_year + 1, 4, 15)
    else raise "Invalid period"
    end
  end


  def compute_period(num, col, start_date)

    unless line("1a.#{col}", :present)
      line["1a.#{col}"] = form(2210).line["17#{col}"]
    compute_period(1, 'a', 4, 15)
    compute_period(2, 'a')
    compute_period(3, 'a')
    compute_period(4, 'a')
end
