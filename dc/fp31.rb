require 'tax_form'
require 'date'

class FormFP31 < TaxForm

  NAME = 'FP-31'

  #
  # This year should be one less than the filing year on the FP-31 form. This is
  # because the form's year is the end of the reporting period, but the form is
  # due at the beginning of the reporting period.
  #
  def year
    2024
  end

  def compute

    bio = form('Partnership')
    copy_line(:ein, bio)
    copy_line(:name, bio)

    if false
      # This doesn't matter for the web form
      line[:if_ein] = 'X'
      copy_line(:address, bio)
      if bio.line[:address2] =~ /^(.*), ([A-Z]{2}) (\d{5})$/
        line[:city], line[:state], line[:zip] = $1, $2, $3
      end
    end

    asset_mgr = compute_form(DCAssetManager)

    line[:cost_225k_or_less] = 'X' if asset_mgr.total_costs <= 225_000

    if false
      # This also doesn't matter for the web form
      line[:A] = bio.line[:business]
      line[:B] = interview('Number of DC locations:')
      confirm("This business is not a hotel or motel")
      confirm("This business does not lease personal property")
      line[:D_no] = 'X'
      confirm("This business is not a qualified high-tech company")
      line[:E_no] = 'X'
      line[:F_no] = 'X' # by virtue of D's question
      confirm("Other companies do not do business from this address")
      line[:G_no] = "X"
      line[:name_p2] = line[:name]
      line[:ein_p2] = line[:ein]
    end

    line['1a'], line['1b'] = asset_mgr.costs_for_type('reference')
    line['2a'], line['2b'] = asset_mgr.costs_for_type('fixed')
    line['3a'], line['3b'] = asset_mgr.costs_for_type('other')

    # Supplies have no distinct original cost
    line['4a'] = line['4b'] = asset_mgr.costs_for_type('supplies').last

    line[5] = sum_lines(%w(1a 2a 3a 4a))
    line[6] = sum_lines(%w(1b 2b 3b 4b))
    line7 = 225_000
    if line[6] > line7
      raise 'Tax not implemented'
    end
    line[8] = 0

    compute_form(FormFP31ABCD1D2)

  end
end

