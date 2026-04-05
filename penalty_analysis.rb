require 'tax_form'
require_relative 'form2210'

#
# Analysis for underpayment penalty. The purpose is to compute the tax shown,
# which is used in the penalty computation. Since this value needs to be known
# across years, it is useful to compute it separately so that it is retained in
# the computation data.
#
class PenaltyAnalysis < TaxForm
  NAME = 'Penalty Analysis'
  def year
    2025
  end

  #
  # Copy-paste this from the form instructions for Form 2210, line 2.
  #
  SCHED_2_ADD_TAX_LINES = %w(
   4 8 9 11 12 14 15 16 17a 17c 17d 17e 17f 17g 17h 17i 17j 17l 17z 19
  )

  def compute

    f1040 = form(1040)

    line[:tax_after_credits] = f1040.line[:tax_after_credits]


    line[:sched_2_additions] = with_form(
      '1040 Schedule 2', otherwise: BlankZero
    ) { |f| f.sum_lines(*SCHED_2_ADD_TAX_LINES) }

    line[:refundable_credits] = f1040.sum_lines(
      '27a', 28, 29, 30
    ) + with_form('1040 Schedule 3', otherwise: BlankZero) { |f|
      f.sum_lines(9, 12, '13b')
    }

    line[:tax_shown] = line[:tax_after_credits] + line[:sched_2_additions] -
      line[:refundable_credits]
  end

end
