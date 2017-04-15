require 'tax_form'

class Form1040B < TaxForm

  def name
    '1040 Schedule B'
  end

  def compute
    line['1l', :all] = forms('1099-INT').lines('name')
    line['1r', :all] = forms('1099-INT').lines(1)
    line[2] = line['1r', :sum]
    line[3] = form_line_or(8815, -1, 0)
    line[4] = line[2] - line[3]

    line['5l', :all] = forms('1099-DIV').lines('name')
    line['5r', :all] = forms('1099-DIV').lines('1a')
    line[6] = line['5r', :sum]

    if line[4] > 1500 or line[6] > 1500
      raise 'Schedule B Part III not implemented'
    end

    return self
  end
end
