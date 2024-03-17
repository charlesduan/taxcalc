require_relative 'tax_form'
require_relative 'form8995a_a'

# Qualified business income deduction, high-income form
class Form8995A < TaxForm
  NAME = '8995-A'

  def year
    2020
  end

  def compute
    set_name_ssn

    @qbi_manager = form('QBI Manager')
    if @qbi_manager.qbi.count > 3
      raise "Too many businesses"
    end
    compute_form('8995-A Schedule A')

    @prefix = "A"
    @qbi_manager.qbi.each do |qbi|
      compute_business(qbi)
      @prefix = @prefix.next
    end

    line[16] = sum_lines('A.15', 'B.15', 'C.15')
    line[27] = line[16]

    # Lines 28-31
    confirm('You have no REIT dividends or publicly traded partnership income')

    line[32] = sum_lines(27, 31)
    line[33] = @qbi_manager.line[:taxable_income]
    line[34] = form(1040).line[:qualdiv] + with_form(
      '1040 Schedule D', otherwise: form(1040).line[:cap_gain]
    ) { |f|
      [ [ f.line[15, :opt], f.line[16, :opt] ].min, 0 ].max
    }
    line[35] = [ line[33] - line[34], 0 ].max
    line[36] = (line[35] * 0.2).round
    line[37] = [ line[32], line[36] ].min

    # Assuming no agricultural/horticultural cooperatives
    line['39/deduction'] = sum_lines(37, 38)
    line['40/reit_ptp_carryforward'] = [ sum_lines(28, 29), 0 ].min
  end

  def lineno(num)
    "#@prefix.#{num}"
  end

  def setlineno(num, val)
    line[lineno(num)] = val
  end

  def compute_business(qbi)
    setlineno('1a', qbi.name)
    setlineno('1b', 'X') if qbi.sstb
    setlineno('1d', qbi.tin)

    setlineno(
      2, with_form('8995-A Schedule A', otherwise: qbi.amount) { |f|
        f.match_line(11, tin: line[lineno('1d')])
      }
    )
    setlineno(3, (line[lineno(2)] * 0.2).round)

    if @qbi_manager.line[:taxable_income] <= form(1040).status.qbi_threshold
      setlineno(13, line[lineno(3)])
    else
      # Assuming there are zero W-2 wages and UBIA

      setlineno(4, with_form('8995-A Schedule A', otherwise: 0) { |f|
        f.match_line(12, tin: line[lineno('1d')])
      })
      setlineno(5, (0.5 * line[lineno(4)]).round)
      setlineno(6, (0.25 * line[lineno(4)]).round)

      setlineno(7, with_form('8995-A Schedule A', otherwise: 0) { |f|
        f.match_line(13, tin: line[lineno('1d')])
      })
      setlineno(8, (0.025 * line[lineno(7)]).round)

      setlineno(9, line[lineno(6)] + line[lineno(8)])
      setlineno(10, [ line[lineno(5)], line[lineno(9)] ].max)
      setlineno(11, [ line[lineno(3)], line[lineno(10)] ].min)
      setlineno(12, compute_phased_in_reduction(qbi))
      setlineno(13, [ line[lineno(11)], line[lineno(12)] ].max)
    end

    setlineno(14, with_form('8995-A Schedule D', otherwise: 0) { |f|
      f.match_line(6, tin: line[lineno('1d')])
    })
    setlineno(15, line[lineno(13)] - line[lineno(14)])
  end

  #
  # Computes Part III, including the condition for whether to calculate it
  #
  def compute_phased_in_reduction(qbi)
    tax_inc = @qbi_manager.line[:taxable_income]
    threshold = form(1040).status.qbi_threshold
    qbi_max = form(1040).status.qbi_max

    # This computation should have been skipped
    raise "Should not be computing this" if tax_inc <= threshold

    if tax_inc > qbi_max
      explain("Taxable income (#{tax_inc}) exceeds QBI max (#{qbi_max})")
      return BlankZero
    end
    if line[lineno(10)] >= line[lineno(3)]
      explain("Line 10 (#{line[lineno(10)]}) >= Line 3 (#{line[lineno(3)]})")
      return BlankZero
    end

    setlineno(17, line[lineno(3)])
    setlineno(18, line[lineno(10)])
    setlineno(19, line[lineno(17)] - line[lineno(18)])

    unless line[20, :present]
      line[20] = tax_inc
      line[21] = threshold
      line[22] = line[20] - line[21]
      line[23] = qbi_max - threshold
      line[24] = (line[22] * 100.0 / line[23]).round(3)
    end

    setlineno(25, (line[24] / 100.0 * line[lineno(19)]).round)
    setlineno(26, line[lineno(17)] - line[lineno(25)])
    return line[lineno(26)]
  end

end

