require 'tax_form'

class Form7004 < TaxForm

  NAME = '7004'
  def year
    2022
  end

  def compute
    f1065 = form(1065)
    copy_line(:name, f1065)
    copy_line(:ein, f1065)
    copy_line(:address, f1065)
    copy_line(:city_zip, f1065)

    line[1] = '09'
    line['5a'] = year.to_s[2..3]

  end

end
