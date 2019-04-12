require 'tax_form'

# Computes the foreign tax credit, including Form 1116 if necessary.

class ForeignTaxCredit < TaxForm

  def name
    "Foreign Tax Credit"
  end

  def year
    2018
  end

  def compute
    ftc = BlankZero
    ftc += forms('1099-INT').lines(6, :sum)
    ftc += forms('1099-DIV').lines(7, :sum)
    if ftc == 0
      line[:fill!] = 0
      return
    elsif ftc < form(1040).status.is('mfj') ? 600 : 300
      if interview(
        'Do your foreign taxes satisfy Form 1040 Schedule 3, Line 48?'
      )
        line[:fill!] = ftc
        return
      end
    end
    raise "Form 1116 not implemented"
  end

  def needed?
    line[:fill!] != 0
  end

end
