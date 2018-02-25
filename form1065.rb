require 'tax_form'

class Form1065 < TaxForm

  def name
    '1065'
  end

  def compute
    line['name'] = form('Partnership').line(:name)
    line['address'] = form('Partnership').line(:address)
    line['address2'] = form('Partnership').line(:address2)
    line['A'] = form('Partnership').line('business')
    line['B'] = form('Partnership').line('product')
    line['C'] = form('Partnership').line('code')
    line['D'] = form('Partnership').line('ein')
    line['E'] = form('Partnership').line(:start)

    assert_question("Is the answer to Schedule B, line 6 `yes'?", true)

    case form('Partnership').line('accounting')
    when 'Cash' then line['H.1'] = 'X'
    when 'Accrual' then line['H.2'] = 'X'
    else
      line['H.3'] = 'X'
      line['H.other'] = form('Partnership').line('accounting')
    end

    line['I'] = forms('Partner').count

    line['1a'] = forms('1099-MISC').lines(7, :sum)
    line['1c'] = line['1a'] - line['1b', :opt]
    line[3] = line['1c'] - line[2, :opt]
    line[8] = sum_lines(3, 4, 5, 6, 7)

    line[20] = form('Deductions').line[:fill]
    line[21] = sum_lines(9, 10, 11, 12, 13, 14, 15, '16c', 17, 18, 19, 20)
    line[22] = line[8] - line[21]

    {
      'B1a' => 'domestic general partnership',
      'B1b' => 'domestic limited partnership',
      'B1c' => 'domestic LLC',
      'B1d' => 'domestic LLP',
      'B1e' => 'foreign partnership',
      'B1f' => 'other'
    }.each do |lineno, desc|
      if desc == 'other'
        line[lineno] = 'X'
        line["#{lineno}.text"] = interview("Entity type:")
        break
      elsif interview("Is the filing entity a #{desc}?")
        line[lineno] = 'X'
        break
      end
    end

    assert_question(
      "Is the answer to any question on Schedule B `yes' (other than 3 and 6)?",
      false
    )

    line['B2.no'] = 'X'

    big_indiv, big_inst = forms('Partner').map { |f|
      if f.line[:share] >= 0.5 || f.line[:capital] >= 0.5
        f.line[:type]
      else
        nil
      end
    }.compact.partition { |x| %w(Individual Estate).include?(x) }
    line[big_inst.empty? ? 'B3a.no' : 'B3a.yes'] = 'X'
    line[big_indiv.empty? ? 'B3b.no' : 'B3b.yes'] = 'X'

    line['B4a.no'] = 'X'
    line['B4b.no'] = 'X'
    line['B5.no'] = 'X'
    line['B6.yes'] = 'X'
    line['B7.no'] = 'X'
    line['B8.no'] = 'X'
    line['B9.no'] = 'X'
    line['B10.no'] = 'X'
    line['B11.no'] = 'X'
    line['B12a.no'] = 'X'
    line['B12b.no'] = 'X'
    line['B12c.no'] = 'X'
    line['B14.no'] = 'X'

    if forms('Partner').lines('nationality', :all).any? { |x| x != 'domestic' }
      raise "Foreign partners not currently handled"
    end

    line['B16.no'] = 'X'
    line['B17'] = 0
    line['B18a.no'] = 'X'
    line['B19'] = 0
    line['B20'] = 0
    line['B21.no'] = 'X'
    line['B22.no'] = 'X'

    line['K1'] = line[22]
    line['K5'] = forms('1099-INT').lines(1, :sum)
    line['K14a'] = line['K1']

    line['Analysis.1'] = sum_lines(*%w(K1 K2 K3c K4 K5 K6a K7 K8 K9a K10 K11)) \
      - sum_lines(*%w(12 13a 13b 13c2 13d 16l))

    line['Analysis.2a(ii)'] = line['Analysis.1']

    # We assumed previously that the Schedule B line 6 answer was yes, so assets
    # are less than $10 million and no M-3 is filed.
    raise "No state in address" unless (line[:address2] =~ / ([A-Z]{2}) \d{5}/)
    state = $1
    if %w(GA IL KY MI TN WI).include?(state)
      line['send'] = 'Kansas City MO 64999-0011'
    elsif %w(
      CT DE DC FL IN ME MD MA NH NJ NY NC OH PA RI SC VT VA WV
    ).include?(state)
      line['send'] = 'Cincinnati OH 45999-0011'
    else
      line['send'] = 'Ogden UT 84201-0011'
    end
  end
end

