require 'tax_form'
require 'interviewer'

class FormManager

  def initialize(name = nil)
    @name = name
    @forms = {}
    @ordered_forms = []
    @interviewer = Interviewer.new
  end

  attr_reader :name

  def export_all(all = false)
    @ordered_forms.each do |f|
      f.export if all || f.exportable
    end
  end

  attr_accessor :interviewer

  def add_form(form)
    name = form.name
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

  def copy_form(other_form)
    new_form = other_form.copy(self)
    add_form(new_form)
    return new_form
  end

  def compute_form(f)
    f = f.new(self) if f.is_a?(Class)
    puts "Computing form #{f.name}#{" for " + @name unless @name.nil?}"
    f.compute
    unless f.needed?
      return nil
    end
    add_form(f)
    return f
  end

  def has_form?(name)
    @forms.include?(name)
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
    MultiForm.new(@forms[name] || [])
  end

  def import(file)
    open(file) do |io|
      until io.eof?
        line = io.gets
        next unless (line && line =~ /\w/)
        raise "Invalid start of form" unless (line =~ /^(Form|Table) /)
        type = $1
        name = $'.strip
        new_form = NamedForm.new(name, self)
        if type == 'Table'
          new_form.import_tabular(io)
        else
          new_form.import(io)
        end
        add_form(new_form)
      end
    end
  end

  def interview(prompt, form = nil)
    @interviewer.ask(prompt, form)
  end

end

