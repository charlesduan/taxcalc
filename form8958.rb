require 'tax_form'
require 'form1040_d'
require 'form1040_se'

class Form8958 < TaxForm

  def name
    '8958'
  end

  attr_accessor :my_manager, :spouse_manager

  def initialize(manager, my_m = nil, sp_m = nil)
    super(manager)
    @my_manager = my_m || FormManager.new
    @spouse_manager = sp_m || FormManager.new

  end

  def compute

    split_biographical

    itemize = interview('Do you want to itemize deductions?')

    @my_manager.interviewer.answer('Enter your filing status:', 'mfs')
    @my_manager.interviewer.answer('Do you want to itemize deductions?',
                                   itemize ? 'yes' : 'no')

    @spouse_manager.interviewer.answer('Enter your filing status:', 'mfs')
    @spouse_manager.interviewer.answer('Do you want to itemize deductions?',
                                       itemize ? 'yes' : 'no')

    split_w2 = split_forms('W-2')
    split_1099int = split_forms('1099-INT')
    split_1099div = split_forms('1099-DIV')
    split_1099g = split_forms('1099-G')
    split_1099b = split_forms('1099-B')
    split_k1 = split_forms('1065 Schedule K-1')
    split_1098int = split_forms('1098-INT')
    split_state_tax = split_forms('State Tax')
    split_charity = split_forms('Charity Gift')
    split_est_tax = split_forms('Estimated Tax')

    # These get split but don't show up on the form
    split_forms('Dependent')
    split_forms('Home Office')

    bio = form('Biographical')
    copy_line(:first_name, bio)
    copy_line(:last_name, bio)
    copy_line(:ssn, bio)
    copy_line(:spouse_first_name, bio)
    copy_line(:spouse_last_name, bio)
    copy_line(:spouse_ssn, bio)

    my_name = "#{line[:first_name]} #{line[:last_name]}"
    spouse_name = "#{line[:spouse_first_name]} #{line[:spouse_last_name]}"

    line['B.ssn'] = line[:ssn]
    line['C.ssn'] = line[:spouse_ssn]
    line[1, :all] = forms('W-2').lines('c')
    enter_split(1, 'W-2', split_w2, 1)

    line[2, :all] = forms('1099-INT').lines('name')
    enter_split(2, '1099-INT', split_1099int, 1)

    line[3, :all] = forms('1099-DIV').lines('name')
    enter_split(3, '1099-DIV', split_1099div, '1a')

    line[4, :all] = forms('1099-G').lines('name')
    enter_split(4, '1099-G', split_1099g, 2)

    line[5, :all] = forms('1065 Schedule K-1').lines('B').map { |x|
      x.split("\n")[0]
    }.zip(forms('1065 Schedule K-1').lines('F')).map { |x| x.join(", ") }
    enter_split(5, '1065 Schedule K-1', split_k1, 14)

    my_se = my_manager.compute_form(Form1040SE)
    spouse_se = spouse_manager.compute_form(Form1040SE)

    my_manager.compute_form(Form1040D)
    spouse_manager.compute_form(Form1040D)

    line[6, :all] = my_manager.forms(8949).lines('II.1a', :all) + \
      spouse_manager.forms(8949).lines('II.1a', :all)
    line['6A', :all] = my_manager.forms(8949).lines('II.1h', :all) + \
      spouse_manager.forms(8949).lines('II.1h', :all)
    line['6B', :all] = my_manager.forms(8949).lines('II.1h', :all) + \
      spouse_manager.forms(8949).map { |x| BlankZero }
    line['6C', :all] = my_manager.forms(8949).map { |x| BlankZero } + \
      spouse_manager.forms(8949).lines('II.1h', :all)

    line[8, :all] = forms('1065 Schedule K-1').lines('B').map { |x|
      x.split("\n")[0]
    }.zip(forms('1065 Schedule K-1').lines('F')).map { |x| x.join(", ") }
    enter_split(8, '1065 Schedule K-1', split_k1, 1)

    if my_se && my_se.line[12] > 0
      line[9, :add] = "Deduction for #{my_name}"
      line['9A', :add] = my_se.line[13]
      line['9B', :add] = my_se.line[13]
      line['9C', :add] = BlankZero
      line[10, :add] = "Tax for #{my_name}"
      line['10A', :add] = my_se.line[12]
      line['10B', :add] = my_se.line[12]
      line['10C', :add] = BlankZero
    end

    if spouse_se && spouse_se.line[12] > 0
      line[9, :add] = "Deduction for #{spouse_name}"
      line['9A', :add] = spouse_se.line[13]
      line['9B', :add] = BlankZero
      line['9C', :add] = spouse_se.line[13]
      line[10, :add] = "Tax for #{spouse_name}"
      line['10A', :add] = spouse_se.line[12]
      line['10B', :add] = BlankZero
      line['10C', :add] = spouse_se.line[12]
    end

    line[11, :all] = forms('W-2').lines('c')
    enter_split(11, 'W-2', split_w2, 2)

    line[12, :add] = forms('W-2').lines('c').map { |x| "State tax: #{x}" }
    enter_split(12, 'W-2', split_w2, 17)
    line[12, :add] = forms('State Tax').lines('name').map { |x|
      "State tax: #{x}"
    }
    enter_split(12, 'State Tax', split_state_tax, 'amount')

    line[12, :add] = forms('1098-INT').lines('lender').map { |x|
      "Home mortgage interest: #{x}"
    }
    enter_split(12, '1098-INT', split_1098int, 1)

    line[12, :add] = forms('1098-INT').lines('lender').map { |x|
      "Real estate taxes: #{x}"
    }
    enter_split(12, '1098-INT', split_1098int, 11)

    line[12, :add] = forms('Charity Gift').lines('name').map { |x|
      "Gifts to charity: #{x}"
    }
    enter_split(12, 'Charity Gift', split_charity, 'amount')

    line[12, :add] = forms('Estimated Tax').lines('confirm').map { |x|
      "Estimated tax, confirmation #{x}"
    }
    enter_split(12, 'Estimated Tax', split_est_tax, 'amount')

  end

  def split_biographical
    bio = form('Biographical')
    @my_manager.copy_form(bio).exportable = true
    spouse_bio = @spouse_manager.copy_form(bio)
    spouse_bio.exportable = true
    spouse_bio.line.each do |l, d|
      if l =~ /^spouse_/
        l_no_spouse = $'
        d_no_spouse = spouse_bio.line[l_no_spouse]
        spouse_bio.line[l, :overwrite] = d_no_spouse
        spouse_bio.line[l_no_spouse, :overwrite] = d
      end
    end
  end

  def split_forms(form_name)
    res = forms(form_name).map { |f| split_form(f) }
    if res.map(&:first).all?(&:nil?)
      @my_manager.no_form(form_name)
    end
    if res.map(&:last).all?(&:nil?)
      @spouse_manager.no_form(form_name)
    end
    return res
  end

  def enter_split(this_line, form_name, split_forms, form_line)
    line["#{this_line}A", :add] = forms(form_name).lines(form_line, :all)
    line["#{this_line}B", :add] = split_forms.map { |x|
      x.first ? x.first.line(form_line) : BlankZero
    }
    line["#{this_line}C", :add] = split_forms.map { |x|
      x.last ? x.last.line(form_line) : BlankZero
    }
  end

  def split_form(f)

    case f.line['whose']
    when 'me', 'mine', 'self'
      is_mine = true
    when 'spouse', 'hers', 'his', 'theirs', 'him', 'her', 'them', 'spouse\'s'
      is_mine = false
    else
      raise 'Invalid "whose" value; use "me" or "spouse"'
    end

    if f.line['split', :present]

      my_form = my_manager.copy_form(f)
      spouse_form = spouse_manager.copy_form(f)
      split = f.line['split', :all].map(&:to_s)

      if is_mine
        zero_form = spouse_form
      else
        zero_form = my_form
      end

      f.line.each do |l, v|
        next unless v.is_a?(Numeric)
        if split.include?(l.to_s)
          my_form.line[l, :overwrite] /= 2
          spouse_form.line[l, :overwrite] -= my_form.line[l]
        else
          zero_form.line[l, :overwrite] = BlankZero
        end
      end

      return [ my_form, spouse_form ]

    elsif is_mine
      return [ my_manager.copy_form(f), nil ]
    else
      return [ nil, spouse_manager.copy_form(f) ]
    end
  end


end
