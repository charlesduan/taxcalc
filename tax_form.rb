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
        if value.is_a?(Enumerable)
          raise "#{line_name(line)}: not expecting an array"
        end
      end
      @lines_data[line] = value
      @lines_order.push(line)
    end

    def [](line, type = nil)
      line = line.to_s
      raise "Reached unimplemented value" if line == '-1'

      unless @lines_data.include?(line)
        return false if type == :present
        return BlankZero if type == :opt
        raise "#{line_name(line)} not defined"
      end
      data = @lines_data[line]
      case type
      when :present
        true
      when :all
        [ data ].flatten
      when :sum
        [ data ].flatten.inject(:+)
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
          io.puts("#{prefix}#{item}")
          prefix = "\t\t"
        end
      end
      io.puts()

    end

  end

  def initialize(manager)
    @lines = Lines.new(self)
    @manager = manager
    @exportable = true
  end

  attr_accessor :exportable

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
      unless forms(num).empty?
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
    value = interview("Does #{form_name} apply to you?")
    unless value == 'no'
      raise "#{form_name} is applicable but not implemented"
    end
  end

  def interview(prompt)
    @manager.interview(prompt)
  end


  def form_line_or(form_name, form_line, default)
    if @manager.has_form?(form_name)
      form(form_name).line(form_line)
    else
      default
    end
  end

  def import(io = STDIN)
    io.each do |text|
      break if (text =~ /^\s*$/)
      line_no, data = text.strip.split(/\s+/, 2)
      data = Interviewer.parse(data)
      if data.is_a?(Enumerable)
        line[line_no, :all] = data
      else
        line[line_no] = data
      end
    end
  end

  def export(io = STDOUT)
    @lines.export(io)
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
      when :sum then res.inject(:+)
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

  def name
    @name
  end

end
