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
    line['B'] = form(1065).line['name']
    line['F'] = @partner_form.line['name']
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
    line['K.nonrecourse'] = "#{share * 100}%"
    line['K.qualified'] = "#{share * 100}%"
    line['K.recourse'] = "#{share * 100}%"
    line['M.no'] = 'X'

    line[1] = (form(1065).line['K1'] * share).round
    line[14] = (form(1065).line['K14a'] * share).round
    line['14.code'] = 'A'
  end

end
