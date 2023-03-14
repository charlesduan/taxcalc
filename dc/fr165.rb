require 'tax_form'

class FormFR165 < TaxForm

  NAME = 'FR-165'

  def year
    2022
  end

  def compute

    d65 = form('D-65')

    copy_line(:ein, d65)
    copy_line(:tax_period, d65)
    copy_line(:business_name, d65)
    if d65.line(:address2, :present)
      line[:address] = d65.line[:address] + ' ' + d65.line[:address2]
    else
      copy_line(:address, d65)
    end
    copy_line(:city, d65)
    copy_line(:state, d65)
    copy_line(:zip, d65)

    line[:extension_month] = 'Oct.'

  end
end
