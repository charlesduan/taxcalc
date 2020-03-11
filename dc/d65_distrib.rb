require 'tax_form'

class D65PassThroughDistribution < TaxForm
  def name
    'Schedule of Pass-Through Distribution of Income'
  end

  def year
    2019
  end

  def compute
    k1s = forms('1065 Schedule K-1')
    line[:Partner, :all] = k1s.lines(:F, :all)
    line[:Amount, :all] = k1s.lines(1, :all)
    sum = k1s.lines(1, :sum)
    line[:Percent, :all] = line[:Amount, :all].map { |x|
      (x * 100.0 / sum).round(1)
    }
  end

end
