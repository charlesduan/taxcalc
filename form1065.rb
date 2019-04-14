require 'tax_form'
require 'form4562'

class Form1065 < TaxForm

  def name
    1065
  end

  def compute
    bio = form('Partnership')
    line['name'] = bio.line(:name)
    line['address'] = bio.line(:address) + \
      (bio.line(:address2, :present) ? " " + bio.line(:address2) : "")
    line['city_zip'] = bio.line(:city_zip)
    line['A'] = bio.line('business')
    line['B'] = bio.line('product')
    line['C'] = bio.line('code')
    line['D'] = bio.line('ein')
    line['E'] = bio.line(:start)

    assert_question(
      "Does this partnership meet the 4 conditions in Schedule B, line 4?",
      true
    )

    assert_question(
      "Does any box in line G need to be checked?", false
    )

    case bio.line('accounting')
    when 'Cash' then line['H.1'] = 'X'
    when 'Accrual' then line['H.2'] = 'X'
    else
      line['H.3'] = 'X'
      line['H.other'] = bio.line('accounting')
    end

    line['I'] = forms('Partner').count

    line['1a'] = forms('1099-MISC').lines(7, :sum)
    line['1c'] = line['1a'] - line['1b', :opt]
    line[3] = line['1c'] - line[2, :opt]
    line[8] = sum_lines(3, 4, 5, 6, 7)

    if has_form?('Asset')
      @manager.compute_form(Form4562)
    end

    line[20] = form('Deductions').line[:fill!]
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
      "Is the answer to any question on Schedule B `yes' " + \
      "(other than 2, 4, and 24)?",
      false
    )

    big_indiv, big_inst = forms('Partner').map { |f|
      if f.line[:share] >= 0.5 || f.line[:capital] >= 0.5
        f.line[:type]
      else
        nil
      end
    }.compact.partition { |x| %w(Individual Estate).include?(x) }
    line[big_inst.empty? ? 'B2a.no' : 'B2a.yes'] = 'X'
    line[big_indiv.empty? ? 'B2b.no' : 'B2b.yes'] = 'X'

    line['B3a.no'] = 'X'
    line['B3b.no'] = 'X'
    line['B4.yes'] = 'X'
    line['B5.no'] = 'X'
    line['B6.no'] = 'X'
    line['B7.no'] = 'X'
    line['B8.no'] = 'X'
    line['B9.no'] = 'X'
    line['B10a.no'] = 'X'
    line['B10b.no'] = 'X'
    line['B10c.no'] = 'X'
    line['B12.no'] = 'X'

    if forms('Partner').lines('nationality', :all).any? { |x| x != 'domestic' }
      raise "Foreign partners not currently handled"
    end

    line['B14.no'] = 'X'
    line['B15'] = 0
    line['B16a.no'] = 'X'
    line['B17'] = 0
    line['B18'] = 0
    line['B19.no'] = 'X'
    line['B20.no'] = 'X'
    line['B21.no'] = 'X'
    line['B22.no'] = 'X'
    line['B23.no'] = 'X'

    # Line 24 is satisfied if line 4 was satisfied above.
    line['B24.yes'] = 'X'

    assert_question(
      "Do you want to opt out of the centralized partnership audit regime?",
      false
    )
    line['B25.no'] = 'X'

    pr_name = interview("Enter the partnership representative's name:")
    pr_form = forms('Partner').find { |x| x.line['name'] == pr_name }
    unless pr_form
      raise "No partner named #{pr_name} for the partnership representative"
    end
    line['PR.name'] = pr_name
    if pr_form.line['type'] == 'Individual'
      line['PR.tin'] = pr_form.line['ssn']
      line['PR.address'] = pr_form.line['address']
      line['PR.address2'] = pr_form.line['address2']
      line['PR.phone'] = interview("Partnership representative phone:")
    else
      raise "No support for non-individual partnership representative"
    end

    line['B26.no'] = 'X'

    line['K1'] = line[22]
    line['K5'] = forms('1099-INT').lines(1, :sum)
    if has_form?(4562)
      line['K12'] = form(4562).line[12]
    end

    line['K14a'] = line['K1']

    line['Analysis.1'] = sum_lines(*%w(K1 K2 K3c K4 K5 K6a K7 K8 K9a K10 K11)) \
      - sum_lines(*%w(12 13a 13b 13c2 13d 16l))

    line['Analysis.2a(ii)'] = line['Analysis.1']

    # We assumed previously that the Schedule B line 6 answer was yes, so assets
    # are less than $10 million and no M-3 is filed.
    raise "No state in address" unless (line[:address2] =~ / ([A-Z]{2}) \d{5}/)
    state = $1
    if %w(
      CT DE DC GA IL IN KY ME MD MA MI NH NJ NY NC OH PA RI SC TN VT VA WV WI
    ).include?(state)
      line[:send_to!] = 'Kansas City MO 64999-0011'
    else
      line[:send_to!] = 'Ogden UT 84201-0011'
    end
  end
end

