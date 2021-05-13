require_relative 'tax_form'

class Form8995A_A < TaxForm

  NAME = "8995-A Schedule A"

  def year
    2020
  end

  def needed?
    return line['A.1b', :present]
  end

  def compute
    set_name_ssn

    @qbi_manager = form('QBI Manager')
    @prefix = "A"
    if @qbi_manager.qbi.count > 3
      raise "Too many businesses"
    end

    @qbi_manager.qbi.each do |qbi|
      next unless qbi.sstb
      compute_business(qbi)
      @prefix = @prefix.next
    end
  end

  def lineno(num, prefix: @prefix)
    "#{prefix}.#{num}"
  end

  def setlineno(num, val)
    line[lineno(num)] = val
  end

  def match_line(num, tin:)
    %w(A B C).each do |prefix|
      tin_lineno = lineno('1b', prefix: prefix)
      next unless line[tin_lineno, :present]
      if line[tin_lineno] == tin
        return line[lineno(num, prefix: prefix)]
      end
    end
    raise "No matching line X.#{num} for TIN #{tin}"
  end

  def compute_business(qbi)
    setlineno('1a', qbi.name.gsub(/.{10}/, "\\&\n"))
    setlineno('1b', qbi.tin)
    setlineno(2, qbi.amount)
    setlineno(3, BlankZero)
    setlineno(4, BlankZero)
    compute_lines_5_to_10
    setlineno(11, (line[10] / 100.0 * line[lineno(2)]).round)
    setlineno(12, (line[10] / 100.0 * line[lineno(3)]).round)
    setlineno(13, (line[10] / 100.0 * line[lineno(4)]).round)
  end

  def compute_lines_5_to_10
    return if line[5, :present]
    line[5] = @qbi_manager.line[:taxable_income]
    line[6] = form(1040).status.qbi_threshold
    line[7] = line[5] - line[6]
    line[8] = form(1040).status.double_mfj(50_000)
    line[9] = (line[7] * 1.0 / line[8]).round(5)
    line[10] = 100.0 - line[9] * 100.0
  end

end
