require 'tax_form'

class Form1040R < TaxForm

  def name
    '1040 Schedule R'
  end

  def year
    2019
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
