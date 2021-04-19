require_relative 'models'
require_relative '../form_manager'
require 'json'

class Marking; class Controller

  def initialize(node_io)
    @forms = {}
    @current_form = nil
    @node_io = node_io
  end

  def send_cmd(cmd, args)
    @node_io.puts(JSON.generate({ 'cmd' => cmd, 'args' => args}))
  end

  def load(filename)
    open(filename) do |io| JSON.parse(io.read) end.each do |d|
      @forms[d['name']] = Form.new(d)
    end
  end

  def add_forms(filename)
    fm = FormManager.new('')
    fm.import(filename)
  end

  def select(form)
    raise "No form #{form}" unless @forms[form]
    @current_form = @forms[form]
  end

  def add_line(obj)
    @current_form.update(obj)
  end

  def remove_line(obj)
    @current_form.remove(obj['name']) do |removed_name|
      send_cmd('remove', :name => removed_name)
    end
  end

  def save(filename)
    open(filename, 'w') do |io|
      io.puts(JSON.pretty_generate(@forms.values.map(&:to_obj)))
    end
  end


end end
