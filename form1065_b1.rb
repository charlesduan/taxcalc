require 'tax_form'

class Form1065B1 < TaxForm

  NAME = '1065 Schedule B-1'

  def year
    2024
  end

  def compute
    reportables = forms('Partner') { |f|
      f.line['share'] >= 0.5
    }
    entities = reportables.select { |f|
      !%w(Individual Estate).include?(f.line['type'])
    }
    individuals = reportables.select { |f|
      %w(Individual Estate).include?(f.line['type'])
    }

    raise 'Entities not implemented' unless entities.empty?

    line['name'] = form('Partnership').line('name')
    line['ein'] = form('Partnership').line('ein')

    line['II.i', :all] = individuals.lines('name')
    line['II.ii', :all] = individuals.lines('ssn')
    line['II.iii', :all] = individuals.lines('country')
    line['II.iv', :all] = individuals.lines('share').map { |x| "#{x * 100}%" }
  end

end
