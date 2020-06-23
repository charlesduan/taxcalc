require 'tax_form'

#
# Noncash charitable contributions
#
class Form8283 < TaxForm

  def name
    '8283'
  end

  def year
    2019
  end

  def compute
    set_name

    gifts = forms('Charity Gift') { |f| !f.cash? }.each do |g|
      raise "Donations over $5000 not implemented" if g.line[:amount] > 5000

      res = { '1a' => g.line[:name] }
      if g.line[:vin, :present]
        res['1b.box'] = 'X'
        res['1b.vin'] = g.line[:vin]
      end
      res['1c'] = g.line[:description]
      res['1d'] = g.line[:date]
      if g.line[:amount] > 500
        res['1e'] = g.line[:date_acq]
        res['1f'] = g.line[:how_acq]
        res['1g'] = g.line[:basis]
      end
      res['1h'] = g.line[:amount]
      res['1i'] = g.line[:method]

      add_table_row(res)
    end

  end

end
