require 'tax_form'

class FormFR165 < TaxForm

  NAME = 'FR-165'

  def year
    2023
  end

  def compute

    bio = form('Partnership')

    copy_line(:ein, bio)
    line[:tax_period] = "1231#{year}"
    copy_line(:name, bio)
    copy_line(:address, bio)
    csz = bio.line[:city_zip]
    if csz =~ /,? ([A-Z][A-Z]) (\d{5}(?:-\d{4})?)$/
      line[:city] = $`
      line[:state] = $1
      line[:zip] = $2
    else
      raise "Could not parse city, state, zip"
    end

    line[:extension_month] = 'Oct.'

  end
end
