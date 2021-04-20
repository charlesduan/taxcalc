require_relative 'models'
require_relative '../form_manager'
require 'json'

class Marking; class Controller

  def initialize(node_io)
    @forms = {}
    @current_form = nil
    @node_io = node_io
  end

  def add_form(form)
    raise "Invalid form" unless form.is_a?(Form)
    @current_form = @forms[form.name] = form
  end

  def start
    send_cmd('loadPdf', {
      'form' => @current_form.name,
      'file' => @current_form.file,
      'lines' => @current_form.line_names,
    })
  end

  def send_cmd(cmd, args)
    @node_io.puts(JSON.generate({ 'command' => cmd, 'payload' => args}))
  end

  def cmd_addLineBox(args)
    line = args['toolbar']['line']
    page = args['page']
    pos = Position.new(page, args['pos'])

    line_obj = @current_form.line(line)
    if line_obj.nil?
      warn("Line #{line} not found in form #{@current_form.name}")
      line_obj = @current_form.add_line(line)
    end

    if line_obj.split? && args['toolbar']['split']
      new_id = line_obj.add_pos(pos)
      send_cmd('drawLineBox', {
        'id' => new_id, 'page' => page, 'pos' => pos.to_a
      })
      send_cmd('findNextSplitBox', {
        'line' => line, 'page' => page, 'pos' => pos.to_a
      })
    elsif !line_obj.split? && !args['toolbar']['split']

      # A split box is neither expected nor present
      send_cmd('removeLineBox', { 'id' => line }) unless line_obj.pos.nil?
      line_obj.add_pos(pos)
      send_cmd('drawLineBox', {
        'id' => line, 'page' => page, 'pos' => pos.to_a
      })
    else
      warn("Box and toolbar are out of sync as to split for line #{line}")
    end

  end

  def cmd_selectPage(args)
  end

  def cmd_removeLine(args)
    send_cmd('removeLineBox', { 'id' => args['id'] })
  end

  def cmd_lineChanged(args)
  end

  def cmd_splitChanged(args)
  end

  def cmd_splitSepChanged(args)
  end

end end
