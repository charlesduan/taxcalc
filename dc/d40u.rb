require_relative '../tax_form'

class FormD40_U < TaxForm

  NAME = 'D-40 Schedule U'

  def year
    2023
  end

  def compute
    set_name_ssn

    #
    # To determine the credit under Part I, Calculation K should be used.
    # Implementing that calculation would require a structure for determining
    # the origin of income, which is currently not implemented.
    #
    confirm("Computation K does not limit the state income tax credit")
    with_form('IT-203') do |it203|
      line['I.a.1.state', :add] = 'NY'
      line['I.a.1.amount', :add] = it203.line[70]
    end

    line['I.a.2'] = line('I.a.1.amount', :sum)
    line['1.a.7/nref_credits'] = sum_lines(*'I.a.2'..'I.a.6')

    line['I.b.3/ref_credits'] = sum_lines(*'I.b.1'..'I.b.2')
    line['II.5/contributions'] = sum_lines(*'II.1'..'II.4')
  end

  def needed?
    return true if line[:nref_credits] != 0
    return true if line[:ref_credits] != 0
    return true if line[:contributions] != 0
    return false
  end
end
