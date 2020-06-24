require 'tax_form'
require 'form8995'
require 'form8995a'

class QBIManager < TaxForm

  def name
    'QBI Manager'
  end

  def year
    2019
  end

  class AbstractQBI
    def initialize(parent, amount, form)
      @qbi_manager, @amount, @form = parent, amount, form
      @sstb = @qbi_manager.interview(
        "Is your business #{name}, " +
        "EIN #{tin}, an SSTB (e.g., consulting)?"
      )
    end
    attr_reader :amount, :form, :sstb
    def to_s
      "<#{self.class} name=#{name} sstb=#{sstb}>"
    end
  end

  class PshipQBI < AbstractQBI

    def name
      form.line[:B].split(/\n/).first
    end
    def tin
      form.line[:A]
    end
  end

  attr_reader :qbi

  def compute

    f1040 = form(1040)

    # Find all QBI
    @qbi = []
    assert_no_forms('1099-MISC') # which would trigger a Schedule C
    forms('1065 Schedule K-1').each do |f|
      next unless f.line[1] != 0
      @qbi.push(PshipQBI.new(self, f.line[1], f))
    end
    assert_question(
      'Did you have REIT dividends or publicly traded partnership income?',
      false
    )

    # Exclude SSTB (consulting income) if the income threshold is exceeded
    line[:taxable_income] = f1040.line_8b - f1040.line_9;
    if line[:taxable_income] > f1040.status.qbi_max
      line[:sstb_excluded?] = true
      @qbi.reject!(&:sstb)
    end

    if @qbi.map(&:amount).inject(0, :+) <= 0
      line[:deduction] = BlankZero
      return
    end

    # 
    puts "Income is #{line[:taxable_income]}"
    if line[:taxable_income] <= form(1040).status.qbi_threshold
      line[:deduction] = compute_form(Form8995).line_15
    else
      line[:deduction] = compute_form(Form8995A).line_39
    end

  end

end

FilingStatus.set_param('qbi_threshold',
                       160_700, 321_400, 160_725, :single, :single)

FilingStatus.set_param('qbi_max',
                       210_700, 421_400, 210_725, :single, :single)

