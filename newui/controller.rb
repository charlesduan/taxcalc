require_relative 'models'
require_relative '../form_manager'
require 'json'

class Marking; class Controller

  def initialize(node_io)
    @forms = {}
    @current_form = nil
    @node_io = node_io
  end

  def cmd_load(args)
    @forms = YAML.load(open(args['file'], &:read))
  end

  def import_forms(form_manager)
    @forms.each do |name, form|
      next unless form_manager.has_form?(name)
      form_manager.forms(name).each do |tax_form|
        form.merge_lines(tax_form)
      end
    end
  end

  def add_form(form_name, file)
    return if @forms[form_name]
    @current_form = @forms[form_name] = Form.new(form_name, file)
  end

  def select_form(name)
    @current_form = @forms[name]
  end

  def start
    send_cmd('loadPdf', {
      'form' => @current_form.name,
      'file' => File.absolute_path(@current_form.file),
      'lines' => @current_form.line_names,
    })
    select_next_line(nil)
  end

  def send_cmd(cmd, args)
    @node_io.puts(JSON.generate({ 'command' => cmd, 'payload' => args}))
  end

  def select_line(line)
    send_cmd('setToolbarInfo', {
      'line' => line.name,
      'split' => line.split?,
      'separator' => line.split? ? line.separator : nil
    })
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
      if line_obj.pos && line_obj.pos.page == page
        send_cmd('removeLineBox', { 'id' => line })
      end
      line_obj.add_pos(pos)
      send_cmd('drawLineBox', {
        'id' => line, 'page' => page, 'pos' => pos.to_a
      })
    else
      warn("Box and toolbar are out of sync as to split for line #{line}")
    end

    select_next_line(line)
  end

  def select_next_line(line = nil)
    lines = @current_form.lines
    if line
      line_next_index = (lines.find_index { |l| l.name == line } || -1) + 1
      lines = lines.rotate(line_next_index)
    end
    lines.each do |line_next|
      if line_next.no_pos?
        select_line(line_next)
        break
      end
    end
  end

  def draw_line_boxes(line)
    if line.split?
      (1 .. line.split_count).each do |i|
        send_cmd('drawLineBox', {
          'id' => line.split_id(i),
          'page' => line.pos(i).page, 'pos' => line.pos(i).to_a
        })
      end

    elsif line.pos
      send_cmd('drawLineBox', {
        'id' => line.name, 'page' => line.pos.page, 'pos' => line.pos.to_a
      })
    end
  end

  def cmd_selectPage(args)
    page = args['page']
    @current_form.lines.each do |line|
      next unless line.page == page
      draw_line_boxes(line)
    end
  end

  def cmd_removeLine(args)
    if args['id'] =~ /\[(\d+)\]\z/
      line, boxno = $`, $1.to_i
    else
      line, boxno = args['id'], nil
    end
    line_obj = @current_form.line(line)
    unless line_obj
      warn("No line object found for #{line}")
      return
    end
    line_obj.remove_pos(boxno).each do |id|
      send_cmd('removeLineBox', { 'id' => id })
    end
    select_line(line_obj)
  end

  def cmd_lineChanged(args)
    select_line(@current_form.line(args['line']))
  end

  def cmd_splitChanged(args)
    line_obj = @current_form.line(args['line'])
    unless line_obj
      warn("No line object found for #{args['line']}")
      return
    end
    if args['split']
      return if line_obj.split?
      send_cmd('removeLineBox', 'id' => line_obj.name) unless line_obj.no_pos?
      line_obj.make_split(args['separator'])
    else
      return unless line_obj.split?
      (1..line_obj.split_count).reverse_each do |i|
        send_cmd('removeLineBox', 'id' => line_obj.split_id(i))
      end
      line_obj.make_not_split
    end
    draw_line_boxes(line_obj)
    select_line(@current_form.line(args['line']))
  end

  def cmd_splitSepChanged(args)
    line_obj = @current_form.line(args['line'])
    unless line_obj && line_obj.split?
      warn("Non-split line #{args['line']} when split was expected")
      return
    end
    line_obj.separator = args['separator']
  end

  def cmd_save(args)
    file = args['file']
    open(file, 'w') do |io|
      io.write(@forms.to_yaml)
    end
  end

end end
