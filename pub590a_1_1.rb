require 'tax_form'

class Pub590AWorksheet1_1 < TaxForm
  def name
    "Pub. 590-A Worksheet 1-1"
  end

  def year
    2019
  end

  def compute

    # Because the IRS instructions somehow expect you to calculate 1040 line 8b
    # before line 8a, this computation below uses a different approach
    # that appears equivalent.
    line[1] = form(1040).line_7b - form('1040 Schedule 1').sum_lines(
      10, 11, 12, 13, 14, 15, 16, 17, '18a'
    )
    # Line 2 adds back the student loan interest deduction that would have been
    # subtracted in the Schedule 1 computation above. Since it is omitted from
    # the above computation, it is not included here.
    line[2] = 0
    # Line 3 similarly restores the tuition and fees deduction, which was not
    # subtracted from above.
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


