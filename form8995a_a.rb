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
    if @qbi_manager.qbi.count > 3
      raise "Too many businesses"
    end

    @prefix = "A"
    @qbi_manager.qbi.each do |qbi|
      # Some prefixes will be left blank, such that the prefixes in this form
      # match those of Form 8995-A.
      compute_business(qbi) if qbi.sstb
      @prefix = @prefix.next
    end
  end

  def lineno(num, prefix: @prefix)
    "#{prefix}.#{num}"
  end

  def setlineno(num, val)
    line[lineno(num)] = val
  end

  def match_line(num, prefix:)
    return line[lineno(num, prefix: prefix)]
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
