require 'tax_form'
require 'date'

class FormFP31 < TaxForm

  NAME = 'FP-31'

  def compute

    bio = form('Partnership')
    copy_line(:ein, bio)
    line[:if_ein] = 'X'
    copy_line(:name, bio)
    copy_line(:address, bio)
    if bio.line[:address2] =~ /^(.*), ([A-Z]{2}) (\d{5})$/
      line[:city], line[:state], line[:zip] = $1, $2, $3
    end

    line[:cost_225k_or_less] = ''

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

    sched = @manager.compute_form('FP-31 Schedules A through D-2')
    line['1.A'] = sched.line['_A4.reference']
    line['1.B'] = sched.line['_A6.reference']
    line['2.A'] = sched.line['_A4.fixed']
    line['2.B'] = sched.line['_A6.fixed']
    line['3.A'] = sched.line['_A4.other']
    line['3.B'] = sched.line['_A6.other']
    line['4.A'] = sched.line['B.total']
    line['4.B'] = line['4.A']
    line[5] = sum_lines('1.A', '2.A', '3.A', '4.A')
    line[6] = sum_lines('1.B', '2.B', '3.B', '4.B')
    line7 = 225_000
    if line[6] > line7
      raise 'Tax not implemented'
    end

    line[:cost_225k_or_less, :overwrite] = 'X'
    line[8] = 0

  end
end

class FormFP31ABCD1D2 < TaxForm
  def name
    "FP-31 Schedules A through D-2"
  end

  def compute
    type_totals_4 = {
      'reference' => 0.0,
      'fixed' => 0.0,
      'other' => 0.0
    }
    type_totals_6 = {
      'reference' => 0.0,
      'fixed' => 0.0,
      'other' => 0.0
    }

    cutoff_date = Date.new(Date.today.year, 6, 30)

    line[:name] = form('FP-31').line[:name]
    line[:tin] = form('FP-31').line[:ein]

    forms('Asset').each do |asset|
      line[:A1, :add] = asset.line[:description]
      date = Date.strptime(asset.line(:date), '%m/%d/%y')
      line[:A2, :add] = date.strftime('%m/%Y')
      dep_rate = DEPRECIATION_RATE[asset.line(:dc_category)]
      line[:A3, :add] = "%.1f%%" % (dep_rate * 100)
      line[:A4, :add] = asset.line[:amount]
      type_totals_4[asset.line(:dc_type)] += asset.line[:amount]

      dep_frac = dep_rate * age_in_years(date, cutoff_date)
      dep_frac = [ dep_frac, asset.line(:dc_category) == 'E' ? 0.9 : 0.75 ].min
      acc_dep = line[:A5, :add] = (dep_frac * asset.line[:amount]).round(2)
      remaining = line[:A6, :add] = (asset.line[:amount] - acc_dep).round(2)
      type_totals_6[asset.line(:dc_type)] += remaining
    end

    line['A4.total'] = line(:A4, :sum).round
    line['A6.total'] = line(:A6, :sum).round
    %w(reference fixed other).each do |type|
      line["_A4.#{type}"] = type_totals_4[type].round
      line["_A6.#{type}"] = type_totals_6[type].round
    end

    # assert_question('Do you have any office supplies?', false)
    #
    # I don't understand why I made the above assertion, so I need to look into
    # this next year
    #
    raise "Review office supplies issue here"
    line['B.total'] = 0
  end

  def age_in_years(earlier, later)
    earlier, later = later, earlier if earlier > later
    years = later.year - earlier.year
    days = later.yday - earlier.yday
    return years + (days / 365.0)
  end

  DEPRECIATION_RATE = {
    'A' => 0.067,
    'B' => 0.1,
    'C' => 0.125,
    'D' => 0.2,
    'E' => 0.3,
    'F' => 0.5,
    'G' => 0.0
  }

end
