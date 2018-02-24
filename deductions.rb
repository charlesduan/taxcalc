require 'tax_form'

#
# Computes deductions from a table of business expenses.
#

class Deductions < TaxForm
  def name
    'Deductions'
  end

  def compute
    exp = form('Business Expenses')

    deds = {}
    exp.line('category', :all).zip(exp.line('amount', :all)).each do |cat, amt|
      deds[cat] = (deds[cat] || 0.0) + amt
    end

    %w(Meals Utilities).each do |half_cat|
      deds[half_cat] /= 2 if deds[half_cat]
    end

    total = 0.0
    deds.keys.sort.each do |cat|
      line[cat] = deds[cat]
      total += deds[cat]
    end

    line['fill'] = total.round
  end
end

