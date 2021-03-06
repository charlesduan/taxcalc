require_relative 'models'
require_relative '../form_manager'
require_relative 'pdf_assembler'
require 'json'
require 'open-uri'

class Marking; class Controller

  def initialize(node_io)
    @forms = {}
    @current_form = nil
    @node_io = node_io
  end

  attr_reader :forms

  def load_posdata(file)
    @forms = YAML.load(open(file, &:read))
  end

  def import_forms(form_manager)
    form_manager.each do |tax_form|
      if @forms.include?(tax_form.name)
        form = @forms[tax_form.name]
      else
        form = @forms[tax_form.name] = Form.new(tax_form.name)
      end
      form.merge_lines(tax_form)
    end
  end

  def select_form(name)
    @current_form = @forms[name]
    raise "Unknown Form #{name}" unless @current_form.is_a?(Form)
  end

  def set_current_form_file(file, force: false)
    raise "No selected form" unless @current_form
    if @current_form.file
      raise "Refusing to overwrite form data; use 'force' option" unless force
    end
    @current_form.file = file
  end

  def download_current_form_file(dir:, url: nil, force: false)
    raise "No selected form" unless @current_form
    if @current_form.file
      raise "Refusing to overwrite form data; use 'force' option" unless force
    end
    shortname = @current_form.name.downcase.gsub(/\W+/, '-')
    filename = File.join(dir, "form#{shortname}.pdf")
    url ||= @current_form.file_url
    open(filename, 'w') do |io|
      io.write(URI.open(url, &:read))
    end
    set_current_form_file(filename, force: force)
  end

  def current_form_has_file?
    return !!@current_form.file
  end

  def select_pdf_pages(range, dir:, force: false)
    shortname = @current_form.name.downcase.gsub(/\W+/, '-')
    filename = File.join(dir, "form#{shortname}.pdf")
    command = [
      PdfAssembler::CPDF, '-merge', '-i', @current_form.file, range,
      '-o', filename
    ]
    IO.popen(command, :err => "/dev/null") do |io|
      puts io.read
    end

    unless @current_form.file == filename
      @current_form.file = filename
    end
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
    res = JSON.generate({ 'command' => cmd, 'payload' => args})
    puts "-> #{res}"
    @node_io.puts(res)
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

    return if pos.too_small?

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
      unless line_next.positioned?
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
    if line_obj.split?
      select_next_line(line_obj.name)
    else
      select_line(line_obj)
    end
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
      send_cmd('removeLineBox', 'id' => line_obj.name) if line_obj.positioned?
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
