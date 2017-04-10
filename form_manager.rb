require 'tax_form'
require 'interviewer'

class FormManager

  def initialize
    @forms = {}
    @ordered_forms = []
    @interviewer = Interviewer.new
  end

  def export_all
    @ordered_forms.each do |f|
      f.export if f.exportable
    end
  end

  attr_accessor :interviewer

  def add_form(form)
    name = form.name
    if @forms[name]
      @forms[name] = [ @forms[name], form ].flatten
    else
      @forms[name] = form
    end
    @ordered_forms.push(form)
  end

  def compute_form(f)
    f = f.new(self) if f.is_a?(Class)
    add_form(f)
    f.compute
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

  def interview(prompt)
    @interviewer.ask(prompt)
  end

end

