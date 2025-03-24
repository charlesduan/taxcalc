require_relative 'tax_form'
require_relative 'form8949'

class Form1040D < TaxForm
  NAME = '1040 Schedule D'

  def year
    2024
  end

  def needed?
    has_form?(8949) or line[7] != 0 or line[15] != 0 or line[16] != 0
  end

  def compute
    Form8949.generate(@manager) unless has_form?(8949)

    forms_a = forms(8949) { |f| f.line[:A, :present] }
    if forms_a.empty?
      line['1b.h'] = BlankZero
    else
      line['1b.d'] = forms_a.lines('I.2d', :sum)
      line['1b.e'] = forms_a.lines('I.2e', :sum)
      line['1b.h'] = forms_a.lines('I.2h', :sum)
    end

    forms_b = forms(8949) { |f| f.line[:B, :present] }
    if forms_b.empty?
      line['2h'] = BlankZero
    else
      line['2d'] = forms_b.lines('I.2d', :sum)
      line['2e'] = forms_b.lines('I.2e', :sum)
      line['2h'] = forms_b.lines('I.2h', :sum)
    end

    # Assume there are none of these:
    # Form 6252: Installment sales
    # Form 4684: Casualties and thefts
    # Form 6781: Section 1251 contracts (non-equity options, futures contracts)
    # Form 8824: Like-kind exchanges of real property
    # Form 4797: Sale of business property
    # Form 2439: RIC or REIT undistributed capital gains

    line[5] = forms('1065 Schedule K-1').lines(8, :sum)

    if @manager.submanager(:last_year).has_form?('1040 Schedule D')
      last_d = @manager.submanager(:last_year).has_form?('1040 Schedule D')
      if last_d.line[21, :present]
        raise "Capital Loss Carryover not implemented"
      end
    end

    line[7] = line['1b.h'] + line['2h']

    forms_d = forms(8949) { |f| f.line[:D, :present] }
    if forms_d.empty?
      line['8b.h'] = BlankZero
    else
      line['8b.d'] = forms_d.lines('II.2d', :sum)
      line['8b.e'] = forms_d.lines('II.2e', :sum)
      line['8b.h'] = forms_d.lines('II.2h', :sum)
    end

    forms_e = forms(8949) { |f| f.line[:E, :present] }
    if forms_e.empty?
      line['9h'] = BlankZero
    else
      line['9d'] = forms_e.lines('II.2d', :sum)
      line['9e'] = forms_e.lines('II.2e', :sum)
      line['9h'] = forms_e.lines('II.2h', :sum)
    end

    line[12] = forms('1065 Schedule K-1').lines('9a', :sum)

    assert_no_lines('1099-DIV', '2a', '2b', '2c', '2d')
    line['15/lt_gain'] = line['8b.h'] + line['9h']

    line['16/tot_gain'] = line[7] + line[15]

    if line[16] > 0
      compute_lines_17_20
    else
      compute_line_21 if line[16] < 0
      compute_line_22
    end
  end

  def compute_lines_17_20
    unless line[15] > 0 && line[16] > 0
      line['17.no'] = 'X'
      compute_line_22
      return
    end

    line['17.yes'] = 'X'

    # These are lines 18 and 19
    confirm("You had no section 1202 exclusion or collectibles gain")
    line[18] = BlankZero
    confirm("You sold no real property with section 1250 gain")
    line[19] = BlankZero

    #
    # Note that I'm not accounting for the investment interest deduction on
    # Form 4952 here.
    #
    if line[18] == 0 && line[19] == 0
      line['20.yes/compute_qdcgt_tax'] = 'X'
    else
      line['20.no/compute_d_tax'] = 'X'
    end
  end

  def compute_line_21
    line[21] = [
      form(1040).status.halve_mfs(3000),
      -line[16]
    ].min
  end

  def compute_line_22
    if forms('1099-DIV').lines('1b', :sum) > 0
      line['22.yes/compute_qdcgt_tax'] = 'X'
    else
      line['22.no'] = 'X'
    end
  end

end
