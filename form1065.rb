require 'tax_form'

class Form1065 < TaxForm

  def name
    '1065'
  end

  def compute
    line['1a'] = forms('1099-MISC').lines(7, :sum)
    line['1c'] = line['1a'] - line['1b', :opt]
    line[3] = line['1c'] - line[2, :opt]
    line[8] = sum_lines(3, 4, 5, 6, 7)

    deductions = 0
    form('Deductions').line.each do |l, v|
      deductions += v
    end
    line[20] = deductions
    line[21] = sum_lines(9, 10, 11, 12, 13, 14, 15, '16c', 17, 18, 19, 20)
    line[22] = line[8] - line[21]

    line['K1'] = line[22]
    line['K14a'] = line['K1']

    line['Analysis.1'] = sum_lines(*%w(K1 K2 K3c K4 K5 K6a K7 K8 K9a K10 K11)) \
      - sum_lines(*%w(12 13a 13b 13c2 13d 16l))

    line['Analysis.2a(ii)'] = line['Analysis.1']
  end
end

