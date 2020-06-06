require 'tax_form'

# Childcare expense credit
class Form2441 < TaxForm

  def name
    '2441'
  end

  def year
    2019
  end

  def compute
    if form(1040).status.is('mfs')
      mfs_except = interview(
        'Did you live apart from your spouse for the last 6 months of the year?'
      )
      if mfs_except
        line[:mfs_except] = 'X'
      else
        line[:na!] = 'X'
        return
      end
    end
    raise 'Not implemented'
  end

  def needed?
    !line[:na!, :present]
  end

end
