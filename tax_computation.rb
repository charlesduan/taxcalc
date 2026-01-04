require_relative 'tax_table'
require_relative 'tax_form'
require_relative 'form5329'

class TaxComputation < TaxForm

  NAME = "Tax Computation"

  def year
    2024
  end


  def compute

    @f1040 = form(1040)
    @status = @f1040.status

    # Form for rich kids (under 24)
    if age < 24
      raise "Form 8615 is not implemented"
    end

    line[:tax] = with_form('1040 Schedule D', otherwise: proc {
      compute_no_schedule_d
    }) do |sched_d|
      compute_with_schedule_d(sched_d)
    end
  end

  def compute_with_schedule_d(sched_d)
    if sched_d.line['compute_d_tax', :present]
      line[:tax_method] = 'Sch D'
      return compute_tax_schedule_d # Not implemented; raises error
    elsif sched_d.line['compute_qdcgt_tax', :present]
      line[:tax_method] = 'QDCGTW'
      return compute_tax_qdcgt
    else
      compute_no_schedule_d
    end
  end

  def compute_no_schedule_d
    if @f1040.line[:qualdiv, :present] or @f1040.line[:cap_gain, :opt] != 0
      line[:tax_method] = 'QDCGTW'
      return compute_tax_qdcgt
    else
      return compute_tax_standard(@f1040.line[:taxinc])
    end
  end

  def compute_tax_standard(income)
    if income < 100_000
      line[:tax_method] = 'Table' unless line[:tax_method, :present]
      return compute_tax_table(income, @status)
    else
      line[:tax_method] = 'TCW' unless line[:tax_method, :present]
      return compute_tax_worksheet(income)
    end
  end

  include TaxTable # This adds compute_tax_table

  def compute_tax_worksheet(income)
    raise 'Worksheet not applicable for less than $100,000' if income < 100_000
    brackets = @status.tax_brackets
    raise "Cannot compute tax worksheet for your filing status" unless brackets
    brackets.each do |limit, rate, subtract|
      next if limit && income > limit
      return (income * rate - subtract).round
    end
    raise "No suitable tax bracket found"
  end

  def compute_tax_qdcgt
    f = compute_form('1040 QDCGT Worksheet')
    return f.line[:tax]
  end

end

class QdcgtWorksheet < TaxForm
  NAME = '1040 QDCGT Worksheet'

  def year
    2024
  end

  def compute
    @f1040 = form(1040)
    confirm("You have no foreign income")

    line[1] = @f1040.line[:taxinc]
    line[2] = @f1040.line[:qualdiv]
    if has_form?('1040 Schedule D')
      sched_d = form('1040 Schedule D')
      line['3yes'] = 'X'
      line[3] = [
        0, [ sched_d.line[:lt_gain], sched_d.line[:tot_gain] ].min
      ].max
    else
      line['3no'] = 'X'
      line[3] = @f1040.line[:cap_gain]
    end

    line['4/tot_qdcg'] = line[2] + line[3] # Total qualdiv and cap gains
    line['5/inc_no_qdcg'] = line[1] - line[4] # Income excluding qualdiv/capgain

    line[6] = @f1040.status.qdcgt_exemption
    line[7] = [ line[1], line[6] ].min  # Exemption, limited by income
    line[8] = [ line[5], line[7] ].min  # Non-qdcg income, up to exemption
    line[9] = line[7] - line[8]         # Some non-qdcg income is exempt
    line[10] = [ line[1], line[4] ].min # Lesser of income and qdcg
    line[11] = line[9]
    line[12] = line[10] - line[11]      # What's left after exemption

    line[13] = @f1040.status.qdcgt_cap
    line[14] = [ line[1], line[13] ].min # 15% rate cap limited by income
    line[15] = line[5] + line[9]         # Non-qdcg income plus line 9 exemption
    line[16] = [ line[14] - line[15], 0 ].max # Phase-out of 15% rate cap
    line[17] = [ line[12], line[16] ].min # qdcg income limited by 15% cap
    line[18] = (line[17] * 0.15).round    # 15% tax
    line[19] = line[9] + line[17]         # qdcg income accounted for so far
    line[20] = line[10] - line[19]        # qdcg income left to account for
    line[21] = (line[20] * 0.20).round    # taxed at 20% rate

    ftc = form('Tax Computation')
    line[22] = compute_more(ftc, :tax_standard, line[5])
    line[23] = sum_lines(18, 21, 22)
    line[24] = compute_more(ftc, :tax_standard, line[1])

    line['25/tax'] = [ line[23], line[24] ].min
  end
end

FilingStatus.set_param('qdcgt_exemption',
                       single: 47_025, mfj: 94_050, mfs: :single,
                       hoh: 63_000, qw: :mfj)
FilingStatus.set_param('qdcgt_cap',
                       single: 518_900, mfj: 583_750,
                       mfs: 291_850, # not :half_mfj?
                       hoh: 551_350, qw: :mfj)

# A one-liner that will convert the tables of the tax brackets worksheet into
# the appropriate forms below:
#
# perl -ne 's/,//g; /(?:not over \$(\d+).*)? \((0\.\d+)\).*\$ *([\d.]+)/; $a = $1 || 'nil'; print "[ $a, $2, $3 ],\n"'
#
FilingStatus.set_param(
  'tax_brackets',
  single: nil,
  mfj: [
    [ 201050, 0.22, 9894.00 ],
    [ 383900, 0.24, 13915.00 ],
    [ 487450, 0.32, 44627.00 ],
    [ 731200, 0.35, 59250.50 ],
    [ nil, 0.37, 73874.50 ],
  ],
  mfs: nil,
  hoh: nil,
  qw: nil
)

