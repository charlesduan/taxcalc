require 'tax_form'

#
# Computes deductions from a table of business expenses. This implements parts
# of Publication 535, under Other Expenses.
#

class Deductions < TaxForm
  def name
    'Deductions'
  end

  def compute
    exps = forms('Business Expense')

    deds = {}
    exps.each do |exp|
      cat = exp.line['category']
      deds[cat] ||= 0.0
      deds[cat] += exp.line['amount']
    end

    %w(Meals Utilities).each do |half_cat|
      deds[half_cat] /= 2 if deds[half_cat]
    end

    total = 0.0
    deds.keys.sort.each do |cat|
      deds[cat] = deds[cat].round(2)
      line[cat] = deds[cat]
      total += deds[cat]
    end

    line[:fill!] = total.round
  end
end

