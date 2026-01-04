require_relative 'tax_form'

class Form1040_2 < TaxForm

  NAME = '1040 Schedule 2'

  def year
    2024
  end

  def compute
    set_name_ssn

    assert_no_forms('1095-A') # Line 2; advance premium tax credit repayment
    line['1a/aptc'] = BlankZero

    line['1z'] = sum_lines(*('1a'..'1y'))

    amt_test = compute_form(
      "1040 Worksheet to See If You Should Fill In Form 6251"
    )
    if amt_test.line[:fill_yes, :present]
      line[2] = compute_form(6251).line[:amt_tax]
    end

    line['3/add_tax'] = sum_lines(1, 2)

    #
    # Part II
    #
    if has_form?('1040 Schedule SE')
      line[4] = forms('1040 Schedule SE').lines[:se_tax, :sum]
    end

    # Lines 5-7: unreported social security/medicare tax
    # Assumed that there were no tips earned
    forms('W-2').each do |f|
      if f.line[3, :opt] > 0 && f.line[4, :opt] == 0
        raise "Possibly need Form 8919"
      end
      if f.line[5, :opt] > 0 && f.line[6, :opt] == 0
        raise "Possibly need Form 8919"
      end
    end

    #
    # Additional tax on IRAs and retirement plans. Form 5329 should have been
    # computed prior to this line, such that it now contains a total amount.
    #
    with_form(5329) do |f|
      compute_more(f, :total)
      line[8] = f.line[:total!]
    end

    #
    # Additional Medicare tax
    #
    compute_form(8959) do |f8959|
      line[11] = f8959.line[:add_mc_tax]
    end

    # Net investment income tax
    compute_form(8960) do |f8960|
      line[12] = f8960.line[:niit]
    end

    line[13] = forms('W-2').sum { |w2|
      w2.match_table_value('12.code', 12, find: 'A', default: BlankZero) +
        w2.match_table_value('12.code', 12, find: 'B', default: BlankZero) +
        w2.match_table_value('12.code', 12, find: 'M', default: BlankZero) +
        w2.match_table_value('12.code', 12, find: 'N', default: BlankZero)
    }

    # HSA additional taxes.
    with_form(8889) do |f|
      line['17c'] = f.line[:hsa_tax_distrib]
      line['17d'] = f.line[:hsa_testing_tax]
    end

    line[18] = sum_lines(*"17a".."17z")

    # The 965 tax seems to have to do with shareholders of foreign corporations.

    line['21/other_tax'] = sum_lines(*4..19)
  end

  def needed?
    # Schedule 2 is needed, even if it reports zero, if the AMT computation is
    # performed.
    line[:add_tax] > 0 || has_form?(6251) || line[:other_tax] > 0
  end
end