class DCAssetManager < TaxForm

  NAME = "DC Asset Manager"

  def year
    2024
  end

  # The last date for which assets are relevant.
  def cutoff_date
    Date.new(year, 6, 30)
  end

  # Accumulates all the assets.
  def compute
    @assets = []
    @disposed_assets = []
    forms('Asset').each do |a|
      process_asset(a)
    end
    forms("Business Expense").each do |be|
      next unless be.line[:category] == 'Supplies'
      process_asset(be)
    end
  end

  def process_asset(a)
    asset = DCAsset.new(a, self)
    return if asset.date > cutoff_date
    if asset.disposed?
      puts "  Disposed"
      @disposed_assets.push(asset) if @asset.disposed_this_year?
    else
      @assets.push(asset)
    end
  end

  attr_reader :disposed_assets

  # Returns current assets associated with a type
  def assets_for_type(type)
    return @assets.select { |asset| asset.type == type }
  end

  # Returns the original and depreciated costs associated with a type
  def costs_for_type(type)
    assets = assets_for_type(type)
    return [
      assets.map(&:amount).sum,
      assets.map(&:remaining_amount).sum
    ]
  end

  # Returns the total depreciated costs of all current assets.
  def total_costs
    @assets.map(&:remaining_amount).sum
  end

  def total_original_costs
    @assets.map(&:amount).sum
  end

  DC_CATS = %w(A B C D E F G)
  DC_TYPES = %w(reference fixed supplies other)
  DEPRECIATION_RATE = {
    'A' => 0.067,
    'B' => 0.1,
    'C' => 0.125,
    'D' => 0.2,
    'E' => 0.3,
    'F' => 0.5,
    'G' => 0.0
  }

  class DCAsset

    def initialize(asset, mgr)
      @mgr = mgr
      @date = asset.line(:date)

      if asset.line[:dc_type, :present]
        @type = asset.line[:dc_type]
      elsif asset.line[:amount] <= 2500
        @type = 'supplies'
      end
      raise "Invalid asset type #{@type}" unless DC_TYPES.include?(@type)

      if asset.line[:dc_category, :present]
        @category = asset.line[:dc_category]
      else
        @category = 'B'
      end
      unless DC_CATS.include?(@category)
        raise "Invalid asset category #{@category}"
      end

      @asset = asset
    end

    attr_accessor :mgr, :date, :category, :type

    def amount
      return @asset.line[:amount]
    end

    def description
      return @asset.line[:description]
    end

    # Computes the age in years in comparison to the cutoff date.
    def age_in_years
      years = @mgr.cutoff_date.year - @date.year
      days = @mgr.cutoff_date.yday - @date.yday
      return years + (days / 365.0)
    end

    def depreciation_rate
      return DEPRECIATION_RATE[category]
    end

    def depreciation_frac
      return [
        depreciation_rate * age_in_years,
        @category == 'E' ? 0.9 : 0.75
      ].min
    end

    def accumulated_depreciation
      return (depreciation_frac * amount).round(2)
    end

    def remaining_amount
      return (amount - accumulated_depreciation).round(2)
    end

    def disposed?
      if @asset.line[:dc_disposition_date, :present]
        return false unless disposition_date.is_a?(Date)
        return false if disposition_date > @mgr.cutoff_date
      elsif type == 'supplies'
        #return true if date <= (@mgr.cutoff_date << 60)
        return false
      end
      return true
    end

    def disposition_date
       return @asset.line[:dc_disposition_date]
    end

    def disposition_method
      return @asset.line[:dc_disposition]
    end

    def disposed_this_year?
      return false if type == 'supplies' # Supplies never reported for disposition
      return false unless disposed?
      return false unless @disposition_date > (@mgr.cutoff_date << 12)
      return true
    end

  end

end


class FormFP31ABCD1D2 < TaxForm

  NAME = "FP-31 Schedules A through D-2"

  def year
    2024
  end

  def compute
    line[:name] = form('FP-31').line[:name]
    line[:tin] = form('FP-31').line[:ein]

    assets = form('DC Asset Manager')

    #
    # Add asset items to Schedule A
    #
    %w(reference fixed other).each do |type|
      assets.assets_for_type(type).each do |asset|
        add_table_row(
          'A1' => asset.description,
          'A2' => asset.date.strftime("%m/%Y"),
          'A3' => asset.category,
          'A4' => asset.amount,
          'A5' => asset.accumulated_depreciation,
          'A6' => asset.remaining_amount,
        )
      end
    end

    line['A4tot'] = line['A4', :sum] if line['A4', :present]
    line['A6tot'] = line['A6', :sum] if line['A6', :present]

    #
    # Supplies are listed in Schedule B. Any items originally bought for $2500
    # or less fall within the IRS section 1.263(a)-1(f) safe harbor, and are
    # reported as such.
    #
    safe_harbor_amt = 0
    assets.assets_for_type('supplies').each do |asset|
      if asset.amount > 2500
        add_table_row(
          'B.type' => asset.description,
          'B.cost' => asset.remaining_amount,
        )
      else
        safe_harbor_amt += asset.remaining_amount
      end
    end
    if safe_harbor_amt > 0
      add_table_row(
        'B.type' => 'Section 1.263(a)-1(f) safe harbor items',
        'B.cost' => safe_harbor_amt.round(2)
      )
    end

    line['B.total'] = line['B.cost', :sum] if line['B.cost', :present]

    # Enter disposed tangible items.
    assets.disposed_assets.each do |asset|
      add_table_row(
        'C1' => asset.description,
        'C2' => asset.date.strftime("%m/%Y"),
        'C3' => asset.amount,
        'C4' => asset.disposition_date.strftime("%m/%Y"),
        'C5' => asset.disposition_method,
      )
    end
  end

end
