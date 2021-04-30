require 'form4562'
require 'home_office'

class Form1040E < TaxForm

  NAME = '1040 Schedule E'

  def year
    2019
  end

  include HomeOfficeManager

  def compute
    set_name_ssn

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

    compute_form(4562)

    k1s.each do |k1|
      raise 'Partnership losses not implemented' if k1.line[1] < 0
      pship_name = k1.line[:B].split("\n")[0]
      res = {
        '28a' => pship_name,
        '28b' => 'P',
        '28d' => k1.line[:A],
      }
      if k1.line[1] < 0
        res['28i'] = -k1.line[1];
      end
      f4562 = forms(4562).find { |x| x.line[:business] == pship_name }
      res['28j'] = f4562.line[12] if f4562
      if k1.line[1] > 0
        res['28k'] = k1.line[1];
      end
      add_table_row(res)
    end

    ho_upes.each do |ein, deduction|
      add_table_row(
        '28a' => "UPE (#{ein})",
        '28i' => deduction
      )
    end

    line['29a.h'] = line['28h', :sum]
    line['29a.k/pship_nonpassive_inc'] = line['28k', :sum]
    line['29b.g'] = line['28g', :sum]
    line['29b.i/pship_nonpassive_loss'] = line['28i', :sum]
    line['29b.j/pship_179_ded'] = line['28j', :sum]

    line[30] = sum_lines('29a.h', '29a.k')
    line[31] = sum_lines('29b.g', '29b.i', '29b.j')
    line[32] = line[30] - line[31]

    line['41/tot_inc'] = sum_lines(26, 32, 37, 39, 40)
  end
end

