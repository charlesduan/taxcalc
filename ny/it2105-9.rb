require_relative '../tax_form'

class FormIT2105_9 < TaxForm

  NAME = 'IT-2105.9'
  def year
    2023
  end

  def compute
    set_name_ssn

    it203 = form('IT-203')

    line[1] = it203.line[:tot_tax] - it203.line[:use_tax] \
      - it203.line[:voluntary_contrib]

    # Lines 2-10, credits, don't apply to me
    line[11] = sum_lines(*2..10)
    line[12] = line[1] - line[11]
    line[13] = (line[12] * 0.9).round
    line[14] = it203.sum_lines(:nys_wh, :nyc_wh, :yonkers_wh)
    line[15] = line[12] - line[14]
    if line[15] < 300
      return
    end
    @manager.submanager(:last_year).with_form('IT-203') do |ly|
      cap = it203.line[:status_mfs, :present] ? 75_000 : 150_000

      line[16] = (
        ly.sum_lines(50, 58) - ly.sum_lines(60, '60a', 61)
      ) * (ly.line[:agi] > cap ? 1.1 : 1)
    end

    line[17] = [ line[13], line[16] ].min
    line[18] = line[14]
    line[19] = BlankZero
    line[20] = sum_lines(18, 19)
    line[21] = line[17] - line[20]
    line[22] = (line[21] * 0.06801).round
    line[23] = 0
    line['24/amount'] = line[22] - line[23]
  end

end
