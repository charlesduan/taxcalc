require 'tax_form'

class FormD2210 < TaxForm
  def name
    'D-2210'
  end

  def compute
    d40 = form('D-40')
    line[1] = d40.line[26]
    line[2] = (line[1] * 0.9).round
    line[3] = (interview('Enter your last year\'s taxes:') * 1.1).round
    line[4] = [ line[2], line[3] ].min
    line[5] = (0.25 * line[4]).round

    line[6, :all] = [ line[5], line[5] * 2, line[5] * 3, line[4] ]
    payments = d40.sum_lines(30, 31)
    qp = (payments * 0.25).round
    line[7, :all] = [ qp, qp * 2, qp * 3, payments ]
    line[8, :all] = line[6, :all].zip(line[7, :all]).map { |l6, l7| l6 - l7 }
    line[9, :all] = [ 0.0175, 0.0265, 0.0351, 0.0259 ]
    line[10, :all] = line[8, :all].zip(line[9, :all]).map { |l8, l9|
      (l8 * l9).round
    }
    line[11] = line[10, :sum]
  end

end
