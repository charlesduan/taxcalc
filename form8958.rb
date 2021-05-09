require 'tax_form'
require 'form1040_d'
require 'form1040_se'

########################################################################
#
# ALLOCATION OF TAX AMOUNTS BETWEEN CERTAIN INDIVIDUALS IN COMMUNITY PROPERTY
# STATES
#
# This form manages the division of community property tax forms between two
# spouses and then produces Form 8958 reflecting that division. To use it,
# create a FormManager that contains all forms belonging to the community.
# Compute this form, which will create two submanagers for self and spouse, each
# having forms appropriately divided. Add any additional forms to those
# submanagers and compute the 1040 returns for each. Then call compute_post to
# actually fill in Form 8958 based on the completed returns.
#
########################################################################

class Form8958 < TaxForm

  NAME = '8958'

  def year
    2020
  end

  attr_accessor :my_manager, :spouse_manager

  def initialize(manager, my_m = nil, sp_m = nil)
    super(manager)
    @my_manager = my_m || FormManager.new
    @spouse_manager = sp_m || FormManager.new

  end

  def compute
    compute_split_forms
  end

  def compute_post
    compute_8958_lines
    update_managers
  end

  #
  # Splits up the input forms. The instance variable @splits records all the
  # forms as split.
  #
  def compute_split_forms
    # Accounting for No Form records
    @manager.copy_no_forms(@my_manager)
    @manager.copy_no_forms(@spouse_manager)

    # Ensure that every form provided to the community is split in some way.
    @all_forms = @manager.all_forms
    @all_forms.delete(self)

    split_biographical

    # Set up itemization and filing status for the submanagers
    @itemize = interview('Do you want to itemize deductions?')
    @my_manager.interviewer.answer('Enter your filing status:', 'mfs')
    @my_manager.interviewer.answer('Do you want to itemize deductions?',
                                   @itemize ? 'yes' : 'no')

    @spouse_manager.interviewer.answer('Enter your filing status:', 'mfs')
    @spouse_manager.interviewer.answer('Do you want to itemize deductions?',
                                       @itemize ? 'yes' : 'no')


    # A table of all split_forms outputs
    @splits = {}
    %w(
      W-2 1099-INT 1099-DIV 1099-MISC 1099-NEC 1099-G 1099-B
      1065\ Schedule\ K-1 1098
      State\ Tax Charity\ Gift Estimated\ Tax
      Dependent Home\ Office
    ).each do |name|
      @splits[name] = split_forms(name)
    end

    unless @all_forms.empty?
      warn "These forms were not accounted for in Form 8958 computation:"
      @all_forms.each do |f| warn(f.name) end
      raise "Unaccounted forms in 8958 processing"
    end

  end

  #
  # Computes the Form 8958 contents. This is done after both spouses' 1040
  # returns have been computed.
  def compute_8958_lines
      
    # Form 8958 biographical information
    copy_line(:first_name, @my_bio)
    copy_line(:last_name, @my_bio)
    copy_line(:ssn, @my_bio)
    box_line(:ssn, 3, '-')
    line[:spouse_first_name] = @spouse_bio.line[:first_name]
    line[:spouse_last_name] = @spouse_bio.line[:last_name]
    line[:spouse_ssn] = @spouse_bio.line[:ssn]
    box_line(:spouse_ssn, 3, '-')

    my_name = "#{line[:first_name]} #{line[:last_name]}"
    spouse_name = "#{line[:spouse_first_name]} #{line[:spouse_last_name]}"

    line['B.ssn'] = line[:ssn]
    line['C.ssn'] = line[:spouse_ssn]

    enter_split(1, 'W-2', 1, :c)
    enter_split(2, '1099-INT', 1, :name)
    enter_split(3, '1099-DIV', '1a', :name)
    enter_split(4, '1099-G', 2, :payer)

    line[5, :all] = forms('1065 Schedule K-1').lines('B').map { |x|
      x.split("\n")[0]
    }.zip(forms('1065 Schedule K-1').lines('F')).map { |x| x.join(", ") }
    enter_split(5, '1065 Schedule K-1', 14)
    enter_split(5, '1099-MISC', 10, :payer)
    enter_split(5, '1099-NEC', 1, :payer)

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
    enter_split(8, '1065 Schedule K-1', 1)

    #
    # Page 2
    #

    line['B.ssn_2'] = line[:ssn]
    line['C.ssn_2'] = line[:spouse_ssn]

    if @my_manager.has_form?('1040 Schedule SE')
      my_se = @my_manager.form('1040 Schedule SE')
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
    end

    if @spouse_manager.has_form?('1040 Schedule SE')
      spouse_se = @spouse_manager.form('1040 Schedule SE')
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
    end

    enter_split(11, 'W-2', 2, :c)

    line[12, :add] = forms('W-2').lines('c').map { |x| "State tax: #{x}" }
    enter_split(12, 'W-2', 17)
    line[12, :add] = forms('State Tax').lines('name').map { |x|
      "State tax: #{x}"
    }
    enter_split(12, 'State Tax', 'amount')

    line[12, :add] = forms('1098').lines('lender').map { |x|
      "Home mortgage interest:\n#{x}"
    }
    enter_split(12, '1098', 1)

    line[12, :add] = forms('1098').lines('lender').map { |x|
      "Real estate taxes:\n#{x}"
    }
    enter_split(12, '1098', 10)

    line[12, :add] = forms('Charity Gift').lines('name').map { |x|
      "Gifts to charity:\n#{x}"
    }
    enter_split(12, 'Charity Gift', 'amount')

    line[12, :add] = forms('Estimated Tax').lines('confirm').map { |x|
      "Estimated tax, confirmation #{x}"
    }
    enter_split(12, 'Estimated Tax', 'amount')

  end

  #
  # Updates the individual's FormManager objects with relevant information,
  # including copies of this Form 8958 itself.
  def update_managers
    @my_manager.copy_form(self).exportable = true
    sf = @spouse_manager.copy_form(self)
    sf.exportable = true
    %w(first_name last_name ssn).each do |item|
      sf.line[item, :overwrite] = line["spouse_#{item}"]
      sf.line["spouse_#{item}", :overwrite] = line[item]
    end
  end


  def split_biographical
    bios = forms('Biographical')
    @my_bio = bios.find { |x| x.line[:whose] == 'mine' }
    @spouse_bio = bios.find { |x| x.line[:whose] == 'spouse' }
    raise "Did not find both Biographical forms" unless @my_bio && @spouse_bio

    @my_manager.copy_form(@my_bio)
    @my_manager.copy_form(@spouse_bio)

    @spouse_manager.copy_form(@my_bio).line[:whose, :overwrite] = 'spouse'
    @spouse_manager.copy_form(@spouse_bio).line[:whose, :overwrite] = 'mine'

    @all_forms.delete(@my_bio)
    @all_forms.delete(@spouse_bio)
  end

  #
  # Finds all forms of the given name, runs split_form on them, and returns an
  # array of the results. The return value is thus an array of two-element
  # arrays of forms.
  #
  # As a side effect, removes any identified forms from @all_forms, and if no
  # forms of the given type are created for one of the spouses, no_form is
  # called to indicate that no form of that type is present for that spouse.
  #
  def split_forms(form_name)
    res = forms(form_name).map { |f|
      @all_forms.delete(f)
      split_form(f)
    }
    if res.map(&:first).all?(&:nil?)
      @my_manager.no_form(form_name)
    end
    if res.map(&:last).all?(&:nil?)
      @spouse_manager.no_form(form_name)
    end
    return res
  end

  #
  # Enters values for the A, B, and C columns. this_line is the line on Form
  # 8958; form_name is the form from which values are to be drawn; form_line is
  # the line from which values are to be drawn. If name_line is given, then
  # values under that line are used as the identifier in the leftmost column.
  #
  def enter_split(this_line, form_name, form_line, name_line = nil)
    split_forms = @splits[form_name]
    if name_line
      line[this_line, :add] = forms(form_name).lines(name_line, :all)
    end
    line["#{this_line}A", :add] = forms(form_name).lines(form_line, :all)
    line["#{this_line}B", :add] = split_forms.map { |x|
      x.first ? x.first.line(form_line) : BlankZero
    }
    line["#{this_line}C", :add] = split_forms.map { |x|
      x.last ? x.last.line(form_line) : BlankZero
    }
  end

  #
  # Splits a form between the two tax returns. The form is checked for two
  # lines:
  #
  # - whose: A value indicating that this form primarily belongs to self or
  #          spouse. A variety of indicator terms is permitted.
  # - split: A list of lines in the form for which numeric values are to be
  #          split between the two returns.
  #
  # If no split value is given, then the form is copied to the return of the
  # spouse indicated in the whose line. Otherwise, two copies of the form are
  # made. For numeric-valued lines, the number is split evenly if the line is in
  # split; otherwise it is solely distributed to the spouse in the whose line.
  #
  # Returns a two-element array of the produced form for each return (nil being
  # returned in one of the array slots if no form was produced for one spouse).
  #
  def split_form(f)

    case f.line['whose', :opt]
    when 'me', 'mine', 'self'
      is_mine = true
    when 'spouse', 'hers', 'his', 'theirs', 'him', 'her', 'them', 'spouse\'s'
      is_mine = false
    else
      raise "Invalid 'whose' value in Form #{f.name}; use 'me' or 'spouse'"
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
