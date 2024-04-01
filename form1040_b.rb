require_relative 'tax_form'

class Form1040B < TaxForm

  NAME = '1040 Schedule B'

  def year
    2023
  end

  def compute
    set_name_ssn

    forms('1099-INT').each do |f|
      if f.line[1, :present]
        add_table_row('1l' => f.line['name'], '1r' => f.line(1))
      end
    end

    forms('1099-OID').each do |f|
      # According to the Form 1099-OID instructions, this may not be correct
      # "depending on the type of debt instrument, the issue or acquisition date
      # and other factors."
      if f.line[1, :present]
        add_table_row('1l' => f.line['name'], '1r' => f.line(1))
      end
    end

    with_forms('1065 Schedule K-1') do |f|
      if f.line[5, :present]
        add_table_row('1l' => f.line[:B].split("\n")[0], '1r' => f.line[5])
      end
    end

    line[2] = line['1r', :sum]

    # Line 3
    confirm("You have no series EE or I savings bonds")

    line['4/ord_int'] = line[2] - line[3, :opt]

    line['5l', :all] = forms('1099-DIV').lines('name')
    line['5r', :all] = forms('1099-DIV').lines('1a')
    with_forms('1065 Schedule K-1') do |f|
      if f.line['6a', :present]
        add_table_row('1l' => f.line[:B].split("\n")[0], '1r' => f.line['6a'])
      end
    end

    line['6/ord_div'] = line['5r', :sum]

    if line[4] > 1500 or line[6] > 1500
      confirm("You had no financial accounts in a foreign country")
      line['7a.no'] = 'X'
      confirm("You had no relationship with a foreign trust")
      line['8.no'] = 'X'
    end

    return self
  end
end
