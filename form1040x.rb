require 'tax_form'
require 'filing_status'

class Form1040X < TaxForm

  def name
    '1040X'
  end

  def initialize(manager)
    super(manager)
  end

  def compute
    line[status.name] = 'X'

    if form(1040).line('61box', :present)
      line['health-coverage.yes'] = 'X'
    else
      line['health-coverage.no'] = 'X'
    end

    line['1A'] = form(1040).line(37)
    line['2A'] = form(1040).line(40)
    line['3A'] = line['1A'] - line['2A']

    line['4A'] = form(1040).line(42)
    line['5A'] = line['3A'] - line['4A']

    line['6A'] = form(1040).line(47)
    line['7A'] = form(1040).line(55)
    line['8A'] = line['6A'] - line['7A']

    line['9A'] = form(1040).line(61)
    line['10A'] = form(1040).sum_lines(57, 58, 59, '60a','60b', 62)
    line['11A'] = sum_lines('8A', '9A', '10A')

    line['12A'] = form(1040).sum_lines(64, 71)
    line['13A'] = form(1040).line(65)
    line['14A'] = form(1040).line('66a')
    line['15A'] = form(1040).sum_lines(67, 68, 69, 72, 73)


  end

end


