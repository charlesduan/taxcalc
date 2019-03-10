require 'tax_form'

class Form4562 < TaxForm

  def name
    '4562'
  end

  def compute

    assert_question('Do you have an enterprise zone business?', false)

    if has_form?(1065)
      for_partnership = true
    elsif has_form?(1040)
      for_partnership = false
      k1_form = form('1065 Schedule K-1')
    else
      raise 'Neither 1065 nor 1040 found'
    end

    if for_partnership
      line['name'] = form(1065).line(:name)
      line['id'] = form(1065).line(:D)

      line[1] = 1_000_000
      line[2] = forms('Asset').select { |x| x.line["179?"] }.map { |x|
        x.line['amount']
      }.inject(:+)

    else
      bio = form('Biographical')
      line[:name] = form(1040).full_name
      unless forms('1065 Schedule K-1').count == 1
        raise "Cannot handle multiple businesses"
      end
      line['business'] = k1_form.line['B'].split("\n")[0]
      line[:id] = form(1040).ssn

      line[1] = 1_000_000
      l2 = k1_form.line[12]
      if form(1040).status.is('mfs')
        l2 += interview('Cost of spouse\'s section 179 eligible property:')
      end
      line[2] = l2
    end

    line[3] = 2_500_000
    line[4] = [ line[2] - line[3], 0 ].max
    l5_limit = [ line[1] - line[4], 0 ].max
    if has_form?(1040) && form(1040).status.is('mfs')
      l5_split = interview(
        "Fraction for section 179 deduction split with spouse:"
      )
      l5_limit = (l5_limit * l5_split.to_f).round
    end
    line[5] = l5_limit

    if for_partnership
      if forms('Asset').any? { |x| x.line['listed?'] }
        raise "No support for listed property"
      end

      non_listed_179_assets = forms('Asset').select { |x|
        !x.line['listed?'] && x.line["179?"]
      }

      line['6a', :all] = non_listed_179_assets.lines(:description)
      line['6b', :all] = non_listed_179_assets.lines(:amount)
      line['6c', :all] = non_listed_179_assets.lines(:amount)
    else
      line['6a'] = 'From Form 1065 Schedule K-1, line 12'
      line['6b'] = k1_form.line[12]
      line['6c'] = k1_form.line[12]
    end

    line[8] = (line['6c', :sum] + line['7c', :opt]).round
    line[9] = [ line[5], line[8] ].min
    if interview('Do you have a section 179 carryover from last year?')
      line[10] = interview('Enter your section 179 carryover amount:')
    end

    if for_partnership
      line[11] = [ line[5], form(1065).line[8] ].min
    else
      line[11] = [ line[5], k1_form.line[14] + form(1040).line[7] ].min
    end

    line[12] = [ line[11], sum_lines(9, 10) ].min
    if line[11] == line[12]
      line[13] = sum_lines(9, 10) - line[12]
    end

    line[22] = sum_lines(
      14, 15, 16, 17, '19a.g', '19b.g', '19c.g', '19d.g', '19e.g', '19f.g',
      '19g.g', '19h.g', '19i.g', '20a.g', '20b.g', '20c.g', 21
    ) + (has_form?(1065) ? line[12, :opt] : 0)

  end

end

