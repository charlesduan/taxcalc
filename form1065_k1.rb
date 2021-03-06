require 'tax_form'

class Form1065K1 < TaxForm

  NAME = '1065 Schedule K-1'

  def year
    2020
  end

  def initialize(manager, partner_form)
    super(manager)
    @partner_form = partner_form
  end

  def copy(manager)
    super(Form1065K1.new(manager, @partner_form.copy(manager)))
  end

  def compute
    f1065 = form(1065)

    line['A/ein'] = f1065.line[:ein]
    line['B'] = [
      f1065.line[:name],
      f1065.line[:address],
      f1065.line[:city_zip]
    ].join("\n")
    line['C'] = f1065.line(:send_to!).sub(/\s+\d{5}(?:-\d{4})?$/, '')
    line['D'] = 'X' if f1065.line('B7.yes', :present)
    line['E/ssn'] = @partner_form.line['ssn']
    line['F'] = @partner_form.line['name']
    line['F.address'] = [
      @partner_form.line['address'],
      @partner_form.line['address2']
    ].join("\n")
    line["G.#{@partner_form.line['liability']}"] = 'X'
    line["H.#{@partner_form.line['nationality']}"] = 'X'
    line['I1'] = @partner_form.line['type']

    share = @partner_form.line['share']
    line['J.profit.beginning'] = "#{share * 100}%"
    line['J.profit.ending'] = "#{share * 100}%"
    line['J.loss.beginning'] = "#{share * 100}%"
    line['J.loss.ending'] = "#{share * 100}%"
    line['J.capital.beginning'] = "#{@partner_form.line['capital'] * 100}%"
    line['J.capital.ending'] = "#{@partner_form.line['capital'] * 100}%"

    confirm("Partnership #{f1065.line_name} has no liabilities.")
    line['K.nonrecourse.beginning'] = BlankZero
    line['K.nonrecourse.ending'] = BlankZero
    line['K.qualified.beginning'] = BlankZero
    line['K.qualified.ending'] = BlankZero
    line['K.recourse.beginning'] = BlankZero
    line['K.recourse.ending'] = BlankZero

    # Item L need not be completed if Schedule B, question 4 is yes, which we
    # confirmed in Form 1065.

    line['M.no'] = 'X'

    # This needs to change if there are any investments in the capital accounts;
    # currently there are not.
    line['N.beginning'] = BlankZero
    line['N.ending'] = BlankZero

    line[1] = (f1065.line['K1'] * share).round
    line[5] = (f1065.line['K5'] * share).round if f1065.line[:K5, :present]
    line[12] = (f1065.line['K12'] * share).round if f1065.line[:K12, :present]
    line[14] = (f1065.line['K14a'] * share).round
    line['14.code'] = 'A'
  end

end
