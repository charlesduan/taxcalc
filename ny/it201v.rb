require_relative '../tax_form'

class FormIT201V < TaxForm

  def year
    2023
  end
  NAME = 'IT-201-V'

  def compute
    it203 = form('IT-203')
    line[:year] = year
    copy_line(:first_name, it203)
    copy_line(:last_name, it203)
    copy_line(:ssn, it203)
    copy_line(:spouse_first_name, it203)
    copy_line(:spouse_last_name, it203)
    copy_line(:spouse_ssn, it203)
    copy_line(:home_address, it203)
    copy_line(:apt_no, it203)
    copy_line(:city, it203)
    copy_line(:state, it203)
    copy_line(:zip, it203)

    line[:amount] = it203.line[:payment]
  end
end
