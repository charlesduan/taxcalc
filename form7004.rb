require 'tax_form'

#
# Partnership return extension of time.
#

class Form7004 < TaxForm

  NAME = '7004'
  def year
    2023
  end

  def compute
    bio = form('Partnership')
    copy_line(:name, bio)
    copy_line(:ein, bio)
    copy_line(:address, bio)
    copy_line(:city_zip, bio)

    line[1] = '09'
    line['5a'] = year.to_s[2..3]

  end

end
