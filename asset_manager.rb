#
# Helps with allocating assets among different forms of deduction etc.
#
require 'tax_form'

class AssetManager < TaxForm

  # The threshold under IRS Regulation 1.263(a)-1(f), which was updated in
  # Notice 2015-82. Look for "Tangible Property Regulations."
  SAFE_HARBOR_THRESHOLD = 2500

  def name
    'Asset Manager'
  end

  def year
    2019
  end

  def compute

    @assets = forms('Asset')
    @current_assets = @assets.select { |x|
      x.line_date.year == year
    }
    if @current_assets.any? { |x| x.line[:amount] <= SAFE_HARBOR_THRESHOLD }
      line[:expense_safe_harbor?] = interview(
        'Do you elect to apply the safe harbor to deduct business assets?'
      )
      if line[:expense_safe_harbor?]
        @expensed_assets, @current_assets = @current_assets.partition { |x|
          x.line[:amount] <= SAFE_HARBOR_THRESHOLD
        }
      end
    end

  end

  def assets_179_nonlisted
    if @current_assets.any? { |x| x.line['listed?'] }
      raise "No support for listed property"
    end
    @current_assets.select { |x| x.line['179?'] }
  end

  def has_current_assets?
    !@current_assets.empty?
  end

  def has_safe_harbor_expenses?
    !@expensed_assets.nil?
  end

  def safe_harbor_expense_total
    @expensed_assets.sum { |x| x.line[:amount] }
  end

  def attach_safe_harbor_election(form)
    if has_safe_harbor_expenses?
      address = case
                when has_form?(1065)
                  form(1065).line[:address] + ", " + form(1065).line[:city_zip]
                when has_form(1040)
                  form(1040).line[:home_address] + ", " + \
                    form(1040).line[:city_zip]
                end
      form.line[:safe_harbor_explanation!, :all] = [
        'Section 1.263(a)-1(f) de minimis safe harbor election',
        'This return is making an election to use the de minimis safe harbor ',
        'under section 1.263(a)-1(f). The information of the entity making ',
        'the election is as follows:',
        '.PP',
        'Name: see above',
        '.PP',
        "Address: #{address}",
        '.PP',
        'TIN: see above',
      ]
    end
  end
end
