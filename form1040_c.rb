require_relative 'tax_form'
require_relative 'form4562'
require_relative 'expense_manager'
require_relative 'home_office'

class Form1040C < TaxForm

  NAME = '1040 Schedule C'

  include HomeOfficeManager

  def year
    2020
  end

  def needed?
    return has_form?('Sole Proprietorship')
  end

  def compute

    unless has_form?('Sole Proprietorship')
      if has_form?('1099-MISC') or has_form?('1099-NEC')
        raise "No sole proprietorship form for 1099-MISC or -NEC"
      end
      return
    end

    @f1040 = form('1040')
    @sp = form('Sole Proprietorship')

    set_name_ssn
    line[:A] = @sp.line[:business]
    line[:B] = @sp.line[:code]
    line[:C] = @sp.line[:dba] if @sp.line[:dba, :present]
    line[:D] = @sp.line[:ein]
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
      if interview("Did you file you sole proprietorship Forms 1099?")
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

    #
    # Business expenses. First collect all the expense types.
    #
    initialize_expenses
    expense(8, 'Advertising')
    expense(9, 'Car')
    expense(10, 'Commissions')
    expense(11, 'Contracts')
    expense(12, 'Depletion')
    line[13] = @asset_manager.depreciation_total
    expense(14, 'Employee_Benefits')
    expense(15, 'Insurance')
    expense('16a', 'Mortgage_Interest')
    expense('16b', 'Other_Interest')
    expense(17, 'Professional_Services')
    expense(18, 'Supplies')
    expense(19, 'Employee_Plans')
    expense('20a', 'Rent_Equipment')
    expense('20b', 'Rent_Property')
    expense(21, 'Repairs')
    # I'm not sure how line 22 differs from 18
    expense(23, 'License')
    expense('24a', 'Travel')
    expense('24b', 'Meals')
    expense(25, 'Utilities')
    expense(26, 'Wages')

    line['27a'] = other_expenses_total

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

    line[:Part_V_type, :all] = @expenses
    line[:Part_V_amt, :all] = @expenses.map { |exp| @expense_manager.line[exp] }
    line[48] = line[:Part_V_amt, :sum]

  end

  def initialize_expenses
    @expenses = @expense_manager.line.to_a.map(&:first).reject { |x|
      x == 'fill!'
    }
  end

  def expense(line_no, category)
    if @expenses.include?(category)
      line[line_no] = @expense_manager.line[category]
      @expenses.delete(category)
    end
  end

  #
  # Assuming that all other @expenses values have been deleted by the expense()
  # method, this totals everything left.
  #
  def other_expenses_total
    @expenses.map { |x| @expense_manager.line[x] }.sum
  end

end
