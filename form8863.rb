require 'tax_form'

# Education credits.
class Form8863 < TaxForm

  def name
    '8863'
  end

  def year
    2019
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
