require 'tax_form'

class FormD2210 < TaxForm
  NAME = 'D-2210'

  def year
    2020
  end

  def needed?
    !line[:no_interest_owed!, :present]
  end

  def compute
    d40 = form('D-40')
    line[1] = d40.line[:pre_hc_tax]
    line[2] = (line[1] * 0.9).round
    line[3] = (
      # In 2021 change 27 to :pre_hc_tax
      @manager.submanager(:last_year).form('D-40').line[27] * 1.1
    ).round
    line[4] = [ line[2], line[3] ].min
    line[5] = (0.25 * line[4]).round

    #
    # To avoid duplicativeness, we compute the test for whether this form needs
    # to be filed here, after partially completing the form.
    #
    line[:prepayments!] = d40.sum_lines(:withholdings, :est_tax)
    if line[:prepayments!] >= line[5]
      line[:no_interest_owed!] = 'X'
      return
    end

    line[6, :all] = [ line[5], line[5] * 2, line[5] * 3, line[4] ]
    qp = (line[:prepayments!] * 0.25).round
    line[7, :all] = [ qp, qp * 2, qp * 3, line[:prepayments!] ]
    line[8, :all] = line[6, :all].zip(line[7, :all]).map { |l6, l7| l6 - l7 }
    line[9, :all] = [ 0.0175, 0.0265, 0.0351, 0.0259 ]
    line[10, :all] = line[8, :all].zip(line[9, :all]).map { |l8, l9|
      (l8 * l9).round
    }
    line['11/underpay_int'] = line[10, :sum]
  end

end
