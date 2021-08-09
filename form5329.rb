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

    with_form(8889, required?: true) do |f|
      line['hsa_self_excess!'] = f.line[2] - f.line[12]
      line['hsa_employer_excess!'] = \
        f.line[9] - [ 0, f.line[8] - f.line[10, :opt] ].max
      line['hsa_excess_withdrawal!'] = forms('HSA Excess Withdrawal') { |f|
        f.line[:tax_year] == year
      }.lines(:amount, :sum)
    end

    # It is assumed that if the withdrawn amount exceeds the excess
    # contributions, then the earnings have been withdrawn as well.
    line[47] = [
      0,
      line['hsa_self_excess!'] + line['hsa_employer_excess!'] -
      line['hsa_excess_withdrawal!']
    ].max

    line['48/hsa_excess'] = sum_lines(46, 47)
    confirm("The value of your HSAs is greater than $#{line[48]}")
    line['49/hsa_excise_tax'] = (0.06 * line[48]).round
    total += line[49]
  end


  def compute_total
    line[:total!] = @total
  end

end
