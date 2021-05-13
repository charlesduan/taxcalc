require 'tax_form'
require 'filing_status'
require 'pub590b'
require 'form8606'
require 'pub590a_1_1'
require 'pub590a_1_2'

#
# Computes 1040 information relating to IRA distributions and contributions. Its
# purpose is to compute the following:
#
# - Line taxable_distrib: The taxable amount of IRA distributions to be shown
#   on Form 1040.
# - Line total_distrib: The total amount of distributions, also show on Form
#   1040.
# - Line deductible_contrib: The deductible portion of IRA contributions.
# - Line nondeductible_contrib: The non-deductible portion of IRA
#   contributions (used for Form 8606).
# - Form 8606, as necessary.
#
# The IRA Analysis has two methods: compute and compute_continuation. The former
# computes the *_distrib values; the latter deductible_contrib and Form 8606. 
#
class IraAnalysis < TaxForm

  NAME = 'IRA Analysis'

  def year
    2020
  end

  attr_reader :form8606, :pub590a_w1_1, :pub590a_w1_2, :pub590b_w1_1

  def compute


    #
    # I. Gathering information
    #

    confirm('You have no qualified disaster distribution (Form 8915)')

    # Collect contributions.
    line[:this_year_contrib] = forms(
      'Traditional IRA Contribution'
    ).lines(:amount, :sum)

    # Collect distributions, which are reported on 1099-R.
    all_1099rs = forms('1099-R')
    all_1099rs.each do |x|
      next if x.line['ira-sep-simple?']
      next if [ 1, 2, 3, 4, 5, 7 ].include?(f.line[7])
      raise "Non-IRA 1099-R forms not implemented"
    end

    #
    # The destination could also be a traditional-to-traditional rollover, a
    # Roth-to-Roth rollover, a qualified charitable distribution, an HSA funding
    # distribution, or cash. The "destination" field in Form 1099-R should
    # reflect these. To implement any other destinations for an IRA
    # distribution, see the 1040 line 4a instructions.
    #
    distrib = {
      'roth' => BlankZero,
      'cash' => BlankZero
    }
    all_1099rs.each do |f|
      distrib[f.line[:destination]] += f.line[1]
      if f.line[:destination] != 'roth'
        raise "Cannot handle 1099-R distributions that are not Roth conversions"
      end
    end
    distrib.each do |d, v|
      line["distrib_#{d}"] = v
    end
    line[:total_distrib] = all_1099rs.lines(1, :sum)

    #
    # II. Computing
    #
    # Computation must be split into two parts because of the following ordering
    # of things:
    #
    # 1. 1040 asks for taxable IRA distributions, which invokes IRA Analysis
    # 2. 1040 performs additional income computations
    # 3. 1040 asks for deductible IRA contributions, which invokes IRA Analysis
    #    but depends on values from step 2
    #
    # Accordingly, each computation method implemented below will construct a
    # continuation proc that handles the computations for step 3.
    #
    if line[:this_year_contrib] == 0

      compute_distributions_only

    else
      if all_1099rs.empty?
        # Contributions but no distributions.
        compute_contributions_only
      else
        # Both contributions and distributions.
        compute_contributions_and_distributions
      end
    end

  end

  # This method is called to continue computation when Form 1040 requires the
  # deductible contributions amount.
  def compute_continuation
    @contrib_continuation.call

    # Compute Form 8606
    compute_form(8606)

    # Check that the required lines were all computed
    [
      :total_distrib, :taxable_distrib,
      :deductible_contrib, :nondeductible_contrib
    ].each do |l|
      raise "Missing #{l} from IRA Analysis" unless line[l, :present]
    end

  end

  #
  # Performs computations when there were distributions only.
  #
  def compute_distributions_only
    line[:deductible_contrib] = BlankZero
    line[:nondeductible_contrib] = BlankZero
    # If there were no contributions, then all we need to do is the following:
    # (1) Compute Form 8606 if it's needed, which will set taxable_distrib
    # (2) If it's not needed, then there is no basis in traditional IRAs so
    #     the taxable portion of the distribution is the whole distribution.
    unless compute_8606_if_needed
      line[:taxable_distrib] = line[:total_distrib]
    end
    @contrib_continuation = proc { }
  end


  #
  # Performs computations when there are no distributions. The taxable_distrib
  # is naturally zero, and we use Pub. 590-A Worksheet 1-2 to compute the
  # deductible and nondeductible contributions.
  #
  def compute_contributions_only
    raise "Inconsistent state" unless line[:total_distrib] == 0
    line[:taxable_distrib] = line[:total_distrib]
    @contrib_continuation = proc {
      @pub590a_w1_2 = @manager.compute_form("Pub. 590-A Worksheet 1-2")
      line[:deductible_contrib] = @pub590a_w1_2.line[7]
      line[:nondeductible_contrib] = @pub590a_w1_2.line[8]
    }
  end

  #
  # This method and the next are called when there were both contributions and
  # distributions made in this tax year.
  #
  def compute_contributions_and_distributions

    #
    # This follows the instructions in Pub. 590-B, "Contribution and
    # distribution in the same year".
    #
    @pub590b_w1_1 = compute_form("Pub. 590-B Worksheet 1-1")

    # Step 8 of the instructions: copies 590-B W1-1 line 9 or 11, coded as
    # :taxable_distrib, to Form 8606 line 15a. (Also computes 15b and 15c
    # incidentally.)
    line['8606_15a'] = @pub590b_w1_1.line[:taxable_distrib]
    line['8606_15b'] = BlankZero # Qualified disaster distributions
    line['8606_15c'] = line['8606_15a'] - line['8606_15b']

    # This will compute lines 18 and 25c
    compute_8606_parts_ii_iii_for_contrib_distrib

    line[:taxable_distrib] = sum_lines(*%w(8606_15c 8606_18 8606_25c))

    @contrib_continuation = proc {
      compute_contributions_and_distributions_continuation
    }
  end

  def compute_contributions_and_distributions_continuation

    @pub590a_w1_2 = @manager.compute_form("Pub. 590-A Worksheet 1-2")

    # Step 2 is done here by setting line nondeductible_contrib
    line[:deductible_contrib] = @pub590a_w1_2.line[:deductible_contrib]
    line[:nondeductible_contrib] = @pub590a_w1_2.line[:nondeductible_contrib]

    # Step 3 says to complete lines 2-5 of Form 8606. Rather than invoking that
    # form, the computations occur here, and Form 8606 is coded to copy the
    # information.
    compute_8606_lines_2_to_5

    # Step 4.
    if line['8606_5'] < @pub590b_w1_1.line[:nontax_distrib]
      # In this case (where the IRA basis in the current tax year was less than
      # the nontaxable portion of the distribution), we complete Form 8606 lines
      # 6-15c and stop. That will be done when Form 8606 is computed.
      line[:compute_8606_rest?] = true
      # The problem is that this instruction appears to be circular: It requires
      # computing line 15c *after* line 15c was used as part of the computation
      # of MAGI in Pub. 590-A Worksheet 1-1. The best guess I have is that Pub.
      # 590-B Worksheet 1-1 computes a "fake" value for the taxable part of the
      # IRA distribution for purposes of computing the 590-A Worksheet 1-1 MAGI,
      # and then the deductible contribution can be calculated, allowing the
      # rest of Form 8606 to be computed, which then sets the final value of the
      # taxable part of the distribution.
      #
      # So far, I don't run into this problem since my contributions are clearly
      # not deductible, but in case this condition is ever reached, I need to
      # revisit to see what numbers are produced.
      raise "IRS instructions are ambiguous here"
    else
      # Steps 5-6.
      # In this case, we do not compute Form 8606 lines 6-12, instead entering
      # various numbers onto the lines.
      line[:compute_8606_rest?] = false
      line['8606_13'] = @pub590b_w1_1.line[:nontax_distrib]
      line['8606_13*note'] = 'Line 13 from Pub. 590-B Worksheet 1-1'
    end

    @form8606 = compute_form(8606)
  end

  # Computes the values of lines 2-5 of Form 8606 (which are stored as lines in
  # this IraAnalysis form, to be copied later by Form 8606 itself).
  def compute_8606_lines_2_to_5
    if @manager.submanager(:last_year).has_form?(8606)
      # For 2021, change line 14 to :tot_basis
      line['8606_2'] = @manager.submanager(:last_year).form(8606).line[14]
    else
      line['8606_2'] = BlankZero
    end
    line['8606_3'] = sum_lines(:nondeductible_contrib, '8606_2')
    line['8606_4'] = [
      forms('Traditional IRA Contribution') { |f|
        f.line[:date].year > @manager.year
      }.lines(:amount, :sum),
      line[:nondeductible_contrib]
    ].min
    line['8606_5'] = line['8606_3'] - line['8606_4']
  end

  #
  # Computes Part II and III of Form 8606 when there are both contributions and
  # distributions.
  #
  def compute_8606_parts_ii_iii_for_contrib_distrib

    raise "No Pub. 590-B Worksheet 1-1" unless @pub590b_w1_1

    # Part II
    if line[:distrib_roth] > 0
      line['8606_16'] = line[:distrib_roth]
      line['8606_17'] = @pub590b_w1_1.line[:nontax_distrib]
      line['8606_18'] = @pub590b_w1_1.line[:taxable_roth_conv]
      line['8606_18*note'] = 'Lines 17 and 18 from Pub. 590-B Worksheet 1-1'
    end

    # Part III
    roth_forms = forms('1099-R') { |f| %w(B J T).include?(f.line[7]) }
    unless roth_forms.empty?
      raise "Form 8606 part III is not implemented"
    end
  end

  #
  # Determines if Form 8606 ought to be computed (namely, if it was computed in
  # the last year, or if nondeductible contributions were made this year). If
  # so, then this method computes it and returns true; otherwise it returns
  # false. For purposes of this method, the nondeductible contributions must
  # have already been determined.
  #
  # This method is used only if there were either contributions or distributions
  # but not both.
  #
  def compute_8606_if_needed
    unless line[:nondeductible_contrib, :present]
      raise "Cannot use this method"
    end
    ndc = line[:nondeductible_contrib]
    if @manager.submanager(:last_year).has_form?(8606) || ndc != 0
      compute_8606_lines_2_to_5
      line[:compute_8606_rest?] = true
      @form8606 = compute_form(8606)
      line[:taxable_distrib] = @form8606.sum_lines('15c', 18, '25c')
      return true
    else
      return false
    end
  end

end


