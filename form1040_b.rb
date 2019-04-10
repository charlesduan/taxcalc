require 'tax_form'

class Form1040B < TaxForm

  def name
    '1040 Schedule B'
  end

  def year
    2017
  end

  def compute
    line[:name] = form(1040).full_name
    line[:ssn] = form(1040).ssn

    line['1l', :all] = forms('1099-INT').lines('name')
    line['1r', :all] = forms('1099-INT').lines(1)
    with_forms('1065 Schedule K-1') do |f|
      if f.line[5, :present]
        add_table_row('1l' => f.line[:B].split("\n")[0], '1r' => f.line[5])
      end
    end

    line[2] = line['1r', :sum]
    line[3] = form_line_or(8815, -1, 0)
    line[4] = line[2] - line[3]

    line['5l', :all] = forms('1099-DIV').lines('name')
    line['5r', :all] = forms('1099-DIV').lines('1a')
    with_forms('1065 Schedule K-1') do |f|
      if f.line['6a', :present]
        add_table_row('1l' => f.line[:B].split("\n")[0], '1r' => f.line['6a'])
      end
    end

    line[6] = line['5r', :sum]

    if line[4] > 1500 or line[6] > 1500
      raise 'Schedule B Part III not implemented'
    end

    return self
  end
end
