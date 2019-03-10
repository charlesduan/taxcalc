require 'tax_form'
require 'interviewer'

class FormManager

  def initialize(name = nil)
    @name = name
    @forms = {}
    @no_forms = {}
    @ordered_forms = []
    @interviewer = Interviewer.new
    @explain = {}
  end

  attr_reader :name

  def export_all(io = STDOUT, all = false)
    @ordered_forms.each do |f|
      f.export(io) if all || f.exportable
    end
  end

  def each(&block)
    @ordered_forms.each(&block)
  end

  attr_reader :interviewer

  def empty?
    @forms.empty?
  end

  def add_form(form)
    name = form.name.to_s
    if @no_forms.include?(name)
      raise "Adding form #{name} after No Form flag given"
    end
    if form.manager != self
      raise 'Adding form, but wrong manager'
    end
    if @forms[name]
      @forms[name] = [ @forms[name], form ].flatten
    else
      @forms[name] = form
    end
    @ordered_forms.push(form)
  end

  def remove_form(form)
    if @forms[form.name] == form
      @forms.delete(form.name)
    else
      arr = @forms[form.name]
      arr.delete(form)
      case arr.count
      when 0 then @forms.delete(form.name)
      when 1 then @forms[form.name] = arr[0]
      end
    end
    @ordered_forms.delete(form)
  end


  def no_form(form)
    @no_forms[form.to_s] = 1
  end

  def copy_form(other_form)
    new_form = other_form.copy(self)
    new_form.exportable = false
    add_form(new_form)
    return new_form
  end

  def compute_form(f)
    f = f.new(self) if f.is_a?(Class)
    add_form(f)
    f.explain("Computing Form #{f.name} for #{name}")
    f.compute
    f.explain("Done computing Form #{f.name}")
    unless f.needed?
      f.explain("Removing Form #{f.name} as not needed")
      remove_form(f)
      return nil
    end
    return f
  end

  def has_form?(name)
    @forms.include?(name.to_s)
  end

  def list_forms
    @forms.keys.sort.each do |name|
      if @forms[name].is_a?(Enumerable)
        puts "#{name} (#{@forms[name].count})"
      else
        puts "#{name}"
      end
    end
  end

  def form(name)
    name = name.to_s
    raise "No form #{name}" unless @forms[name]
    raise "Multiple forms #{name}" if @forms[name].is_a?(Enumerable)
    @forms[name]
  end

  def forms(name)
    name = name.to_s
    unless @forms.include?(name) or @no_forms.include?(name)
      warn("Warning: No forms #{name} found for #{@name}.")
      @no_forms[name] = 1
    end
    MultiForm.new(@forms[name] || [])
  end

  def import(file)
    open(file) do |io|
      until io.eof?
        line = io.gets
        next unless (line && line =~ /\w/)
        next if line =~ /^\s*#/

        unless (line =~ /^((No )?Form|Table) /)
          raise "Invalid start of form"
        end
        type = $1
        name = $'.strip
        case type
        when 'Table'
          import_tabular(name, io)
        when 'No Form'
          @no_forms[name] = 1
          next
        when 'Form'
          new_form = NamedForm.new(name, self)
          new_form.import(io)
          add_form(new_form)
        else
          raise "Unknown form type #{type}"
        end
      end
    end
  end

  def import_tabular(name, io = STDIN)
    lines = nil
    io.each do |text|
      break if (text =~ /^\s*$/)
      unless lines
        lines = text.strip.split(/\s+/)
        next
      end
      elts = lines.zip(text.strip.split(/\s+/, lines.count)).map { |l, x|
        Interviewer.parse(l, x)
      }
      raise "Invalid table line #{text}" unless lines.count == elts.count

      new_form = NamedForm.new(name, self)
      lines.zip(elts).each do |l, e|
        new_form.line[l] = e
      end
      add_form(new_form)
    end
  end

  def interview(prompt, form = nil)
    @interviewer.ask(prompt, form)
  end

  def explain(form)
    @explain[form.to_s] = true
  end

  def explaining?(form)
    @explain.include?(form.name.to_s)
  end

end

