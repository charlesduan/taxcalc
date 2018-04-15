require 'tax_form'
require 'dc/d40s'
require 'dc/dc_tax_table'
require 'dc/d40wh'
require 'dc/d2210'

class FormD40 < TaxForm
  include DcTaxTable

  def name
    'D-40'
  end

  def compute
    line[1] = interview("Enter your DC filing status:")
    unless %w(single mfj mfs dep mfssr hoh qw).include?(line[1])
      raise 'Unknown filing status'
    end

    line['a'] = forms(1040).lines(7, :sum)
    line['b'] = forms(1040).lines(12, :sum)
    line['c'] = forms(1040).lines(13, :sum)
    line['d'] = forms(1040).lines(17, :sum)

    line[3] = forms(1040).lines(38, :sum)

    assert_question('Do you have any DC income additions or subtractions?',
                    false)

    line[6] = sum_lines(3, 4, 5)

    line[8] = forms(1040).lines(10, :sum)
    line[9] = forms(1040).lines('20b', :sum)

    assert_no_forms('D-20', 'D-30', 'D-41') # Line 10

    # Line 11
    assert_question('Did you receive income as an annuitant\'s survivor?',
                    false)

    line[13] = sum_lines(*7..12)
    line[14] = line[6] - line[13]

    if has_form?('1040 Schedule A')
      line['15itemized'] = 'X'
      line[16] = @manager.compute_form(CalculationF).line['fill']
    else
      line['15standard'] = 'X'

      # Standard deduction amounts
      line[16] = case line[1]
                 when 'single', 'dep', 'mfs' then 5650
                 when 'hoh' then 7800
                 when 'mfj', 'qw', 'mfssr' then 10275
                 end
    end

    sched_s = @manager.compute_form(FormD40S)
    if sched_s
      line[17] = sched_s.line['G.i']
    else
      line[17] = (%w(mfj mfssr).include?(line[1]) ? 2 : 1)
    end

    if line[1] == 'mfssr'
      line[18] = sched_s.sum_lines('J.h.m', 'J.h.s')
    else
      line[18] = 1775 * line[17] - exemption_reduction(line[14])
    end

    line[19] = sum_lines(16, 18)
    line[20] = line[14] - line[19]

    if line[1] == 'mfssr'
      line['21.mfssr'] = 'X'
      line[21] = sched_s.line['J.l']
    else
      line[21] = compute_tax(line[20])
    end

    line[25] = sum_lines(22, 23, 24)
    line[26] = [ BlankZero, line[21] - line[25] ].max

    line[30] = @manager.compute_form(FormD40WH).line['total']

    line[31] = forms('DC Estimated Tax').lines['amount', :sum]

    line[33] = sum_lines('27d', '27e', 28, 29, 30, 31, 32)

    if line[33] > line[26]
      line[34] = line[33] - line[26]
      line[38] = line[34] - sum_lines(35, 36, 37)
      line[40] = line[38] - line[39, :opt]
    else
      line[41] = line[26] - line[33]

      if line[41] >= 100
        prepayments = sum_lines(30, 31)
        if prepayments < 0.9 * line[26]
          last_year_tax = interview('Enter your last year\'s taxes:')
          if prepayments < 1.1 * last_year_tax
            line[44] = @manager.compute_form(FormD2210).line[11]
          end
        end
      end

      line[45] = sum_lines(41, 42, 43, 44)
    end
  end

  class CalculationF < TaxForm
    def name
      'D-40 Calculation F'
    end

    def compute
      sch_as = forms('1040 Schedule A')

      line['a'] = sch_as.lines(29, :sum)

      assert_question('Were federal deductions taken for non-DC taxes?', false)
      pro_ratas = sch_as.map { |sch_a|
        exp_29 = sch_a.sum_lines(4, 9, 15, 19, 20, 27, 28)
        if sch_a.line[29] == exp_29
          1
        else
          sch_a.line[29] * 1.0 / exp_29
        end
      }
      line['b'] = sch_as.lines(5, :opt).zip(pro_ratas).map { |t, r|
        t * r
      }.inject(&:+).round

      line['c'] = line['a'] - line['b']

      d40 = form('D-40')
      if d40.line[14] <= (d40.line[1] == 'mfs' ? 100000 : 200000)
        line['fill'] = line['c']
        return
      end

      line['d'] = %w(4 14 20).map { |l| sch_as.lines(l, :sum) }.inject(&:+)
      line['e'] = line['c'] - line['d']
      line['f'] = d40.line[14]
      line['g'] = (d40.line[1] == 'mfs' ? 100000 : 200000)
      line['h'] = line['f'] - line['g']
      line['i'] = (line['h'] * 0.05).round
      line['j'] = [ 0, line['e'] - line['i'] ].max
      line['fill'] = line['k'] = sum_lines('d', 'j')
    end

  end

end

