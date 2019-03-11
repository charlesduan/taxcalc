require 'tax_form'

class Form1065K1 < TaxForm

  def initialize(manager, partner_form)
    super(manager)
    @partner_form = partner_form
  end

  def copy(manager)
    super(Form1065K1.new(manager, @partner_form.copy(manager)))
  end

  def name
    '1065 Schedule K-1'
  end


  def compute
    f1065 = form(1065)

    line['A'] = f1065.line['D']
    line['B'] = [
      f1065.line[:name],
      f1065.line[:address],
      f1065.line[:address2]
    ].join("\n")
    line['C'] = f1065.line('send')
    line['D'] = 'X' if f1065.line('B7.yes', :present)
    line['E'] = @partner_form.line['ssn']
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
    line['K.nonrecourse.beginning'] = "#{share * 100}%"
    line['K.nonrecourse.ending'] = "#{share * 100}%"
    line['K.qualified.beginning'] = "#{share * 100}%"
    line['K.qualified.ending'] = "#{share * 100}%"
    line['K.recourse.beginning'] = "#{share * 100}%"
    line['K.recourse.ending'] = "#{share * 100}%"
    line['M.no'] = 'X'

    line[1] = (f1065.line['K1'] * share).round
    line[5] = (f1065.line['K5'] * share).round if f1065.line[:K5, :present]
    line[12] = (f1065.line['K12'] * share).round if f1065.line[:K12, :present]
    line[14] = (f1065.line['K14a'] * share).round
    line['14.code'] = 'A'
  end

end
