require 'tax_form'

class Form8960 < TaxForm

  def name
    '8960'
  end

  def compute
    line[1] = form(1040).line['8a']
    line[2] = form(1040).line['9a']

    assert_no_forms('1099-R')

    line['4a'] = form(1040).line[17]
    with_form('1040 Schedule E') do |f|
      line4b = f.line('29a.j', :opt)
      if line4b != 0
        assert_question('Were your partnership activities a section 162 ' + \
                        'trade or business but not trading financial ' + \
                        'instruments or commodities?', true)
        line['4b'] = -line4b
      end
    end
    line['4c'] = line['4a'] + line['4b']

    line['5a'] = form(1040).sum_lines(13, 14)
    line['5d'] = sum_lines('5a', '5b', '5c')

    line[8] = sum_lines(1, 2, 3, '4c', '5d', 6, 7)

    with_form('1040 Schedule A') do |f|
      line['9a'] = f.line[14, :opt]
      line['9b'] = (f.line[5] * line[8] / form(1040).line[38]).round
      assert_no_forms(4952)
      line['9d'] = sum_lines('9a', '9b', '9c')
    end

    line[11] = sum_lines('9d', 10)

    line[12] = [ 0, line[8] - line[11] ].max
    line[13] = form(1040).line[38]

    line[14] = form(1040).status.niit_threshold

    line[15] = [ 0, line[13] - line[14] ].max

    line[16] = [ line[12], line[15] ].min
    line[17] = (line[16] * 0.038).round

  end
end
