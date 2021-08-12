require 'tax_form'

#
# Additional Taxes on Qualified Plans and Other Tax-Favored Accounts
#
# This form is unusual in that it captures a variety of unrelated taxes, such
# that it could be filled out for one or more reasons, and each computation will
# depend on other forms. As a result, it is not really possible to know exactly
# when to compute the whole form. Thus, instead of putting the main computation
# in the +compute+ method, a separate +compute_[part]+ method is used for each
# part. Callers of this form should +find_or_compute_form(5329)+ and then
# execute the appropriate subcomputation.
#
class Form5329 < TaxForm

  NAME = '5329'
  def year
    2020
  end

  def compute
    set_name_ssn
    @total = 0
  end

  def compute_hsa
    line[42] = @manager.submanager(:last_year).with_form(
      5329, otherwise_return: BlankZero
    ) { |f| f.line[:hsa_excess] }
    unless line[42] == 0
      raise "Lines 43-46 not implemented"
    end

    f8889 = form(8889)
    line[47] = f8889.sum_lines(:self_excess!, :employer_excess!) - \
      f8889.line[:excess_wd_basis!, :opt]

    line['48/hsa_excess'] = sum_lines(46, 47)
    confirm("The value of your HSAs is greater than $#{line[48]}")
    line['49/hsa_excise_tax'] = (0.06 * line[48]).round
    @total += line[49]
  end


  def compute_total
    line[:total!] = @total

    # This ensures that this form cannot be further filled; to do so would
    # attempt to add to @total which is no longer an integer
    @total = nil
    line[:total!]
  end

  #
  # This is based on the 1040 instructions for computing tax shown for purposes
  # of the estimated tax penalty.
  #
  def tax_shown_adjustment
    line[:total!] - sum_lines(4, 8)
  end

end
