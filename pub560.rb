require 'tax_form'

class Pub560Worksheet < TaxForm

  NAME = "Pub. 560 Deduction Worksheet"

  def year
    2022
  end

  def initialize(profit)
    @profit = profit
  end

  def compute
    line[1] = @profit
  end

end
