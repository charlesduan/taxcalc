require 'date'
require 'tax_form'
require 'filing_status'

class EstimatedTax < TaxForm

  def name
    'Estimated Tax'
  end

  def year
    2020
  end

  INCOME_TYPES = {
    'wage' => 1,
    'int' => '2b',
    'div' => '3b',
    'ira_distribution' => '4b',
    'pension' => '4d',
    'social_security' => '5b',
    'cap_gain' => 6,
    'other_inc' => '7a',
  }

  DEDUCTION_TYPES = {
    'adjustment' => '8a',
    'sched_a' => 'deduction',
    'qbid' => 'qbid',
  }

  def find_line(type, all_forms, types_map)
    lf = all_forms.select { |f| f.line_type == type }
    if lf.empty? || (lf.length == 1 && lf[0].line_amount == 'same')
      warn(
        "No #{type}; using last year's. " \
        "Enter 'same' to avoid this warning.\n"
      ) if lf.empty?
      return @manager.submanager(:last_year).form(1040).line(
        types_map[type], :opt
      )
    else
      return lf.lines(:amount, :sum)
    end
  end

  #
  # Computes all the income, deductions, etc.
  def compute_part(form_name, types_map)
    all_forms = forms(form_name)

    # Check that all form values are of the right type
    unless all_forms.all? { |x| types_map.include?(x.line_type) }
      wrong_types = all_forms.map { |x| x.line_type } - types_map.keys
      raise "Wrong type #{wrong_types.join(", ")} in Form #{form_name}"
    end

    # Compute each line
    types_map.each do |type, n|
      line[type] = find_line(type, all_forms, types_map)
    end

    # Sum the lines
    return sum_lines(*types_map.keys)
  end

  def compute_quarter
    Date.today
    return 1 if Date.today <= Date.new(year, 4, 15)
    return 2 if Date.today <= Date.new(year, 6, 15)
    return 3 if Date.today <= Date.new(year, 9, 15)
    return 4 if Date.today <= Date.new(year + 1, 1, 15)
    raise "Too late to make estimated payments"
  end

  #
  # Projects a number for the rest of the year based on the quarterly data. This
  # could be improved by allowing estimated values, but for now we just project
  # data by multiplying by the number of remaining quarters.
  #
  def project(value)
    return value * 4 / line[:quarter]
  end

  def compute

    line[:quarter] = compute_quarter

    #
    # Filing status is taken from last year's form. TODO: Allow user to choose a
    # different status
    #
    @status = FilingStatus.from_form(@manager.submanager(:last_year).form(1040))
    line[:status] = @status.name

    # First, simulate an approximate Form 1040.
    line[:total_income] = compute_part('Estimated Income', INCOME_TYPES)

    # Project income for the year.
    line[:projected_income] = project(line[:total_income])

    line[:total_deductions] = compute_part(
      'Estimated Deduction', DEDUCTION_TYPES
    )

    line[:taxable_income] = line[:projected_income] - line[:total_deductions]

    #
    # We're going to assume no capital gains/qualified dividends since those
    # will only reduce income, and for my purposes not so significantly as to
    # recommend estimating tax based on them.
    #
    line[:tax] = compute_tax_estimate(line[:taxable_income])

    # Self-employment tax estimation
    se_forms = forms('Estimated Income') { |x| x.line[:se?] }
    unless se_forms.empty?
      line[:se_income] = se_forms.lines(:amount, :sum)
      line[:se_projected_income] = project(line[:se_income])
      line[:ss_max] = 137_700
      line[:se_ss_taxable] = [
        [ line[:ss_max] - line[:wage], 0 ].max,
        line[:se_projected_income]
      ].min
      line[:se_ss_tax] = (0.124 * line[:se_ss_taxable]).round
      line[:se_tax] = (0.029 * line[:se_projected_income]).round
    end

    line[:total_tax] = sum_lines(:tax, :se_ss_tax, :se_tax)

    line[:withholding] = forms('Withholding').lines(:amount, :sum)
    line[:projected_withholding] = project(line[:withholding])
    line[:refund_applied] =
      @manager.submanager(:last_year).form(1040).line(22, :opt)

    line[:total_payments] = sum_lines(:projected_withholding, :refund_applied)
    line[:estimated_tax_paid] = forms('Estimated Tax').lines(:amount, :sum)

    if line[:total_tax] > line[:total_payments] + line[:estimated_tax_paid]

      # We use the IRS formula from Pub. 505, Worksheet 2-10
      line[:estimated_liability] = line[:total_tax] - line[:total_payments]
      quarter_frac = line[:quarter] * 0.25
      line[:estimated_tax] =
        (line[:estimated_liability] * quarter_frac).round -
        line[:estimated_tax_paid]

    else
      line[:estimated_tax] = 0
    end
  end

  def compute_tax_estimate(amount)
    @status.estimated_tax_brackets.each do |b|
      next unless b[0].nil? || b[0] >= amount
      return round(b[1] + b[2] * (amount - b[3]))
    end
    raise "Should never reach here"
  end

end

#
# The following can be generated with util/parse_505.rb
#

FilingStatus.set_param(
  :estimated_tax_brackets,
  [ # single
    [9875, 0, 0.1, 0],
    [40125, 987.5, 0.12, 9875],
    [85525, 4617.5, 0.22, 40125],
    [163300, 14605.5, 0.24, 85525],
    [207350, 33271.5, 0.32, 163300],
    [518400, 47367.5, 0.35, 207350],
    [nil, 156235.0, 0.37, 518400],
  ],
  [ # mfj
    [19750, 0, 0.1, 0],
    [80250, 1975.0, 0.12, 19750],
    [171050, 9235.0, 0.22, 80250],
    [326600, 29211.0, 0.24, 171050],
    [414700, 66543.0, 0.32, 326600],
    [622050, 94735.0, 0.35, 414700],
    [nil, 167307.5, 0.37, 622050],
  ],
  [ # mfs
    [9875, 0, 0.1, 0],
    [40125, 987.5, 0.12, 9875],
    [85525, 4617.5, 0.22, 40125],
    [163300, 14605.5, 0.24, 85525],
    [207350, 33271.5, 0.32, 163300],
    [311025, 47367.5, 0.35, 207350],
    [nil, 83653.75, 0.37, 311025],
  ],
  [ # hoh
    [14100, 0, 0.1, 0],
    [53700, 1410.0, 0.12, 14100],
    [85500, 6162.0, 0.22, 53700],
    [163300, 13158.0, 0.24, 85500],
    [207350, 31830.0, 0.32, 163300],
    [518400, 45926.0, 0.35, 207350],
    [nil, 154793.5, 0.37, 518400],
  ],
  [ # qw
    [19750, 0, 0.1, 0],
    [80250, 1975.0, 0.12, 19750],
    [171050, 9235.0, 0.22, 80250],
    [326600, 29211.0, 0.24, 171050],
    [414700, 66543.0, 0.32, 326600],
    [622050, 94735.0, 0.35, 414700],
    [nil, 167307.5, 0.37, 622050],
  ],
)
