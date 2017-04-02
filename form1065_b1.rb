require 'tax_form'

class Form1065B1 < TaxForm

  def name
    '1065 Schedule B-1'
  end

  def compute
    reportables = forms('Partner').select { |f|
      f.line['share'] >= 0.5
    }
    entities = reportables.select { |f|
      !%w(Individual Estate).include?(f.line['type'])
    }
    individuals = reportables.select { |f|
      %w(Individual Estate).include?(f.line['type'])
    }

    raise 'Entities not implemented' unless entities.empty?

    line['II.i', :all] = individuals.lines('name')
    line['II.ii', :all] = individuals.lines('ssn')
    line['II.iii', :all] = individuals.lines('country')
    line['II.iv', :all] = individuals.lines('share').map { |x| "#{x * 100}%" }
  end

end
