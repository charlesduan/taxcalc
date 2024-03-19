require 'tax_form'

class Form1040R < TaxForm

  NAME = '1040 Schedule R'

  def year
    2023
  end

  def compute
    if needed?
      raise "Schedule R not implemented"
    end
  end

  def needed?
    forms('Biographical').any? { |f|
      age(f) >= 65
    }
  end
end
