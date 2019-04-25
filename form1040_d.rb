require 'tax_form'
require 'form8949'

class Form1040D < TaxForm
  def name
    '1040 Schedule D'
  end

  def year
    2018
  end

  def needed?
    has_form?(8949) or line[7] != 0 or line[15] != 0 or line[16] != 0
  end

  def compute
    Form8949.generate(@manager) unless has_form?(8949)

    forms_a = forms(8949) { |f| f.has_line('A') }
    if forms_a.empty?
      line['1b.h'] = BlankZero
    else
      line['1b.d'] = forms_a.lines('I.2d', :sum)
      line['1b.e'] = forms_a.lines('I.2e', :sum)
      line['1b.h'] = forms_a.lines('I.2h', :sum)
    end

    forms_b = forms(8949) { |f| f.has_line('B') }
    if forms_b.empty?
      line['2h'] = BlankZero
    else
      line['2d'] = forms_b.lines('I.2d', :sum)
      line['2e'] = forms_b.lines('I.2e', :sum)
      line['2h'] = forms_b.lines('I.2h', :sum)
    end

    # Assume there are none of these:
    # Form 6252: Installment sales
    # Form 4684: Casualties and thefts
    # Form 6781: Section 1251 contracts (non-equity options, futures contracts)
    # Form 8824: Like-kind exchanges of real property
    # Form 4797: Sale of business property
    # Form 2439: RIC or REIT undistributed capital gains

    line[5] = forms('1065 Schedule K-1').lines(8, :sum)

    if @manager.submanager(:last_year).has_form?('1040 Schedule D')
      last_d = @manager.submanager(:last_year).has_form?('1040 Schedule D')
      if last_d.line[21, :present]
        raise "Capital Loss Carryover not implemented"
      end
    end

    line[7] = line['1b.h'] + line['2h']

    forms_d = forms(8949) { |f| f.has_line('D') }
    if forms_d.empty?
      line['8b.h'] = BlankZero
    else
      line['8b.d'] = forms_d.lines('II.2d', :sum)
      line['8b.e'] = forms_d.lines('II.2e', :sum)
      line['8b.h'] = forms_d.lines('II.2h', :sum)
    end

    forms_e = forms(8949) { |f| f.has_line('E') }
    if forms_e.empty?
      line['9h'] = BlankZero
    else
      line['9d'] = forms_e.lines('II.2d', :sum)
      line['9e'] = forms_e.lines('II.2e', :sum)
      line['9h'] = forms_e.lines('II.2h', :sum)
    end

    line[12] = forms('1065 Schedule K-1').lines('9a', :sum)

    assert_no_lines('1099-DIV', '2a', '2b', '2c', '2d')
    line[15] = line['8b.h'] + line['9h']

    line[16] = line[7] + line[15]

    if line[16] > 0
      line[:fill!] = line[16]
      if line[15] > 0
        line['17yes'] = 'X'
        assert_form_unnecessary('Schedule D 28% Rate Gain Worksheet')
        assert_form_unnecessary('Schedule D Section 1250 Gain Worksheet')

        line['20yes'] = 'X'
        return
      else
        line['17no'] = 'X'
      end
        
    elsif line[16] < 0
      raise 'Not implemented'

    else # line[16] == 0
      line[:fill!] = 0

    end

    if forms('1099-DIV').lines('1b', :sum) > 0
      line['22yes'] = 'X'
    else
      line['22no'] = 'X'
    end

  end
end
