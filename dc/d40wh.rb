require 'tax_form'

class FormD40WH < TaxForm

  def name
    'D-40WH'
  end

  def compute
    w2s = forms('W-2')
    line['A.ein', :all] = w2s.lines('b')
    line['A.name', :all] = w2s.lines('c')
    line['B', :all] = w2s.lines(16)
    line['C', :all] = w2s.lines(17)
    line['C.W-2', :all] = w2s.map { |x| 'X' }
    line['C.state', :all] = w2s.lines(15)

    line['total'] = line['C', :sum]
  end

end
