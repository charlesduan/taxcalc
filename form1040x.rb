require 'tax_form'
require 'filing_status'

class Form1040X < TaxForm

  NAME = '1040X'

  def year
    2020
  end

  def initialize(manager)
    super(manager)
    @orig_1040 = submanager(:unamended).form(1040)
    @new_1040 = form(1040)
  end

  #
  # Fills line [l]A, [l]B, and [l]C based on yielding to the given block with
  # the old and new 1040 forms.
  #
  def fill_cols(l)
    col_a = yield(@orig_1040)
    col_c = yield(@new_1040)
    line["#{l}A"] = col_a
    line["#{l}B"] = col_c - col_a unless col_c == col_a
    line["#{l}C"] = col_c
  end

  def calc_cols(l)
    col_a = yield('A')
    col_c = yield('C')
    line["#{l}A"] = col_a
    line["#{l}B"] = col_c - col_a unless col_c == col_a
    line["#{l}C"] = col_c
  end

  def compute
    year = interview("Tax year for this amended return:")
    if (2016..2019).include?(year)
      line["for_#{year}"] = 'X'
    else
      line[:for_year] = year
    end

    #
    # Copy biographical information
    #
    %w(
      first_name last_name ssn spouse_first_name spouse_last_name spouse_ssn
      home_address apt_no phone city_zip foreign_country foreign_state
      foreign_zip
    ).each do |l| copy_line(l, @new_1040) end

    # Starting in 2019, the health care coverage box is left blank
    if year < 2019
      if form(1040).line('61box', :present)
        line['health-coverage.yes'] = 'X'
      else
        line['health-coverage.no'] = 'X'
      end
    end

    #
    # Filing status
    #
    [
      [ 1, 'single' ],
      [ 2, 'mfj' ],
      [ 3, 'mfs' ],
      [ 4, 'hoh' ],
      [ 5, 'qw' ]
    ].each do |l, s|
      line[s] = 'X' if @new_1040.line[l, :present]
    end

    if status.is?(:mfs, :hoh, :qw)
      copy_line('status.name', @new_1040)
    end

    fill_cols(1) { |x| x.line(:agi) }
    fill_cols(2) { |x| x.line(:deduction) }
    calc_cols(3) { |x| line["1#{x}"] - line["2#{x}"] }

    # Line 4 only applies to 2017 and earlier returns. If there is a need to
    # amend such a return, the line number to be copied must be implemented
    # here.
    if year <= 2017
      fill_cols('4a') { |x| raise "Not Implemented" }
    end
    if year >= 2018
      fill_cols('4b') { |x| x.line[:qbid] }
    end

    calc_cols(5) { |x|
      line["3#{x}"] - line["4a#{x}", :opt] - line["4b#{x}", :opt]
    }

    fill_cols(6) { |x| x.line(:tax) }
    line['6.method'] = form('Tax Computation').line[:tax_method]

    fill_cols(7) { |x| x.line[20] }
    calc_cols(8) { |x| [ 0, line["6#{x}"] - line["7#{x}"] ].max }

    if year <= 2018
      fill_cols(9) { |x| x.line(61, :opt) }
    end

    fill_cols(10) { |x| x.line[23] }
    calc_cols(11) { |x| sum_lines("8#{x}", "9#{x}", "10#{x}") }

    fill_cols(12) { |x| x.line['25d'] }
    fill_cols(13) { |x| x.line(26) }
    fill_cols(14) { |x| x.line(27, :opt) }

    #
    # There's probably something to be fixed if a payment was made with an
    # extension to file.
    #
    fill_cols(15) { |x| x.sum_lines(28, 29, 30, 31) }
    if line['15C'] > 0
      raise "Need to check boxes for line 15"
    end

    line[16] = @orig_1040.line(:tax_owed, :opt)
    line[17] = sum_lines('12C', '13C', '14C', '15C', 16)

    line[18] = @orig_1040.line(:tax_refund, :opt)
    line[19] = line[17] - line[18]

    #
    # The instruction for line 19 specifies that if it is negative, then add its
    # negation to line 11C and enter the result on line 20. But the code below,
    # which follows the instruction for line 20, achieves the same result
    # because line 19, when negative, will always be less than line 11C.
    #
    if line['11C'] > line[19]
      line[20] = line['11C'] - line[19]
    else
      line[21] = line[19] - line['11C']
      line[22] = line[21]
    end

    line['III'] = interview("Explanation of changes:")

  end

end


