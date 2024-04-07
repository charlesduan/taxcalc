require_relative '../tax_form'

class FormIT2 < TaxForm
  NAME = 'IT-2'
  def year
    2023
  end

  def initialize(manager, w2_1, w2_2)
    super(manager)
    @w2_1 = w2_1
    @w2_2 = w2_2
  end

  def compute
    w2 = @w2_1
    compute_w2(@w2_1, 'I')
    compute_w2(@w2_2, 'II') if @w2_2
  end

  def compute_w2(w2, pre)
    @pre = pre
    w2_copy_line(:a, w2)
    w2_copy_line(:b, w2)
    w2_copy_line(:c, w2)
    w2_copy_line(:address, w2)
    line["#{pre}.c_city"], line["#{pre}.c_state"], line["#{pre}.c_zip"] \
      = split_csz(w2.line[:csz])
    w2_copy_line(1, w2)
    w2_copy_line(8, w2)
    w2_copy_line(10, w2)
    w2_copy_line(11, w2)
    w2_copy_line('12.code', w2)
    w2_copy_line(12, w2)
    line["#{pre}.13ret"] = 'X' if w2.line['13ret?']
    w2_copy_line("14.code", w2)
    w2_copy_line(14, w2)

    if w2.line[15, :all].include?("NY")
      line["#{pre}.16a"] = w2.match_table_value(15, 16, find: "NY")
      line["#{pre}.17a"] = w2.match_table_value(15, 17, find: "NY")
    end
    other_state = w2.line[15, :all].reject { |x| x == "NY" }.first
    if other_state
      line["#{pre}.15b"] = other_state
      line["#{pre}.16b"] = w2.match_table_value(15, 16, find: other_state)
      line["#{pre}.17b"] = w2.match_table_value(15, 17, find: other_state)
    end
  end

  def w2_copy_line(l, form)
    copy_line("#@pre.#{l}", form, from: l)
  end
end
