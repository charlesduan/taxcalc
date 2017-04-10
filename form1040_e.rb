class Form1040E < TaxForm
  def calculate
    k1s = forms('1065 Schedule K-1')
    assert_interview('What is your answer to Schedule E, line 27?', false)

    line['27.no'] = 'X'
    line['28a', :all] = k1s.lines['B']
    line['28b', :all] = k1s.map { |x| 'P' }
    assert_interview('Are any of your partnerships foreign?', false)
    line['28d', :all] = k1s.lines['A']

    if k1s.lines[1].any? { |x| x < 0 }
      raise 'Partnership losses not implemented'
    end

    assert_interview('Were you active in all your partnerships?', true)

    assert_no_lines('1065 Schedule K-1', 12)

    line['28j', :all] = k1s.lines[1]

    line['29a.j'] = line['28j', :sum]
    line[30] = sum_lines('29a.g', '29a.j')
    line[31] = sum_lines('29b.f', '29b.h', '29b.i')
    line[32] = line[30] - line[31]

    line[41] = sum_lines(26, 32, 37, 39, 40)
  end
end

