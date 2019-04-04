require 'tax_form'

class Pub590AWorksheet1_1 < TaxForm
  def name
    "Pub. 590-A Worksheet 1-1"
  end

  def year
    2018
  end

  def initialize(manager, ira_analysis)
    super(manager)
    @ira_analysis = ira_analysis
  end

  def compute

    # Because the IRS instructions somehow expect you to calculate Schedule 1,
    # line 36 before line 32, this computation below uses a different approach
    # that appears equivalent.
    line[1] = form(1040).line[6] - form('1040 Schedule 1').sum_lines(
      23, 24, 25, 26, 27, 28, 29, 30, '31a'
    )
    # Line 2 adds back the student loan interest deduction that would have been
    # subtracted in the Schedule 1 computation above. Since it is omitted from
    # the above computation, it is not included here.
    line[2] = 0
    # Line 3 pertains to DPAD activities that are added as a special case to
    # line 36. I assume that there aren't any.
    line[3] = 0
    #
    # These relate to foreign earned income, foreign housing, savings bond
    # interest, and adoption benefits.
    with_form(2555) do |f|
      line[4] = f.line[45]
      line[5] = f.line[50]
    end
    with_form(8815) do |f|
      line[6] = f.line[14]
    end
    with_form(8839) do |f|
      line[7] = f.line[28]
    end
    line[8] = sum_lines(1, 2, 3, 4, 5, 6, 7)
  end

end


