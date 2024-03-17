require 'tax_form'

# Education credits.
class Form8863 < TaxForm

  NAME = '8863'

  def year
    2023
  end

  def compute
    return unless needed?
    raise "Form not implemented"
  end

  def needed?
    s = form(1040).status
    return false if s.is?(:mfs)
    return false if form(1040).line(:agi) > s.double_mfj(90_000)
    return true
  end

end
