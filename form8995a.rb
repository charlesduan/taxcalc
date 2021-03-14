require 'tax_form'

# Qualified business income deduction, high-income form
class Form8995A < TaxForm
  NAME = '8995-A'

  def year
    2019
  end

  def compute
    set_name_ssn

    raise "Not implemented"
  end

end


