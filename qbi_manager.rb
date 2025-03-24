require_relative 'tax_form'
require_relative 'form8995'
require_relative 'form8995a'

#
# Computes the qualified business income deduction. This class should produce a
# line :deduction that will be entered on the appropriate line of Form 1040. It
# should also compute Form 8995 or 8995-A as appropriate.
#
class QBIManager < TaxForm

  NAME = 'QBI Manager'

  def year
    2024
  end

  #
  # Represents a possible QBI business.
  #
  class AbstractQBI
    def initialize(parent, amount, form)
      @qbi_manager, @amount, @form = parent, amount, form
      @sstb = is_sstb?
    end
    attr_reader :amount, :form, :sstb
    def to_s
      "<#{self.class} name=#{name} sstb=#{sstb}>"
    end

    def is_sstb?
      @qbi_manager.interview("Is your business #{name}, EIN #{tin}, an SSTB?")
    end
  end

  class PshipQBI < AbstractQBI

    def name
      form.line[:B].split(/\n/).first
    end
    def tin
      form.line[:ein]
    end

  end

  class SoleProprietorQBI < AbstractQBI
    def name
      form.line[:C, :present] ? form.line[:C] : form.line[:name]
    end
    def tin
      form.line[:ein!, :present] ? form.line[:ein!] : form.line[:ssn]
    end

  end

  attr_reader :qbi

  def compute

    f1040 = form(1040)

    # Find all QBI
    @qbi = []
    forms('1065 Schedule K-1').each do |f|
      next unless f.line[1] != 0
      @qbi.push(PshipQBI.new(self, f.line[1], f))
    end
    with_form('1040 Schedule C') do |sch_c|
      @qbi.push(SoleProprietorQBI.new(self, sch_c.line[:net_profit], sch_c))
    end

    confirm('You have no REIT dividends or publicly traded partnership income')

    #
    # The definition of taxable income is in the Form 8995-A instructions,
    # immediately under Specific Instructions.
    #
    line[:taxable_income] = f1040.line[:agi] - f1040.line[:deduction]

    #
    # Exclude SSTB (consulting income) if the income threshold is exceeded.
    #
    if line[:taxable_income] > f1040.status.qbi_max
      line[:sstb_excluded?] = true
      @qbi.reject!(&:sstb)
    end

    if @qbi.map(&:amount).sum <= 0
      line[:deduction] = BlankZero
    elsif line[:taxable_income] <= form(1040).status.qbi_threshold
      line[:deduction] = compute_form(8995).line[:deduction]
    else
      line[:deduction] = compute_form('8995-A').line[:deduction]
    end

  end

end

#
# Determines whether Form 8995-A is required. See Form 8995-A instrudctions,
# under "Who Can Take the Deduction," and Form 8995-A, line 3.
#
FilingStatus.set_param('qbi_threshold',
                       single: 191_950, mfj: 383_900, mfs: :single,
                       hoh: :single, qw: :single)

FilingStatus.set_param('qbi_max',
                       single: 241_950, mfj: 483_900, mfs: :single,
                       hoh: :single, qw: :single)

