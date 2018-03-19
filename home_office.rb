#!/usr/bin/ruby

if __FILE__ == $0
  $LOAD_PATH.push(File.dirname(__FILE__))
  require 'form_manager'
end

class HomeOfficeManager < TaxForm

  def name
    'Home Office Manager'
  end

  def compute
    forms('Home Office').each do |ho_form|
      case ho_form.line['type'].downcase
      when 'partnership', 'partner'
        compute_partnership(ho_form)
      else
        raise "Cannot handle home office for #{ho_form.line['type']}"
      end
    end
  end

  def compute_partnership(ho_form)
    unless ho_form.line['method'] == 'simplified'
      raise 'Actual home office expense method not implemented'
    end

    forms('1065 Schedule K-1').each do |k1_form|
      next unless k1_form.line['A'] == line['ein']
      f = @manager.compute_form(
        Pub587SimplifiedWorksheet.new(@manager, k1_form)
      )
      line[:upe, :add] = f.line[:fill] if f.line[:fill] != 0
      return
    end
    raise "No matching 1065 Schedule K-1 for Home Office form"
  end

end

class Pub587SimplifiedWorksheet < TaxForm

  def name
    'Publication 587 Simplified Method Worksheet'
  end

  def initialize(manager, income_form)
    super(manager)
    @income_form = income_form
  end

  def compute

    ho_form = form('Home Office')

    line[1] = compute_gross_income_limitation

    line[2] = [ ho_form.line[:sqft], 300 ].min

    line['3a'] = 5
    if ho_form.line['daycare?']
      raise 'Day care home office not implemented'
    else
      line['3b'] = 1.0
    end
    line['3c'] = (line['3b'] * line['3a']).round(2)

    line[4] = (line[2] * line['3c']).round

    line[5] = [ [ line[1], line[4] ].min, 0 ].max

    line[:fill] = line[5]

  end

  def compute_gross_income_limitation

    unless @income_form.name = '1065 Schedule K-1'
      raise 'Home office deduction for non-partnerships not implemented'
    end

    line['1A'] = @income_form.sum_lines(1, 2, 3, 4, 5, '6a', '6b', 7, 11)
    line['1B'] = @income_form.sum_lines(8, '9a', '9b', '9c', 10)
    line['1C'] = sum_lines('1A', '1B')
    assert_question(
      'Do you have unreimbursed partnership expenses (other than home office)?',
      false
    )
    line['1D'] = 0
    %w(8 9a 9b 9c 10).each do |l|
      if @income_form.line[l, :present] && @income_form.line[l] < 0
        raise 'Partnership losses for home office not implemented'
      end
    end
    line['1E'] = 0
    line['1F'] = sum_lines('1D', '1E')
    line['1G'] = line['1C'] - line['1F']
    return line['1G']
  end

end
