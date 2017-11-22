require 'tax_form'
require 'filing_status'

class Form1040X < TaxForm

  def name
    '1040X'
  end

  def initialize(manager, orig_1040, new_1040)
    super(manager)
    @orig_1040 = orig_1040
    @new_1040 = new_1040
  end

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
    [
      [ 1, 'single' ],
      [ 2, 'mfj' ],
      [ 3, 'mfs' ],
      [ 4, 'hoh' ],
      [ 5, 'qw' ]
    ].each do |l, s|
      line[s] = 'X' if @new_1040.line[l, :present]
    end

    if form(1040).line('61box', :present)
      line['health-coverage.yes'] = 'X'
    else
      line['health-coverage.no'] = 'X'
    end

    fill_cols(1) { |x| x.line(37) }
    fill_cols(2) { |x| x.line(40) }
    calc_cols(3) { |x| line["1#{x}"] - line["2#{x}"] }

    fill_cols(4) { |x| x.line(42) }
    calc_cols(5) { |x| line["3#{x}"] - line["4#{x}"] }

    fill_cols(6) { |x| x.line(47) }
    fill_cols(7) { |x| x.line(55) }
    calc_cols(8) { |x| line["6#{x}"] - line["7#{x}"] }

    fill_cols(9) { |x| x.line(61, :opt) }
    fill_cols(10) { |x| x.sum_lines(57, 58, 59, '60a','60b', 62) }
    calc_cols(11) { |x| sum_lines("8#{x}", "9#{x}", "10#{x}") }

    fill_cols(12) { |x| x.sum_lines(64, 71) }
    fill_cols(13) { |x| x.line(65) }
    fill_cols(14) { |x| x.line('66a', :opt) }
    fill_cols(15) { |x| x.sum_lines(67, 68, 69, 72, 73) }

    assert_no_forms(4868, 2350)
    line[16] = @orig_1040.line(70, :opt)

    assert_no_forms(8689)
    line[17] = sum_lines('12C', '13C', '14C', '15C', 16)

    line[18] = @orig_1040.line(75, :opt)

    line[19] = line[17] - line[18]
    if line['11C'] > line[19]
      line[20] = line['11C'] - line[19]
    else
      line[21] = line[19] - line['11C']
      line[22] = line[21]
    end

  end

end


