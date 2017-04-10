require 'tax_form'

class Form1040D < TaxForm
  def name
    '1040 Schedule D'
  end

  def compute
    forms_a = forms(8949).select { |f| f.has_line('A') }
    if forms_a.empty?
      line['1b.h'] = BlankZero
    else
      line['1b.d'] = forms_a.lines('I.2d', :sum)
      line['1b.e'] = forms_a.lines('I.2e', :sum)
      line['1b.h'] = forms_a.lines('I.2h', :sum)
    end

    forms_b = forms(8949).select { |f| f.has_line('B') }
    if forms_b.empty?
      line['2h'] = BlankZero
    else
      line['2d'] = forms_b.lines('I.2d', :sum)
      line['2e'] = forms_b.lines('I.2e', :sum)
      line['2h'] = forms_b.lines('I.2h', :sum)
    end

    assert_no_forms(6252, 4684, 6781, 8824, 'Schedule K-1')

    assert_no_forms('Capital Loss Carryover Worksheet')

    line[7] = line['1b.h'] + line['2h']

    forms_d = forms(8949).select { |f| f.has_line('D') }
    if forms_d.empty?
      line['8b.h'] = BlankZero
    else
      p forms_d.lines['II.2d', :sum]
      line['8b.d'] = forms_d.lines('II.2d', :sum)
      line['8b.e'] = forms_d.lines('II.2e', :sum)
      line['8b.h'] = forms_d.lines('II.2h', :sum)
    end

    forms_e = forms(8949).select { |f| f.has_line('E') }
    if forms_e.empty?
      line['9h'] = BlankZero
    else
      line['9d'] = forms_e.lines('II.2d', :sum)
      line['9e'] = forms_e.lines('II.2e', :sum)
      line['9h'] = forms_e.lines('II.2h', :sum)
    end

    assert_no_forms(4797, 2439, 6252, 4684, 6781, 8824, 'Schedule K-1')
    assert_no_lines('1099-DIV', '2a', '2b', '2c', '2d')
    assert_no_forms('Capital Loss Carryover Worksheet')
    line[15] = line['8b.h'] + line['9h']

    line[16] = line[7] + line[15]

    if line[16] > 0
      if line[15] > 0
        line['17yes'] = 'X'
        assert_form_unnecessary('Schedule D 28% Rate Gain Worksheet')
        assert_form_unnecessary('Schedule D Section 1250 Gain Worksheet')

        line['20yes'] = 'X'
      else
        raise 'Not implemented'
      end
        
    else
      raise 'Not implemented'
    end

  end
end
