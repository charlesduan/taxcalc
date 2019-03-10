require 'delegate'
require 'form_manager'
require 'interviewer'

class BlankNum < DelegateClass(Fixnum)
  def to_s
    self == 0 ? '-' : to_i.to_s
  end

  def -(num)
    res = to_i - num
    if num.is_a?(BlankNum) && res == 0
      return BlankZero
    else
      return res
    end
  end

  def +(num)
    res = to_i + num
    if num.is_a?(BlankNum) && res == 0
      return BlankZero
    else
      return res
    end
  end
end
BlankZero = BlankNum.new(0)


class TaxForm

  class Lines
    def initialize(form)
      @form = form
      @lines_data = {}
      @lines_order = []
    end

    attr_reader :form

    def each
      @lines_order.each do |l|
        yield(l, @lines_data[l])
      end
    end

    def line_name(line)
      "Form #{@form.name}, line #{line}"
    end

    def []=(*args)
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
    end

    def [](line, type = nil)
      line = line.to_s
      raise "Reached unimplemented value" if line == '-1'

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
          item = item.to_s.gsub("\n", "\\n")
          io.puts("#{prefix}#{item}")
          prefix = "\t#{'"'.ljust(line.length)}\t"
        end
      end
      io.puts()

    end

    def place_lines(*nums)
      nums.each do |num|
        num = num.to_s
        if @lines_order.include?(num)
          @lines_order.delete(num)
          @lines_order.push(num)
        end
      end
    end

  end

  def initialize(manager)
    @lines = Lines.new(self)
    @manager = manager
    @exportable = true
  end

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

  attr_accessor :exportable
  attr_accessor :manager

  def name
    raise "Abstract form class"
  end

  def line(*args)
    if args.count == 0
      @lines
    else
      @lines[*args]
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

  def forms(num)
    @manager.forms(num)
  end

  def assert_no_forms(*args)
    args.each do |num|
      if has_form?(num)
        raise "Form #{num} present but not implemented for #{name}"
      end
    end
  end

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

  def copy_line(l, form)
    line[l] = form.line[l] if form.line[l, :present]
  end

  def place_lines(*nums)
    line.place_lines(*nums)
  end

  def format_lines(format, *nums)
    format % nums.map { |l| line[l] }
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

  def with_form(name)
    if @manager.has_form?(name)
      yield(form(name))
    end
  end

  def with_or_without_form(name)
    if @manager.has_form?(name)
      yield(form(name))
    else
      yield(nil)
    end
  end

  def find_or_compute_form(name, form_class)
    if has_form?(name)
      return form(name)
    else
      @manager.compute_form(form_class)
    end
  end

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

  def set_name_ssn
    bio = form("Biographical")
    line[:name] = bio.line[:first_name] + ' ' + bio.line[:last_name]
    line[:ssn] = bio.line[:ssn]
  end

end

class MultiForm < Array
  def initialize(forms)
    super([ forms ].flatten)
  end

  def lines(*args)
    if args.empty?
      Lines.new(self)
    else
      Lines.new(self)[*args]
    end
  end

  def select(&block)
    MultiForm.new(super(&block))
  end

  class Lines
    def initialize(mf)
      @mf = mf
    end
    def [](line, type = nil)
      res = @mf.map { |f| f.line[line, type] }
      case type
      when :all then res.flatten
      when :sum then
        if res.empty?
          BlankZero
        else
          res.inject(:+)
        end
      when :present then res.any? && !res.empty?
      else
        if res.any? { |x| x.is_a?(Enumerable) }
          raise "Unexpected array in lines #{line}"
        end
        res
      end
    end
  end

  def export
    each { |f| f.export }
  end

end

class NamedForm < TaxForm
  def initialize(name, data)
    super(data)
    @name = name.to_s
    @exportable = false
  end

  def copy(new_manager)
    super(self.class.new(name, new_manager))
  end

  def name
    @name
  end

end
