require 'tax_form'

# Withholding tax schedule, for reporting W-2 withholdings.
#
# This class does not compute the printed forms correctly (which must be
# produced as separate forms for every three entries), because the online form
# does not request the information in this way.
#
class FormD40WH < TaxForm

  def name
    'D-40WH'
  end

  def year
    2019
  end

  def compute
    forms = forms('W-2') { |f| f.line[15, :all].include?('DC') }
    forms += forms('1099-MISC') { |f| f.line[17, :all].include?('DC') }
    forms.each_with_index do |f, index|
      index += 1
      case f.name
      when 'W-2'
        add_table_row(
          "A.ein" => f.line(:b),
          "A.name" => f.line(:c),
          "B" => f.line(16),
          "C.amount" => f.line(17),
          "C.w-2" => "X"
        )
      else
        "Raise DC withholding form not implemented for #{f.name}"
      end
    end
    line['total'] = line['C.amount', :sum]
  end

end
