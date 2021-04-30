require_relative 'tax_form'
require_relative 'asset_manager'

# Depreciation and amortization (and section 179 deduction)
class Form4562 < TaxForm

  NAME = '4562'

  def year
    2019
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
      line[2] = assets_179.map { |x|
        x.line['amount']
      }.inject(0, :+)

    else
      line[:name] = form(1040).full_name
      unless forms('1065 Schedule K-1').count == 1
        raise "Cannot handle multiple businesses"
      end
      line['business'] = k1_form.line['B'].split("\n")[0]

      #
      # This form is not needed unless line 12 is filled on a 1065 K-1.
      #
      return unless k1_form.line[12, :present]
      line[:id] = form(1040).line[:ssn]

      line[1] = 1_000_000
      l2 = k1_form.line[12]
      if form(1040).status.is('mfs')
        l2 += @manager.submanager(:spouse).forms('1065 Schedule K-1').lines(
          12, :sum
        )
      end
      line[2] = l2
    end

    line[3] = 2_500_000
    line[4] = [ line[2] - line[3], 0 ].max
    l5_limit = [ line[1] - line[4], 0 ].max
    if has_form?(1040) && form(1040).status.is('mfs')
      if @manager.submanager(:spouse).has_form?(4562)
        l5_limit = l5_limit - @manager.submanager(:spouse).form(4562).line[5]
        if l5_limit < 0
          raise "Form 4562, line 5 limit irreconcilable with spouse's"
        end
      else
        l5_split = interview(
          "Fraction for section 179 deduction split with spouse:"
        )
        if l5_split > 1
          raise "Fraction must be a decimal value"
        end
        l5_limit = (l5_limit * l5_split.to_f).round
      end
    end
    line[5] = l5_limit

    if for_partnership
      non_listed_179_assets = find_or_compute_form(
        'Asset Manager'
      ).assets_179_nonlisted
      line['6a', :all] = non_listed_179_assets.lines(:description)
      line['6b', :all] = non_listed_179_assets.lines(:amount)
      line['6c', :all] = non_listed_179_assets.lines(:amount)
    else
      line['6a'] = 'From Form 1065 Schedule K-1, line 12'
      line['6b'] = k1_form.line[12]
      line['6c'] = k1_form.line[12]
    end

    line[8] = (line['6c', :sum] + line[7, :opt]).round
    line[9] = [ line[5], line[8] ].min
    if @manager.submanager(:last_year).form(4562).line[13, :present]
      line[10] = @manager.submanager(:last_year).form(4562).line[13]
    end

    if for_partnership
      line[11] = [ line[5], form(1065).line[8] ].min
    else
      line[11] = [ line[5], k1_form.line[14] + form(1040).line[1] ].min
    end

    line[12] = [ line[11], sum_lines(9, 10) ].min
    if line[11] == line[12]
      line[13] = sum_lines(9, 10) - line[12]
    end

    # Line 12 is included for individuals but not partnerships
    line[22] = sum_lines(
      14, 15, 16, 17, '19a.g', '19b.g', '19c.g', '19d.g', '19e.g', '19f.g',
      '19g.g', '19h.g', '19i.g', '20a.g', '20b.g', '20c.g', 21
    ) + (has_form?(1065) ? line[12, :opt] : 0)

  end

  def needed?
    return line[22, :present]
  end

end

