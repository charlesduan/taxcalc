require 'tax_form'
require 'filing_status'
require 'pub590b'
require 'form8606'
require 'pub590a_1_1'
require 'pub590a_1_2'

#
# Computes 1040 information relating to IRA distributions and contributions.
#
# The methods of this meta-form are invoked at two points in the 1040
# computation. First, the compute method is called at 1040 line 15, to compute
# just the IRA distributions. Second, the compute_contributions method is called
# at 1040 line 32, to compute any IRA deduction.
#
# TODO: The aforementioned method of computation may not be the best; it may be
# preferable to complete all computations initially, breaking into the three
# separate situations of (1) distributions only, (2) contributions only, and (3)
# contributions and distributions in one year. This appears to be how the IRS
# proposes to do it in Pub. 590-B.
#
class IraAnalysis < TaxForm

  def name
    'IRA Analysis'
  end

  def year
    2019
  end

  attr_reader :form8606, :pub590a_w1_1, :pub590a_w1_2, :pub590b_w1_1

  #
  # Computes distributions only; contributions are computed later.
  #
  def compute

    assert_question(
      'Did you have a qualified disaster distribution (Form 8915)?', false
    )

    # In all cases, set :this_year_contrib first
    contrib = forms('Traditional IRA Contribution').lines(:amount, :sum)
    line[:this_year_contrib] = contrib

    all_1099rs = forms('1099-R')
    if all_1099rs.any? { |x| !x.line['ira-sep-simple?'] }
      raise "Non-IRA 1099-R forms not implemented"
    end

    # Since we're only computing distributions, quit if there weren't any
    return if all_1099rs.empty?

    #
    # The destination could also be a traditional-to-traditional rollover, a
    # Roth-to-Roth rollover, a qualified charitable distribution, an HSA funding
    # distribution, or cash. The "destination" field in Form 1099-R should
    # reflect these. To implement any other destinations for an IRA
    # distribution, see the 1040 line 4a instructions.
    #
    if all_1099rs.any? { |x| x.line['destination'] != 'Roth conversion' }
      raise "Cannot handle 1099-R distributions that are not Roth conversions"
    end
    line[:roth_conversion] = all_1099rs.select { |x|
      x.line[:destination] == 'Roth conversion'
    }.lines(1, :sum)

    # The next line is not confirmed to be correct yet; currently it should
    # always be zero
    line[:cash_distribution] = all_1099rs.select { |x|
      x.line[:destination] == 'cash'
    }.lines(1, :sum)

    # If there are traditional IRA contributions, then we need to use the Pub.
    # 590B worksheet to reconcile the amount to fill into the 1040.
    if line[:this_year_contrib] > 0
      # Both contributions and distributions.
      # Follow Pub. 590-B, Worksheet 1-1 and instructions
      @pub590b_w1_1 = compute_form(Pub590BWorksheet1_1.new(@manager, self))
    end

    # Compute form 8606 (just distributions)
    @form8606 = compute_form(Form8606.new(@manager, self))

    # These lines are used to report to Form 1040, lines 4a-4b
    line[:distribs] = line[:roth_conversion]
    line[:taxable] = @form8606.sum_lines('15c', 18, 25)

  end

  def compute_contributions

    # Was calculated in compute
    return unless line[:this_year_contrib] > 0

    @pub590a_w1_1 = @manager.compute_form(
      Pub590AWorksheet1_1.new(@manager, self)
    )
    @pub590a_w1_2 = @manager.compute_form(
      Pub590AWorksheet1_2.new(@manager, self)
    )

    line[:deductible_contribution] = @pub590a_w1_2.line[7]

    if @form8606
      @form8606.compute_contributions
    else
      @form8606 = Form8606.new(@manager, self)
      @manager.add_form(@form8606)
      @form8606.compute_contributions
    end
  end

end


