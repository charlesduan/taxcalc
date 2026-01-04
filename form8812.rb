require_relative 'tax_form'

#
# Child tax credit. This replaces the worksheet that used to be for determining
# the credit.
#
class Form8812 < TaxForm

  NAME = '1040 Schedule 8812'

  def year
    2024
  end

  def compute
    f1040 = form(1040)

    set_name_ssn

    #
    # Part 1
    #

    line[1] = f1040.line[:agi]
    # Lines 2a-2c relate to foreign or US territory income.
    line['2d'] = sum_lines(%w(2a 2b 2c))
    line[3] = sum_lines(1, '2d')


    if f1040.line[:dep_4_ctc, :present]
      line[4] = f1040.line[:dep_4_ctc, :all].count { |x| x == 'X' }
      line[5] = line[4] * 2000
    end

    if f1040.line[:dep_4_other, :present]
      line[6] = f1040.line[:dep_4_other, :all].count { |x| x == 'X' }
      line[7] = line[6] * 500
    end

    line[8] = sum_lines(5, 7)
    # No point in calculating the credit if there won't be one
    if line[8] == 0
      line['14/ctc'] = BlankZero
      return
    end

    # Income limits
    line[9] = f1040.status.double_mfj(200_000)
    line10 = line[3] - line[9]
    if line10 <= 0
      line[10] = 0
    elsif line10 % 1000 == 0
      line[10] = line10
    else
      line[10] = line10.round(-3) + 1000
    end
    line[11] = (line[10] * 0.05).round

    if line[8] > line[11]
      line['12.yes'] = 'X'
      line[12] = line[8] - line[11]
    else
      line['12.no'] = 'X'
      line[12] = BlankZero
      line['14/ctc'] = BlankZero
      return
    end

    with_form('1040 Schedule 3', otherwise: proc {
      line[13] = f1040.line(:pre_ctc_tax)
    }) do |sched_3|
      if sched_3.line[:form_8812_worksheet_b_needed!]
        raise "Worksheet B not implemented"
      else
        line[13] = f1040.line(:pre_ctc_tax) - \
          sched_3.line[:form_8812_exclusions!]
      end
    end

    line['14/ctc'] = [ line[12], line[13] ].min
  end

  #
  # Compute the additional child tax credit.
  #
  def compute_actc

    if line[12] <= line[14]
      line['27/actc'] = BlankZero
      return
    end

    raise "Additional child tax credit not implemented"

  end
end


