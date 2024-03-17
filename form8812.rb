
#
# From Form 1040, line 19 instructions
#
class ChildTaxCreditWorksheet < TaxForm
  NAME = '1040 Child Tax Credit Worksheet'

  def year
    2020
  end

  def compute
    f1040 = form(1040)

    #
    # Part 1
    #

    if f1040.line[:dep_4_ctc, :present]
      line['1num'] = f1040.line[:dep_4_ctc, :all].count { |x| x == 'X' }
      line[1] = line['1num'] * 2000
    end

    if f1040.line[:dep_4_other, :present]
      line['2num'] = f1040.line[:dep_4_other, :all].count { |x| x == 'X' }
      line[2] = line['2num'] * 500
    end

    line[3] = sum_lines(1, 2)
    # No point in calculating the credit if there won't be one
    if line[3] == 0
      line[:fill!] = 0
      return
    end

    # Income limits
    line[4] = f1040.line_agi
    line[5] = f1040.status.double_mfj(200_000)
    if line[4] > line[5]
      line['6.yes'] = 'X'
      l6 = line[4] - line[5]
      if l6 % 1000 == 0
        line[6] = l6
      else
        line[6] = l6.round(-3) + 1000
      end
      line[7] = (line[6] * 0.05).round
    else
      line['6.no'] = 'X'
      line[7] = 0
    end

    if line[3] > line[7]
      line['8.yes'] = 'X'
      line[8] = line[3] - line[7]
    else
      line['8.no'] = 'X'
      line[:fill!] = BlankZero
      return
    end

    #
    # Part 2
    #

    line[9] = f1040.line[:pre_ctc_tax]

    find_or_compute_form('1040 Schedule 3') do |f|
      line['10_3_1'] = f.line[1, :opt]
      line['10_3_2'] = f.line[2, :opt]
      line['10_3_3'] = f.line[3, :opt]
      line['10_3_4'] = f.line[4, :opt]
    end
    with_form(5695) do |f|
      line['10_5695_30'] = f.line[30, :opt]
    end
    with_form(8910) do |f|
      line['10_8910_15'] = f.line[15, :opt]
    end
    with_form(8936) do |f|
      line['10_8936_23'] = f.line[23, :opt]
    end
    with_form('1040 Schedule R') do |f|
      line['10_r_22'] = f.line[22, :opt]
    end
    line[10] = sum_lines(*%w(
      10_3_1 10_3_2 10_3_3 10_3_4 10_5695_30 10_8910_15 10_8936_23 10_r_22
    ))

    if line[10] >= line[9]
      line['11.yes'] = 'X'
      line[:fill!] = 0
      return
    end
    line['11.no'] = 'X'
    line[11] = line[9] - line[10]

    if line[8] > line[11]
      line['12.yes'] = 'X'
      line[12] = line[11]
    else
      line['12.no'] = 'X'
      line[12] = line[8]
    end

    line[:fill!] = line[12]

  end
end


