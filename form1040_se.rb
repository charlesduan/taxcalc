class Form1040SE < TaxForm

  def name
    '1040 Schedule SE'
  end

  def compute

    line[:name] = form('Biographical').line[:first_name] + ' ' + \
      form('Biographical').line[:last_name]
    line[:ssn] = form('Biographical').line[:ssn]

    line[2] = forms('1040 Schedule C').lines(31, :sum) + \
      forms('1065 Schedule K-1').lines(14, :sum)

    line[3] = sum_lines('1a', '1b', 2)

    line['4a'] = line[3] <= 0 ? line[3] : (line[3] * 0.9235).round

    line['4c'] = sum_lines('4a', '4b')
    if line['4c'] < 400
      line[12] = BlankZero
      line[13] = BlankZero
      return
    end

    line[6] = sum_lines('4c', '5b')
    line[7] = 127200

    line['8a'] = forms('W-2').lines(3, :sum) + forms('W-2').lines(7, :sum)
    line['8d'] = sum_lines('8a', '8b', '8c')

    l9 = line[7] - line['8d']
    if l9 <= 0
      line[9] = line[10] = 0
    else
      line[9] = l9
      line[10] = ([ line[6], line[9] ].min * 0.124).round
    end
    line[11] = (line[6] * 0.029).round
    line[12] = sum_lines(10, 11)
    line[13] = (line[12] * 0.5).round
  end

  def needed?
    return line['4c'] >= 400
  end

end
