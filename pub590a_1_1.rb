require 'tax_form'

class Pub590AWorksheet1_1 < TaxForm
  NAME = "Pub. 590-A Worksheet 1-1"

  def year
    2024
  end

  def initialize(manager, ssn, spouse_ssn)
    super(manager)
    @ssn = ssn
    @spouse_ssn = spouse_ssn
  end

  def compute

    line[:ssn] = @ssn
    line[:spouse_ssn] = @spouse_ssn

    #
    # The instructions call for filling line 1 with AGI from Form 1040, "figured
    # without Schedule 1 line [for IRA contributions]". This approach below
    # attempts to capture that computation.
    #
    # From what I can tell, the MAGI computation does not allocate between
    # spouses in a MFJ return.
    #
    line[1] = form(1040).line[:tot_inc] \
      - form('1040 Schedule 1').line[:pre_ira_adjust!]

    # Line 2 adds back the student loan interest deduction that would have been
    # subtracted in the Schedule 1 computation above. Since it is omitted from
    # the above computation, it is not included here.
    line[2] = 0
    #
    # These relate to foreign earned income, foreign housing, savings bond
    # interest, and adoption benefits.
    with_form(2555) do |f|
      line[3] = f.line[45]
      line[4] = f.line[50]
    end
    with_form(8815) do |f|
      line[5] = f.line[14]
    end
    with_form(8839) do |f|
      line[6] = f.line[28]
    end
    line['7/magi'] = sum_lines(*1..6)
  end

end


