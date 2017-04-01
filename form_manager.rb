require 'tax_form'
require 'interviewer'

class FormManager

  def initialize
    @forms = {}
    @interviewer = Interviewer.new
  end

  attr_accessor :interviewer

  def add_form(form)
    name = form.name
    if @forms[name]
      @forms[name] = [ @forms[name], form ].flatten
    else
      @forms[name] = form
    end
  end

  def compute_form(f)
    f = f.new(self) if f.is_a?(Class)
    add_form(f)
    f.compute
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
        raise "Invalid start of form" unless line =~ /^Form /
        name = $'.strip
        new_form = NamedForm.new(name, self)
        new_form.import(io)
        add_form(new_form)
      end
    end
  end

  def interview(prompt)
    @interviewer.ask(prompt)
  end

end

