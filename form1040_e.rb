require 'form4562'
require 'home_office'

class Form1040E < TaxForm

  def name
    '1040 Schedule E'
  end

  include HomeOfficeManager

  def compute
    line[:name] = form(1040).full_name
    line[:ssn] = form(1040).ssn

    k1s = forms('1065 Schedule K-1')
    assert_question(
      'Do you have prior year unallowed losses for Schedule E?', false
    )
    assert_question(
      'Do you have unreimbursed partnership expenses (other than home office)?',
      false
    )

    ho_upes = {}
    home_office_partnership do |ho_form, entry|
      ho_upes[ho_form.line[:ein]] = entry
    end
    if ho_upes.empty?
      line['27.no'] = 'X'
    else
      line['27.yes'] = 'X'
    end

    assert_question('Are any of your partnerships foreign?', false)
    assert_question('Were you active in all your partnerships?', true)

    @manager.compute_form(Form4562)

    k1s.each do |k1|
      raise 'Partnership losses not implemented' if k1.line[1] < 0
      pship_name = k1.line[:B].split("\n")[0]
      f4562 = forms(4562).find { |x| x.line[:business] == pship_name }

      add_table_row(
        '28a' => pship_name,
        '28b' => 'P',
        '28d' => k1.line[:A],
        '28i' => f4562.line[12],
        '28j' => k1.line[1]
      )
    end

    ho_upes.each do |ein, deduction|
      add_table_row(
        '28a' => "UPE (#{ein})",
        '28h' => deduction
      )
    end

    line['29a.g'] = line['28g', :sum]
    line['29a.j'] = line['28j', :sum]
    line['29b.f'] = line['28f', :sum]
    line['29b.h'] = line['28h', :sum]
    line['29b.i'] = line['28i', :sum]

    line[30] = sum_lines('29a.g', '29a.j')
    line[31] = sum_lines('29b.f', '29b.h', '29b.i')
    line[32] = line[30] - line[31]

    line[41] = sum_lines(26, 32, 37, 39, 40)
  end
end

