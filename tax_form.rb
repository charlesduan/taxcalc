require 'delegate'
require 'date'

require_relative 'form_manager'
require_relative 'interviewer'
require_relative 'blank_zero'

#
# Represents a single form in a tax return. This class is intended to be
# subclassed for particular forms. A proper subclass should implement the
# following:
#
# - A constant +NAME+ that is a string identifying the class
#
# - A method +compute+ that performs computations for the form
#
# - A method +needed?+ that determines whether this form should be included on a
#   return
#
# - A method +year+ that specifies the year for which this object's computations
#   have been updated
#
# Additional computation methods should follow the naming convention
# *compute_[name]*.
#
class TaxForm

  #
  # Register subclasses by their names.
  #
  FORM_TYPES = {}
  UNREGISTERED_FORMS = []
  def self.inherited(subclass)
    UNREGISTERED_FORMS.push(subclass)
  end

  def self.by_name(name)
    UNREGISTERED_FORMS.each do |subclass|
      n = subclass.const_get(:NAME).to_s
      if FORM_TYPES[n]
        raise "Duplicate TaxForm type #{n} (#{subclass})"
      else
        FORM_TYPES[n] = subclass
      end
    end
    UNREGISTERED_FORMS.clear

    res = FORM_TYPES[name.to_s]
    raise "Unknown Form #{name.to_s}" unless res
    return res
  end

  def initialize(manager)

    # The form lines in this form
    @lines = Lines.new(self)

    @manager = manager
    @exportable = true
    @used = false
  end

  #
  # Whether this form has been used for any purpose. This is for
  # error-checking to ensure that forms have not been unprocessed.
  #
  attr_accessor :used

  #
  # Whether this form should be exported (basically everything but a
  # NamedForm).
  #
  attr_accessor :exportable

  #
  # The FormManager associated with this form.
  #
  attr_accessor :manager

  #
  # Returns the name of this form as given in the TaxForm::NAME constant.
  # Subclasses should redefine the constant appropriately.
  #
  def name
    return self.class.const_get(:NAME)
  end

  #
  # The year that this TaxForm was last updated. Subclasses should override this
  # method to return the year that the class was last updated.
  #
  def year
    warn "Form #{name} has no year set"
    return 0
  end

  #
  # Whether the form is needed to be included in the completed return. This
  # method should be overridden by subclasses. At the moment, when this method
  # returns true, the form is removed from the manager, but it might be
  # preferable to keep it around with just a flag of some sort.
  #
  def needed?
    true
  end

  ########################################################################
  #
  # ACCESSING LINES OF THE FORM
  #
  ########################################################################

  #
  # Returns the value of a form line. Given no parameters, returns the
  # TaxForm::Lines object associated with this form, such that square bracket
  # notation can be used. Otherwise, passes any arguments as square-bracket
  # arguments to the TaxForm::Lines object.
  #
  def line(*args)
    if args.count == 0
      @lines
    else
      @lines[*args]
    end
  end

  #
  # An alternate way of accessing lines. If the given method is of the form
  # line_[name], then it will be converted to the call +line[name, *args]+.
  #
  def method_missing(sym, *args)
    if sym.to_s =~ /^line_?/
      l = $'
      if l =~ /=$/
        l = $`
        line[l] = *args
      else
        line[l]
      end
    else
      super(sym, *args)
    end
  end

  #
  # Sums a list of lines. The lines are not required to be present.
  #
  def sum_lines(*args)
    args.map { |l| line[l, :opt] }.sum
  end

  #
  # Copies a line value from another form.
  #
  def copy_line(l, form, from: nil)
    from ||= l
    return unless form.line[from, :present]
    if form.line[from, :all].count > 1
      line[l, :all] = form.line[from, :all]
    else
      line[l] = form.line[from]
    end
  end

  #
  # Rearranges lines already computed.
  #
  def place_lines(*nums)
    line.place_lines(*nums)
  end

  # Returns the SSN associated with this form. Generally this is the contents of
  # line :ssn, but some special cases are implemented.
  def ssn
    case name
    when 'W-2' then line[:a]
    when '1065 Schedule K-1' then line[:A]
    else line[:ssn]
    end
  end

  #
  # Returns the SSN of the person filing this return.
  #
  def my_ssn
    return forms('Biographical').find { |x|
      x.line[:whose] == 'mine'
    }.line[:ssn]
  end

  #
  # Returns the SSN of the spouse.
  #
  def spouse_ssn
    return forms('Biographical').find { |x|
      x.line[:whose] == 'spouse'
    }.line[:ssn]
  end

  #
  # Sets the :name and :ssn lines based on an appropriate Biographical form.
  #
  def set_name_ssn(lname = :ssn)
    set_name
    line[lname] = my_ssn
  end

  #
  # Sets the :name line based on an appropriate Biographical form.
  #
  def set_name(lname = :name)
    bio = forms('Biographical').find { |x|
      x.line[:whose] == 'mine'
    }
    names = bio.line[:first_name] + ' ' + bio.line[:last_name]
    with_form(1040) do |f|
      if f.sbio && f.status.is('mfj')
        names += ' & ' + f.sbio.line[:first_name] + ' ' + \
          f.sbio.line[:last_name]
      end
    end
    line[lname] = names
  end

  #
  # Given a hash where the keys represent line names, treats each of those lines
  # as a table where each line is a column, and adds the values of the hash as
  # the next row of that table. This is done by first ensuring that each line's
  # value is an array of an equal number of elements, and then appending the
  # values of the hash to each of those arrays. Consider, for example:
  #
  #   Line 1a: 3, 4, 5
  #   Line 1b: x, y
  #   Line 1c: 6
  #   Line 1d: a, b
  #
  # Calling add_table_row('1a' => 8, '1c' => 9, '1d' => 'c') would yield:
  #
  #   Line 1a: 3, 4, 5, 8
  #   Line 1b: x, y
  #   Line 1c: 6, -, -, 9
  #   Line 1d: a, b, -, c
  #
  # where a dash is BlankZero. (Lines are described above as "columns" of a
  # table because on IRS forms, usually that is how the lines are presented.)
  #
  # In using this method, it is important for one column of the table always to
  # contain data for every row. Otherwise, there is a possibility that the new
  # row will be packed in with another one. For example, if the above call were
  # changed to add_table_row('1c' => 9, '1d' => c), it would yield:
  # 
  #   Line 1a: 3, 4, 5
  #   Line 1b: x, y
  #   Line 1c: 6, -, 9
  #   Line 1d: a, b, c
  #
  # so now there appears to be a row of "5, -, 9, c" whereas the table should
  # have had "5, -, -, -" as a row of its own.
  #
  def add_table_row(hash)
    max_rows = hash.keys.map { |x|
      line[x, :present] ? line[x, :all].count : 0
    }.max
    hash.keys.each do |x|
      arr = line[x, :present] ? line[x, :all] : []
      line[x, :all] = arr + ([ BlankZero ] * (max_rows - arr.count) << hash[x])
    end
  end

  #
  # Given two lines acting as columns of a table, match a given value in the
  # first line and return the corresponding value in the second. If the value is
  # not found, executes the given block and/or returns the default value.
  #
  def match_table_value(l1, l2, find:, default: nil)
    if line[l1, :present]
      index = line[l1, :all].find_index(find)
      return line[l2, :all][index] if index
    end
    default ||= yield if block_given?
    return default
  end



  ########################################################################
  #
  # CONVENIENCE METHODS
  #
  ########################################################################

  #
  # Given a name, splits off the first and last names.
  #
  def split_name(name)
    if name =~ /\s+(\S+)\z/
      return [ $`, $1 ]
    else
      return [ name, nil ]
    end
  end

  #
  # Given a city-state-zip, split into parts.
  #
  def split_csz(csz)
    if csz =~ /,?\s+(\w\w),?\s+(\d{5}(?:-\d+)?)\z/
      return [$`, $1, $2]
    else
      raise "Could not parse city-state-zip #{csz}"
    end
  end

  #
  # Returns the current year. This is better than the subclasses' +year+ method
  # because it returns the correct year even if the form is out of date.
  #
  def this_year
    return @manager.year
  end


  ########################################################################
  #
  # INPUT AND OUTPUT
  #
  ########################################################################

  #
  # Copies this form to another FormManager.
  #
  def copy(new_manager_or_obj)
    if new_manager_or_obj.is_a?(FormManager)
      new_copy = self.class.new(new_manager_or_obj)
    else
      new_copy = new_manager_or_obj
    end
    new_copy.exportable = @exportable
    line.each do |lnum, val|
      if val.is_a?(Enumerable)
        new_copy.line[lnum, :all] = val.dup
      else
        new_copy.line[lnum] = val
      end
    end
    return new_copy
  end

  #
  # Imports a form from a IO stream.
  #
  def import(io = STDIN)
    last_line = nil
    io.each do |text|
      break if (text =~ /^\s*$/)
      line_no, data = text.strip.split(/\s+/, 2)
      data ||= ''
      data = Interviewer.parse(line_no == '"' ? last_line : line_no, data)
      if line_no == '"'
        line[last_line, :all] = [ line[last_line, :all], data ].flatten
      elsif data.is_a?(Enumerable)
        line[line_no, :all] = data
      else
        line[line_no] = data
      end
      last_line = line_no unless line_no == '"'
    end
  end

  #
  # Exports the form to the IO stream. This delegates to TaxForm::Lines#export.
  #
  def export(io = STDOUT)
    @lines.export(io)
  end

  #
  # Outputs an explanatory message during this TaxForm's computation.
  #
  def explain(text)
    if @manager.explaining?(self)
      STDERR.puts(text)
    end
  end



  ########################################################################
  #
  # ACCESSING OTHER FORMS
  #
  ########################################################################



  #
  # Convenience for FormManager#form.
  #
  def form(num, ssn: nil, &block)
    @manager.form(num, ssn: ssn, &block)
  end

  #
  # Convenience for FormManager#form.
  #
  def forms(num, ssn: nil, &block)
    @manager.forms(num, ssn: ssn, &block)
  end

  #
  # Convenience for FormManager#has_form?.
  #
  def has_form?(name)
    @manager.has_form?(name)
  end

  #
  # Convenience for FormManager.with_form
  #
  def with_form(*args, **params, &block)
    @manager.with_form(*args, **params, &block)
  end

  def with_forms(name)
    if @manager.has_form?(name)
      @manager.forms(name).each do |f|
        yield(f)
      end
    end
  end

  #
  # This performs a database join-like operation that identifies all forms of a
  # certain type that have a value in a line matching this form.
  #
  def match_forms(form_name, line_name, other_line_name = nil)
    other_line_name ||= line_name
    return forms(form_name) { |f|
      line[line_name] == f.line[other_line_name]
    }
  end

  #
  # Finds a single form that matches this form's given line. Line #match_forms,
  # but must return exactly one form.
  #
  def match_form(form_name, line_name, other_line_name = nil)
    fs = match_forms(form_name, line_name, other_line_name)
    if fs.count == 0
      raise "No Form #{form_name} matching #{name} on line #{line_name}"
    elsif fs.count > 1
      raise "Multiple Forms #{form_name} match #{name} on line #{line_name}"
    else
      return fs[0]
    end
  end

  ########################################################################
  #
  # COMPUTING OTHER FORMS
  #
  ########################################################################


  #
  # Convenience method for FormManager#compute_form.
  #
  def compute_form(name, *args, **params, &block)
    @manager.compute_form(name, *args, **params, &block)
  end

  #
  # Convenience method for FormManager#compute_more.
  #
  def compute_more(*args, **params)
    @manager.compute_more(*args, **params)
  end

  #
  # If a form is not present, computes it. Then returns the form and/or executes
  # the given block on the form.
  #
  # TODO: This method is problematic for a number of reasons: It fails to impose
  # a particular ordering of computations, and it sometimes computes forms
  # duplicatively (if a form is not needed, for example).
  #
  def find_or_compute_form(name)
    if has_form?(name)
      f = form(name)
    else
      f = compute_form(name)
    end
    yield(f) if block_given? and f
    return f
  end


  #
  # Conforms that no forms of the given types are present.
  #
  def assert_no_forms(*args)
    args.each do |num|
      if has_form?(num)
        raise "Form #{num} present but not implemented for #{name}"
      else
        @manager.ensure_no_forms(num)
      end
    end
  end

  #
  # Assert that the following lines are unfilled in any forms with the given
  # name.
  #
  def assert_no_lines(fnum, *lnums)
    lnums.each do |num|
      if forms(fnum).lines(num, :present)
        raise "Form #{fnum}, line #{num} present but not implemented in #{name}"
      end
    end
  end


  ########################################################################
  #
  # CONVENIENCE METHODS
  #
  ########################################################################

  #
  # Convenience method for FormManager#interview.
  #
  def interview(prompt)
    @manager.interview(prompt, self)
  end

  #
  # Convenience method for FormManager#confirm.
  #
  def confirm(prompt)
    @manager.confirm(prompt, self)
  end

  # Computes a person's age as of the end of the relevant tax year. Per the IRS
  # rule that a birthday on January 1 of a year counts as the last year, we
  # subtract one day from the birthday.
  def age(bio = nil)
    bio ||= form(1040).bio
    return year - (bio.line[:dob] - 1).year
  end

  #
  # Breaks lines in a long text at 80 characters (which coincidentally is the
  # right length for a full-page-width box).
  #
  def break_lines(text, linelen = 80)
    len = 0
    res = ''
    text.split(/(\s+)/).each do |part|
      if len + part.length > linelen || part =~ /\n/
        res = res.sub(/\s+\z/, '')
        res += "\n" if len > 0
        if part =~ /\s/
          len = 0
        else
          while part.length > linelen
            part, res = part[linelen..-1], res + part[0, linelen] + "\n"
          end
          len, res = part.length, res + part
        end
      else
        len += part.length
        res += part
      end
    end
    return res
  end

  def to_s
    "<Form #{name}>"
  end

  def inspect
    "<Form #{name}>"
  end
end




class TaxForm


  #
  # A collection of lines inside a TaxForm. This class implements the primary
  # accessors and setters for values in a form, enabling a syntax of
  # +form.line[2] = 100+ for example.
  #
  class Lines
    def initialize(form)
      @form = form
      @lines_data = {}
      @lines_order = []
      @aliases = {}
    end

    include Enumerable

    attr_reader :form

    def each
      @lines_order.each do |l|
        yield(l, @lines_data[l])
      end
    end

    def resolve_alias(line)
      line = line.to_s
      if @aliases[line]
        res = @aliases[line]
        if @form != @form.manager.currently_computing && res.start_with?(line)
          if @form.manager.currently_computing
            warn("In #{@form.manager.currently_computing.name}, use alias " +
                 "for Form #{@form.name}, line #{res}")
          else
            warn("For #{@form.manager.name}, use alias for " +
                 "Form #{@form.name}, line #{res}")
          end
        end
        return res
      end
      return @aliases[line] if @aliases[line]
      return line
    end

    def assign_aliases(line)
      parts = line.split('/')
      # If any of the parts are already aliases to anything other than this line
      # itself, there's an ambiguity that raises an error.
      parts.each do |p|
        if @aliases[p] && @aliases[p] != line
          raise "Ambiguous line alias #{line}"
        end
      end
      return unless parts.length > 1
      parts.each do |p|
        @aliases[p] = line
      end
    end

    def line_name(line)
      line = resolve_alias(line)
      "Form #{@form.name}, line #{line}"
    end

    def []=(*args)
      @form.used = true
      line, value = args.first.to_s, args.last
      type = args.count == 3 ? args[1] : nil
      case type
      when :all
        value = [ value ].flatten
        value = value.first if value.count == 1
      when :add
        value = [ @lines_data[line] || [], value ].flatten
        value = value.first if value.count == 1
      else
        unless type == :overwrite
          warn("Overwriting value for #{line_name(line)}") if @lines_data[line]
        end
        if value.is_a?(Enumerable)
          raise "#{line_name(line)}: not expecting an array"
        end
      end
      @lines_order.push(line) unless @lines_data[line]
      form.explain("    #{line}:  #{value.inspect}")
      @lines_data[line] = value
      assign_aliases(line)
    end

    def [](line, type = nil)
      line = resolve_alias(line)

      unless @lines_data.include?(line)
        return false if type == :present
        return BlankZero if type == :opt or type == :sum
        raise "#{line_name(line)} not defined"
      end
      data = @lines_data[line]
      case type
      when :present
        true
      when :all
        [ data ].flatten
      when :sum
        [ data ].flatten.inject(:+) || BlankZero
      else
        raise "Line #{line} is an array" if data.is_a?(Enumerable)
        data
      end
    end

    def export(io = STDOUT)

      io.puts("Form #{@form.name}")
      @lines_order.each do |line|
        data = @lines_data[line]
        prefix = "\t#{line}\t"
        [ data ].flatten.each do |item|
          item = item.strftime("%-m/%-d/%Y") if item.is_a?(Date)
          item = "'#{item}" if item.is_a?(String) && item =~ /\A\d+\z/
          item = item.to_s.gsub("\n", "\\n")
          io.puts("#{prefix}#{item}")
          prefix = "\t#{'"'.ljust(line.length)}\t"
        end
      end
      io.puts()

    end

    #
    # For any line numbers given, rearrange them such that they appear in the
    # given order.
    #
    def place_lines(*nums)
      nums.each do |num|
        num = resolve_alias(num)
        if @lines_order.include?(num)
          @lines_order.delete(num)
          @lines_order.push(num)
        end
      end
    end

  end
end


require_relative 'multi_form'
require_relative 'named_form'
