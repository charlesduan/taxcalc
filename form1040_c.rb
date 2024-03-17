require_relative 'tax_form'
require_relative 'form4562'
require_relative 'expense_manager'
require_relative 'home_office'

class Form1040C < TaxForm

  NAME = '1040 Schedule C'

  include HomeOfficeManager

  def year
    2023
  end

  def initialize(manager, sole_proprietorship)
    super(manager)
    @sp = sole_proprietorship
    unless @sp.is_a?(TaxForm) and @sp.name == 'Sole Proprietorship'
      raise "Invalid Sole Proprietorship form given"
    end
  end

  def compute

    @f1040 = form('1040')

    #
    # This hasn't been updated since 2020, and the underlying premise has
    # changed a bit, since theoretically a single tax return can contain several
    # sole proprietorships each requiring a Schedule C. This form needs to be
    # updated accordingly; it will also be necessary to figure out how to
    # allocate the 1099 forms and business expenses to individual sole
    # proprietorships.
    #
    raise "Not updated since 2020"

    set_name_ssn
    line[:A] = @sp.line[:business]
    line[:B] = @sp.line[:code]
    line[:C] = @sp.line[:dba] if @sp.line[:dba, :present]
    line[:ein!] = @sp.line[:ein]
    line[:D] = @sp.line[:ein].gsub(/-/, '')
    line[:E_addr] = @sp.line[:address]
    line[:E_city_zip] = @sp.line[:city_zip]

    case @sp.line[:accounting].downcase
    when 'cash'    then line['F.1'] = 'X'
    when 'accrual' then line['F.2'] = 'X'
    else
      line['F.3'] = 'X'
      line['F.3.specify'] = @sp.line[:accounting]
    end

    if @sp.line[:materially_participated?]
      line['G.yes'] = 'X'
    else
      line['G.no'] = 'X'
    end

    if @sp.line[:start].year == self.year
      line['H'] = 'X'
    end

    @asset_manager = compute_form('Asset Manager')
    if @asset_manager.has_current_assets?
      @manager.compute_form(4562)
    end

    @asset_manager.attach_safe_harbor_election(self)

    @expense_manager = compute_form('Business Expense Manager')

    if @expense_manager.line[:Commissions, :present] \
        or @expense_manager.line[:Contracts, :present]
      line['I.yes'] = 'X'
      if interview("Did you need to file sole proprietorship Forms 1099?")
        line['J.yes'] = 'X'
      else
        line['J.no'] = 'X'
      end
    else
      line['I.no'] = 'X'
    end


    line[1] = forms('1099-MISC').lines(3, :sum) + \
      forms('1099-MISC').lines(10, :sum) + \
      forms('1099-NEC').lines(1, :sum)

    line[3] = line[1] - line[2, :opt]

    confirm("The sole proprietorship had no costs of goods sold")

    line[5] = line[3] - line[4, :opt]

    confirm("The sole proprietorship had no line 6 miscellaneous income")

    line[7] = sum_lines(5, 6)

    if @asset_manager.depreciation_total != 0
      line[13] = @asset_manager.depreciation_total
    end
    #
    # Business expenses. First collect all the expense types.
    #
    @expense_manager.fill_lines(self, {
      8 => 'Advertising',
      9 => 'Car',
      10 => 'Commissions',
      11 => 'Contracts',
      12 => 'Depletion',
      14 => 'Employee_Benefits',
      15 => 'Insurance',
      '16a' => 'Mortgage_Interest',
      '16b' => 'Other_Interest',
      17 => 'Professional_Services',
      18 => 'Supplies',
      19 => 'Employee_Plans',
      '20a' => 'Rent_Equipment',
      '20b' => 'Rent_Property',
      21 => 'Repairs',
      23 => 'Licenses',
      '24a' => 'Travel',
      '24b' => 'Meals',
      25 => 'Utilities',
      26 => 'Wages',
    }, other: '27a', continuation: false)

    line[28] = sum_lines(*%w(8 9 10 11 12 13 14 15 16a 16b 17 18 19 20a 20b 21
                         22 23 24a 24b 25 26 27a 27b))
    line[29] = line[7] - line[28]

    home_office_sole_proprietorship do |home_sf, biz_sf, amount|
      line[30] = amount
      line['30(a)'] = home_sf
      line['30(b)'] = biz_sf
    end

    line['31/net_profit'] = line[29] - line[30, :opt]

    if line[31] < 0
      raise "Sole proprietorship loss at-risk not implemented"
    end


    #
    # Cost of goods sold, part III, is assumed not necessary
    #

    if line[9, :present]
      raise "Vehicle information not implemented"
    end

    line[:Part_V_type, :all], line[:Part_V_amt, :all] = \
      @expense_manager.other_expenses
    line[48] = line[:Part_V_amt, :sum]

  end


end
