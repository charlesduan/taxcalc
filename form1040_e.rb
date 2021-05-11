require_relative 'form4562'
require_relative 'home_office'

#
# Supplemental Income and Loss: rental real eastate, royalties, partnerships,
# etc.
#
class Form1040E < TaxForm

  NAME = '1040 Schedule E'

  def year
    2020
  end

  include HomeOfficeManager

  def compute
    set_name_ssn

    k1s = forms('1065 Schedule K-1')
    #
    # At the time the partnership experiences a loss, it will be necessary to
    # implement the loss limitations. At that time, the rules for applying prior
    # year disallowed losses to the current year should be implemented here.
    #

    upes = []
    forms("Unreimbursed Partnership Expense").each do |f|
      l = f.line[:passive?] ? '28i' : '28g'
      upes.push(
        '28a' => "UPE (#{f.line[:ein]})",
        l => f.line[:amount],
      )
    end

    home_office_partnership do |ho_form, deduction|
      upes.push(
        '28a' => "UPE (#{ho_form.line[:ein]})",
        '28i' => deduction,
      )
    end
    if upes.empty?
      line['27.no'] = 'X'
    else
      line['27.yes'] = 'X'
    end

    assert_question('Are any of your partnerships foreign?', false)
    assert_question('Were you active in all your partnerships?', true)

    find_or_compute_form('Asset Manager') do |f|
      compute_form(4562) if f.line[:needs_4562?]
    end

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
      if has_form?(4562)
        f4562 = forms(4562).find { |x| x.line[:business] == pship_name }
        res['28j'] = f4562.line[12] if f4562
      end
      if k1.line[1] > 0
        res['28k'] = k1.line[1];
      end
      add_table_row(res)
    end

    upes.each do |row| add_table_row(row) end

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

