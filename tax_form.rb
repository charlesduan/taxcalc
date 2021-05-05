require 'delegate'
require 'date'

require_relative 'form_manager'
require_relative 'interviewer'
require_relative 'blank_zero'
require_relative 'boxed_data'

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

    return FORM_TYPES[name.to_s]
  end

  def initialize(manager)

    # The form lines in this form
    @lines = Lines.new(self)

    # The FormManager associated with this form
    @manager = manager

    # Whether this form should be exported (basically everything but a
    # NamedForm)
    @exportable = true

    # Whether this form has been used for any purpose. This is for
    # error-checking to ensure that forms have not been unprocessed.
    @used = false
  end

  attr_accessor :used
  attr_accessor :exportable
  attr_accessor :manager

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
      new_copy.box_line(lnum, *line.box_data(lnum)) if line.boxed?(lnum)
    end
    return new_copy
  end

  def name
    return self.class.const_get(:NAME)
  end

  def year
    warn "Form #{name} has no year set"
    return 0
  end

  def check_year
    if @manager.year && @manager.year != year
      warn("Form #{name} is for #{year}, but manager is #{@manager.year}")
    end
  end

  def line(*args)
    if args.count == 0
      @lines
    else
      @lines[*args]
    end
  end

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

  def sum_lines(*args)
    args.map { |l| line[l, :opt] }.inject(:+)
  end

  def has_line(num)
    @lines[num, :present]
  end

  def form(num)
    @manager.form(num)
  end

  def forms(num, &block)
    @manager.forms(num, &block)
  end

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

  def assert_form_unnecessary(form_name)
    assert_question("Does #{form_name} apply to you?", false)
  end

  def assert_question(question, answer)
    if interview(question) != answer
      raise 'Processing for that response is not implemented'
    end
  end

  def interview(prompt)
    @manager.interview(prompt, self)
  end

  def confirm(prompt)
    @manager.confirm(prompt, self)
  end

  def copy_line(l, form)
    line[l] = form.line[l] if form.line[l, :present]
  end

  def place_lines(*nums)
    line.place_lines(*nums)
  end

  def format_lines(format, *nums)
    format % nums.map { |l| line[l] }
  end

  #
  # Use when a line is presented as a series of character-width boxes.
  #
  def box_line(line, box, split = "")
    self.line.box(line, box, split)
  end

  def form_line_or(form_name, form_line, default)
    if @manager.has_form?(form_name)
      form(form_name).line(form_line)
    else
      default
    end
  end

  def has_form?(name)
    @manager.has_form?(name)
  end

  def with_form(name, otherwise_return: nil)
    if @manager.has_form?(name)
      return yield(form(name))
    else
      return otherwise_return
    end
  end

  def with_forms(name)
    if @manager.has_form?(name)
      @manager.forms(name).each do |f|
        yield(f)
      end
    end
  end

  def with_or_without_form(name)
    if @manager.has_form?(name)
      yield(form(name))
    else
      yield(nil)
    end
  end

  def compute_form(name, *args)
    f = @manager.compute_form(name, *args)
    yield(f) if block_given? and f
    return f
  end

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
      elsif data.is_a?(BoxedData)
        line[line_no] = data.data
        line.box(line_no, data.count, data.split)
      else
        line[line_no] = data
      end
      last_line = line_no unless line_no == '"'
    end
  end

  def export(io = STDOUT)
    @lines.export(io)
  end

  def needed?
    true
  end

  def explain(text)
    if @manager.explaining?(self)
      STDERR.puts(text)
    end
  end

  def set_name_ssn(lname = :ssn)
    set_name
    line[lname] = forms('Biographical').find { |x|
      x.line[:whose] == 'mine'
    }.line[:ssn]
  end

  def set_name
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
    line[:name] = names
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

  # Computes a person's age as of the end of the relevant tax year. Per the IRS
  # rule that a birthday on January 1 of a year counts as the last year, we
  # subtract one day from the birthday.
  def age(bio = nil)
    bio ||= form(1040).bio
    return year - (bio.line[:birthday] - 1).year
  end
end




########################################################################
#
# LINES CLASS
#
########################################################################


class TaxForm; class Lines
  def initialize(form)
    @form = form
    @lines_data = {}
    @lines_order = []
    @boxed_lines = {}
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
        warn("In #{@form.manager.currently_computing.name}, use alias for " +
             "Form #{@form.name}, line #{res}")
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
    when :add
      value = [ @lines_data[line] || [], value ].flatten
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

  def box(line, count, split = "")
    @boxed_lines[resolve_alias(line)] = [ count, split ]
  end

  def boxed?(line)
    @boxed_lines.include?(resolve_alias(line))
  end

  def box_data(line)
    @boxed_lines[resolve_alias(line)]
  end

  def embox(line)
    line = resolve_alias(line)
    raise "Not a boxed line" unless boxed?(line)
    data = self[line]
    bld = @boxed_lines[line]
    boxes = data.to_s.split(bld[1])
    if data.is_a?(Numeric)
      boxes.unshift(*([ "" ] * [ bld[0] - boxes.count, 0 ].max))
    else
      boxes = boxes[0, bld[0]]
    end
    return boxes
  end

  def export(io = STDOUT)

    io.puts("Form #{@form.name}")
    @lines_order.each do |line|
      data = @lines_data[line]
      prefix = "\t#{line}\t"
      if @boxed_lines[line]
        bld = @boxed_lines[line]
        io.puts("#{prefix}<#{bld[1]}|#{bld[0]}|#{data}>")
      else
        [ data ].flatten.each do |item|
          item = item.strftime("%-m/%-d/%Y") if item.is_a?(Date)
          item = item.to_s.gsub("\n", "\\n")
          io.puts("#{prefix}#{item}")
          prefix = "\t#{'"'.ljust(line.length)}\t"
        end
      end
    end
    io.puts()

  end

  def place_lines(*nums)
    nums.each do |num|
      num = resolve_alias(num)
      if @lines_order.include?(num)
        @lines_order.delete(num)
        @lines_order.push(num)
      end
    end
  end

end; end


require_relative 'multi_form'
require_relative 'named_form'
