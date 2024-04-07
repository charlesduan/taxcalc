require_relative '../tax_form'
require_relative 'ny_tax_table'
require_relative 'it2105-9'
require_relative 'it2'
require_relative 'it201v'

class FormIT203 < TaxForm

  include NYTaxTable

  NAME = 'IT-203'

  def year
    2023
  end

  def compute
    f1040 = form(1040)

    @bio = forms('Biographical').find { |x| x.line[:whose] == 'mine' }
    @sbio = forms('Biographical').find { |x| x.line[:whose] == 'spouse' }

    copy_line(:first_name, @bio)
    copy_line(:last_name, @bio)
    copy_line(:dob, @bio)
    copy_line(:ssn, @bio)

    if @sbio
      copy_line(:spouse_first_name, @sbio, from: :first_name)
      copy_line(:spouse_last_name, @sbio, from: :last_name)
      copy_line(:spouse_dob, @sbio, from: :dob)
      copy_line(:spouse_ssn, @sbio, from: :ssn)
    end

    copy_line('home_address', @bio)
    copy_line('apt_no', @bio)
    line[:city], line[:state], line[:zip] = split_csz(@bio.line[:city_zip])
    if line[:state] == 'NY'
      raise "NY county not set"
    end

    @status = f1040.status.name
    line["status.#{@status}"] = 'X'

    if has_form?('1040 Schedule A')
      line['B.yes'] = 'X'
    else
      line['B.no'] = 'X'
    end

    if f1040.line['ysd.dependent', :present]
      line['C.yes'] = 'X'
    else
      line['C.no'] = 'X'
    end

    with_form('1040 Schedule B', otherwise: proc {
      line['D1.no'] = 'X'
    }) do |sched_b|
      if line['7a.yes', :present]
        line['D1.yes'] = 'X'
      else
        line['D1.no'] = 'X'
      end
    end

    confirm('You had no living quarters in New York State')
    line['D2.1.no'] = 'X'
    line['H.no'] = 'X'

    forms('Dependent').each do |dep|
      fname, lname = split_name(dep.line[:name])
      add_table_row({
        'I.first_name' => fname,
        'I.last_name' => lname,
        'I.relationship' => dep.line[:relationship],
        'I.ssn' => dep.line[:ssn],
        'I.dob' => dep.line[:dob],
      })
    end
    if forms('Dependent').count > 6
      line['I.over_6_deps'] = 'X'
    end

    #
    # Page 2
    #
    # The following need to be checked to make sure that all NY income has
    # properly been accounted for.
    #

    line[:p2_ssn] = line[:ssn]
    line[1] = f1040.line[:wages]
    line['1.ny'] = forms('W-2') { |w2|
      w2.line[:state, :present] && w2.line[:state, :all].include?('NY')
    }.lines(1, :sum)

    copy_line(2, f1040, from: :taxable_int)
    copy_line(3, f1040, from: :taxable_div)
    with_form('1040 Schedule 1') do |sched_1|
      copy_line(4, sched_1, from: :taxrefund)
      copy_line(5, sched_1, from: :alimony)
      copy_line(6, sched_1, from: :bus_inc)
      copy_line(8, sched_1, from: :other_gains)
      copy_line(11, sched_1, from: :rrerpst)
      copy_line(18, sched_1, from: :adj_inc)
      if line[18] > 0
        line['18.expl', :all] = line_18_expl(sched_1)
      end
    end
    copy_line(7, f1040, from: :cap_gain)
    place_lines(8)
    copy_line(9, f1040, from: :taxable_ira)
    copy_line(10, f1040, from: :taxable_pension)
    place_lines(11)

    # Line 12
    confirm("You had no rental real estate income")

    # The other forms of income are inapplicable to me
    #
    inc_lines = (1..11).to_a | (13..16).to_a
    line[17] = sum_lines(*inc_lines)
    line['17.ny'] = sum_lines(*ny_lines(inc_lines))

    place_lines(18)
    place_lines('18.expl')
    copy_line('19/fed_agi', f1040, from: :agi)
    if line['fed_agi'] != line[17] - line[18]
      #puts "#{line['fed_agi']}, #{line[17] - line[18]}"
      raise "AGI computation was inconsistent"
    end
    line['19.ny'] = line['17.ny'] - line['18.ny', :opt]

    confirm('You have no NY additions or subtractions')
    line[23] = sum_lines(*19..22)
    line['23.ny'] = sum_lines(*ny_lines(19..22))
    line[30] = sum_lines(*24..29)
    line['30.ny'] = sum_lines(*ny_lines(24..29))
    line[31] = line[23] - line[30]
    line['31.ny'] = line['23.ny'] - line['30.ny']
    line['32/agi'] = line[31]

    #
    # Page 3
    #
    set_name(:p3_name)
    line[:p3_ssn] = line[:ssn]

    # Assume standard deduction
    line['33.std'] = 'X'
    line[33] = case @status
               when 'mfj' then 16_050
               else raise 'Not implemented'
               end
    line[34] = [ line[32] - line[33], BlankZero ].max
    line[35] = line['I.ssn', :all].count
    line[36] = line[34] - line[35] * 1000
    line[37] = line[36]

    line[38] = compute_tax(line[37], @status)

    if line[:agi] <= 32_000
      raise "NYS Household Credit not implemented"
    end
    line[40] = [ line[38] - line[39, :opt], BlankZero ].max

    # Line 41, dependent care credit, is not implemented because it's not worth
    # the time since any credit would simply be offset by the DC tax credit.
    line[41] = BlankZero
    line[42] = [ line[40] - line[41, :opt], BlankZero ].max

    # Line 43, earned income credit
    line[44] = [ line[42] - line[43, :opt], BlankZero ].max

    line['45.ny'] = line['31.ny']
    line['45.fed'] = line[31]
    line[45] = (line['45.ny'].to_f / line['45.fed']).round(4)
    line[46] = (line[44] * line[45]).round

    # Not computing credits since they will just be offset as above
    line[47] = BlankZero
    line[48] = line[46] - line[47]
    line[50] = sum_lines(48, 49)

    # NYC, Yonkers, MCTMT taxes
    line[55] = sum_lines('52a', '52f', 53, 54)

    # Being a nonresident, no sales tax owed
    line['56/use_tax'] = 0
    line['57/voluntary_contrib'] = BlankZero
    line['58/tot_tax'] = sum_lines(50, 55, 56, 57)

    #
    # Page 4
    #
    line[:p4_ssn] = line[:ssn]
    line[59] = line[58]

    forms('W-2').each_slice(2) do |w2s|
      compute_form('IT-2', *w2s)
    end

    wh = forms('W-2').map { |f|
      f.match_table_value(15, 17, find: 'NY', default: 0)
    }.sum
    wh += forms('1099-MISC').map { |f|
      f.match_table_value(15, 17, find: 'NY', default: 0)
    }.sum
    wh += forms('1099-NEC').map { |f|
      f.match_table_value(6, 5, find: 'NY', default: 0)
    }.sum
    line['62/nys_wh'] = wh
    line[66] = sum_lines(*60..65)

    if line[66] > line[59]
      line[67] = line[66] - line[59]

      # Refund applied to 2024 tax
      line[69] = BlankZero
      line[68] = line[67] - line[69]

      # NY 529 account
      line['68a'] = BlankZero
      line['68b'] = line[68] - line['68a']

      line['68.check'] = 'X'
      place_lines(69)
    else
      line[:tax_owed!] = line[59] - line[66]
      penalty = compute_form('IT-2105.9')
      if penalty
        line[71] = penalty.line[:amount]
      end
      line['70/payment'] = sum_lines(:tax_owed!, 71, 72)
      place_lines(71, 72)
      compute_form('IT-201-V')
    end

    line[:occupation] = @bio.line[:occupation]
    if @status == 'mfj'
      line[:spouse_occupation] = @sbio.line[:occupation]
    end
    copy_line('phone', @bio)
  end

  def ny_lines(range)
    range.to_a.map { |x| "#{x}.ny" }
  end

  def line_18_expl(sched_1)
    expls = []
    {
      :hsa_adj => "HSA",
      :se_tax_ded => "SE Tax Deduction",
      :se_ret => 'SE qualified plans',
      :ira_ded => 'IRA deduction',
    }.each do |l, text|
      next unless sched_1.line[l, :present]
      expls.push("#{text}: #{sched_1.line[l]}")
    end
    return expls
  end

end
