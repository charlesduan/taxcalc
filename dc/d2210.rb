require 'tax_form'

class FormD2210 < TaxForm
  NAME = 'D-2210'

  def year
    2023
  end

  def needed?
    !line[:no_interest_owed!, :present]
  end

  def compute
    d40 = form('D-40')
    line[1] = d40.line[:pre_hc_tax]
    line[2] = (line[1] * 0.9).round
    line[3] = @manager.submanager(:last_year).form('D-40').line[:pre_hc_tax]
    line[4] = (line[3] * 1.1).round
    line[5] = [ line[2], line[4] ].min
    line[6] = (0.25 * line[5]).round

    #
    # To avoid duplicativeness, we compute the test for whether this form needs
    # to be filed here, after partially completing the form.
    #
    line[:prepayments!] = d40.sum_lines(:withholdings, :est_tax)
    if line[:prepayments!] >= line[5]
      line[:no_interest_owed!] = 'X'
      return
    end

    line[7, :all] = [ line[6], line[6] * 2, line[6] * 3, line[5] ]
    qp = (line[:prepayments!] * 0.25).round
    line[8, :all] = [ qp, qp * 2, qp * 3, line[:prepayments!] ]
    line[9, :all] = line[6, :all].zip(line[8, :all]).map { |l6, l7| l6 - l7 }
    line[10, :all] = [ 0.0175, 0.0265, 0.0351, 0.0259 ]
    line[11, :all] = line[9, :all].zip(line[10, :all]).map { |l9, l10|
      (l9 * l10).round
    }
    line['12/underpay_int'] = line[11, :sum]
  end

end
