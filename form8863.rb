require 'tax_form'

# Education credits.
class Form8863 < TaxForm

  NAME = '8863'

  def year
    2020
  end

  def compute
    if form(1040).status.is('mfs')
      line[:na] = 'X'
      return
    end
    raise "Form not implemented"
  end

  def needed?
    !line[:na, :present]
  end

end
