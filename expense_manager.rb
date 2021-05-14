require 'tax_form'

#
# Computes deductions from a table of business expenses. This implements parts
# of Publication 535, under Other Expenses.
#

class ExpenseManager < TaxForm
  NAME = 'Business Expense Manager'

  def year
    2020
  end

  def compute
    exps = forms('Business Expense')

    # Arrange the business expenses into a hash, keyed by category.
    deds = {}
    exps.each do |exp|
      cat = exp.line['category']
      deds[cat] ||= 0.0
      deds[cat] += exp.line['amount']
    end

    # For each of these categories, the deduction value is divided by two.
    half_cats = %w(Meals Utilities)

    # 100% deduction for business meals in 2021 and 2022
    if year == 2021 or year == 2022
      half_cats.delete("Meals")
    end

    half_cats.each do |half_cat|
      deds[half_cat] /= 2 if deds[half_cat]
    end

    # Aggregate the total per category, and sum up for a grand total.
    total = 0.0
    deds.keys.sort.each do |cat|
      deds[cat] = deds[cat].round(2)
      line[cat] = deds[cat]
      total += deds[cat]
    end

    # Add in the safe harbor assets.
    @asset_manager = find_or_compute_form('Asset Manager')
    if @asset_manager.has_safe_harbor_expenses?
      line['Safe_Harbor'] = @asset_manager.safe_harbor_expense_total.round(2)
      total += line['Safe_Harbor']
    end

    line[:fill!] = total.round
  end

  def make_continuation(form, name = 'Table of Business Expenses')
    @con_form = NamedForm.new(name, @manager)
    @manager.add_form(@con_form)
    @con_form.exportable = true

    cats, amts = line.to_a.reject { |x| x[0] == 'fill!' }.transpose
    cats = cats.map { |c| present_name(c) }
    amts = amts.map { |a| a.round }
    @con_form.line['Type', :all] = cats
    @con_form.line['Amount', :all] = amts
    form.line[:continuation!] = name
  end

  CAT_NAMES = {
    'Meals' => 'Business Meals',
    'Licenses' => 'Taxes and Licenses',
    'Safe_Harbor' => '1.263(a)-1(f) Safe Harbor',
    'Rent_Equipment' => 'Rented Vehicles, Machinery, and Equipment',
    'Rent_Property' => 'Rented Business Property',
  }

  def present_name(cat)
    CAT_NAMES[cat] || cat
  end

end

