#!/usr/bin/ruby

if __FILE__ == $0
  $LOAD_PATH.push(File.dirname(__FILE__))
  require 'form_manager'
end

require 'tk'
require 'tkextlib/tkimg/png'
require 'tkextlib/bwidget'
require 'tmpdir'
require 'tax_form'
require 'interviewer'
require 'biographical'

class PdfFileParser

  dir = File.dirname(__FILE__)
  entries = Dir.entries(dir)
  CPDF = entries.include?("cpdf") ? File.join(dir, "cpdf") : "cpdf"
  GS = entries.include?("gs") ? File.join(dir, "gs") : "gs"

  def popen(*args)
    IO.popen("-", 'r+:iso-8859-1') do |io|
      if io
        yield(io)
      else
        exec(*args.flatten)
      end
    end
  end

  def initialize(file)
    @file = file
    @resolutions = {}
    @tempdir = nil
  end

  attr_accessor :file

  def tempdir
    return @tempdir if @tempdir
    @tempdir = Dir.mktmpdir
    return @tempdir
  end

  def cleanup
    FileUtils.remove_entry(@tempdir) if @tempdir
  end

  def pages
    return @pages if @pages

    popen(CPDF, '-pages', @file) do |io|
      io.each do |line|
        if line =~ /^(\d+)$/
          @pages = $1.to_i
          break
        end
      end
    end
    raise "Can't get number of pages\n" unless @pages
    return @pages
  end


  def page_image(num, resolution)
    unless @resolutions[resolution]
      popen(
        GS, '-NODISPLAY', '-dSAFER', '-dBATCH', '-dNOPAUSE', '-sDEVICE=pngmono',
        "-r#{resolution}", "-sOutputFile=#{tempdir}/img-#{resolution}-%03d.png",
        @file
      ) do |io|
        io.each do |line|
        end
      end
      @resolutions[resolution] = true
    end
    page_file = "#{tempdir}/img-#{resolution}-#{"%03d" % num}.png"
    return nil unless File.exist?(page_file)
    return page_file
  end

  def fill_form(commands, new_file)
    command = [ CPDF, "-merge", @file ]
    commands.each do |cmd|
      command.push("AND", *cmd)
    end
    command.push("-o", new_file)
    popen(*command) do |io|
      io.each do |line|
        puts line
      end
    end
  end

end

class MarkingUI

  def initialize(parser, line_pos_data)

    @parser = parser
    @line_pos_data = line_pos_data
    @resolution = 144

    @root = TkRoot.new(title: "Mark Form Fields")

    initialize_top_frame
    initialize_canvas_frame
    load_image(1)

  end

  def to_page_coords(x1, y1, x2, y2)
    return [
      [ x1, x2 ].min,
      (@image.height - [ y1, y2 ].max),
      (x1 - x2).abs,
      (y1 - y2).abs
    ].map { |x| x * 72 / @resolution }.unshift(@page)
  end

  def to_screen_coords(pos)
    page, x, y, w, h = *pos
    return [
      x * @resolution / 72,
      @image.height - ((y + h) * @resolution / 72),
      (x + w) * @resolution / 72,
      @image.height - (y * @resolution / 72)
    ]
  end

  def canvas_coords(e)
    return @canvas.canvasx(e.x).round, @canvas.canvasy(e.y).round
  end

  def initialize_top_frame
    frame = TkFrame.new(@root)
    frame.pack(fill: 'x', expand: true, side: 'top')

    @prev_page_button = TkButton.new(
      frame, text: "< Previous Page",
      command: proc { load_image(@page - 1) }
    )
    @prev_page_button.pack(side: 'left')

    @next_page_button = TkButton.new(
      frame, text: "Next Page >",
      command: proc { load_image(@page + 1) }
    )
    @next_page_button.pack(side: 'left')

    lv = TkVariable.new(@line_pos_data.lines)

    @listbox = Tk::BWidget::ComboBox.new(
      frame, height: 8, values: @line_pos_data.lines
    )
    @listbox.clear_value
    advance_listbox
    @listbox.pack(side: 'left')

  end

  def initialize_canvas_frame

    frame = TkFrame.new(@root)
    frame.pack(fill: 'x', expand: true, side: 'top')

    @canvas = TkCanvas.new(
      frame,
      width: @resolution * 17 /2,
      height: 500,
      scrollregion: "0 0 #{@resolution * 17 / 2} #{@resolution * 11}"
    )
    @canvas.pack(fill: 'both', expand: 1, side: 'left')

    @canvas.itembind('image', 'Double-Button-1') { |e| process_click(e) }
    @canvas.itembind('rect', 'Double-Button-1') { |e| process_item_click(e) }
    @canvas.itembind('text', 'Double-Button-1') { |e| process_item_click(e) }
    @canvas.itembind('image', 'B1-Motion') { |e| process_drag(e) }
    @canvas.itembind('image', 'ButtonRelease-1') { |e| process_release(e) }

    @vscroll = TkScrollbar.new(frame) { orient 'vertical' }
    @canvas.yscrollbar(@vscroll)
    @vscroll.pack(side: 'left', fill: 'y', expand: 1)

    @canvas.bind("MouseWheel") do |e|
      @canvas.yview_scroll(-e.delta, "units")
    end
  end

  def process_item_click(e)
    item = @canvas.find_withtag('current')[0]
    line_tag = item.gettags.find { |x| x =~ /^line_/ }
    return unless line_tag
    line_tag.sub!(/^line_/, '')
    delete_line_data(line_tag)
    @listbox.configure(text: line_tag)
  end

  def delete_line_data(line)
    @canvas.delete("line_#{line}")
    @line_pos_data[line] = nil
  end

  def add_line_data(line, coords)
    delete_line_data(line) if @line_pos_data[line]
    TkcRectangle.new(
      @canvas, *coords,
      fill: 'red',
      width: 0,
      tags: [ 'rect', "line_#{line}" ]
    )
    TkcText.new(
      @canvas,
      (coords[0] + coords[2]) / 2,
      (coords[1] + coords[3]) / 2,
      text: line,
      tags: [ 'text', "line_#{line}" ]
    )
    @line_pos_data[line] = to_page_coords(*coords)
  end

  def process_click(e)
    @in_drag = false
    cx, cy = canvas_coords(e)
    coords = find_box(cx, cy)
    text = @listbox.get
    if coords && text && !text.empty?
      add_line_data(text, coords)
      advance_listbox
    end
  end

  def process_drag(e)
    if @in_drag
      cx, cy = canvas_coords(e)
      @canvas.coords(@drag_rect, @drag_x, @drag_y, cx, cy)
    else
      @in_drag = true
      @drag_x, @drag_y = canvas_coords(e)
      @drag_rect = TkcRectangle.new(
        @canvas, @drag_x, @drag_y, @drag_x, @drag_y,
        outline: 'green'
      )
    end
  end

  def process_release(e)
    return unless @in_drag
    @in_drag = false
    @canvas.delete(@drag_rect)
    @drag_rect = nil
    cx, cy = canvas_coords(e)
    w, h = (@drag_x - cx).abs, (@drag_y - cy).abs
    text = @listbox.get
    if [ w, h ].min > 5 && text && !text.empty?
      add_line_data(text, [
        [ cx, @drag_x ].min, [ cy, @drag_y ].min,
        [ cx, @drag_x ].max, [ cy, @drag_y ].max
      ])
      advance_listbox
    end
  end

  def find_box(x, y)
    start_color = @image.get(x, y)

    # Find the bottom line
    bx, by, new_color = find_change([ x, y ], 0, 1, @resolution / 2)
    return unless bx
    by -= 1

    # Find the right edge
    right_coords = ([ x ] * (by - y + 1)).zip(y..by)
    rx, ry = find_change(right_coords, 1, 0, @resolution * 3)
    unless rx
      rx, ry = find_change([ bx, by + 1 ], 1, 0, @resolution * 3)
      rx ||= x + @resolution * 3
    end
    rx -= 1

    # Find the left edge
    left_coords = ([ x ] * (by - y + 2)).zip(y..(by + 1))
    lx, ly = find_change(left_coords, -1, 0, @resolution * 3)
    lx ||= x - @resolution * 3
    lx += 1

    # Find the top edge
    top_coords = (lx..rx).zip([ y ] * (rx - lx + 1))
    tx, ty = find_change(top_coords, 0, -1, @resolution / 2)
    ty ||= y - @resolution / 2
    ty += 1

    return [ lx, ty, rx, by ]
  end

  def find_change(coords, dx, dy, max_steps)
    coords = [ coords ] unless coords[0].is_a?(Enumerable)

    coords.each do |coord|
      coord.push(@image.get(*coord)) unless coord.count == 3
    end

    1.upto(max_steps) do |i|
      coords.each do |x, y, color|
        tx, ty = x + dx * i, y + dy * i
        begin
          new_color = @image.get(tx, ty)
          return tx, ty, new_color unless color == new_color
        rescue RuntimeError
          return nil
        end
      end
    end
    return nil
  end

  def load_image(page)
    @page = page
    return if page < 1 or page > @parser.pages

    @tkc_image.destroy if @tkc_image
    @image = TkPhotoImage.new(file: @parser.page_image(page, @resolution))
    @tkc_image = TkcImage.new(
      @canvas, 0, 0, image: @image, anchor: 'nw',
      tags: 'image'
    )

    @line_pos_data.lines(@page).each do |l|
      add_line_data(l, to_screen_coords(@line_pos_data[l]))
    end

    update_buttons
  end

  def update_buttons
    @prev_page_button.configure(state: @page == 1 ? 'disabled' : 'normal')
    @next_page_button.configure(
      state: @page == @parser.pages ? 'disabled' : 'normal'
    )
  end

  def advance_listbox
    cur_pos = @listbox.get_value
    values = @listbox.cget(:values)
    if cur_pos < 0 || cur_pos == values.count - 1
      range = 0 ... values.count
    else
      range = [
        ((cur_pos + 1) ... values.count).to_a,
        (0 ... cur_pos).to_a
      ].flatten
    end

    range.each do |i|
      unless @line_pos_data[values[i]]
        @listbox.set_value(i)
        return
      end
    end

  end

end

class LinePosData

  def initialize(pdf_file, tax_form)
    @parser = PdfFileParser.new(pdf_file)

    @line_order = Biographical::FIELDS.keys.map { |x| "bio:#{x}" }
    @line_data = {}

    if tax_form.is_a?(TaxForm)
      @form_name = tax_form.name
      merge_lines(tax_form)
    else
      @form_name = tax_form.to_s
    end
  end

  def add_line_data(line, params)
    unless params.is_a?(Array) and params.count == 5
      raise "Invalid parameter #{params}"
    end
    @line_data[line.to_s] = params
    @line_order.push(line.to_s) unless @line_order.include?(line.to_s)
  end

  def merge_lines(tax_form)
    insert_pos = @line_order.count - 1
    lines = []
    tax_form.line.each do |l, v|
      lines.push(l)
      if v.is_a?(Array) && v.count > 1
        lines.push(*(2..v.count).map { |x| "#{l}##{x}" })
      end
    end
    lines.each do |l|
      pos = @line_order.find_index(l)
      if pos
        insert_pos = pos
      else
        insert_pos += 1
        @line_order.insert(insert_pos, l)
      end
    end
  end

  def all_filled?
    @line_order.all? { |x| @line_data.include?(x) }
  end

  def lines(page = nil)
    return @line_order unless page
    return @line_order.select { |x| @line_data[x] && @line_data[x][0] == page }
  end

  def [](line)
    @line_data[line]
  end

  def []=(line, data)
    if data.nil?
      @line_data.delete(line)
      return
    end

    raise "Invalid data" unless data.is_a?(Array) and data.count == 5
    line = line.to_s
    @line_data[line] = data
    @line_order.push(line) unless @line_order.include?(line)
  end

  def show_ui
    until File.exist?(@parser.file)
      @parser.file = Interviewer.new.ask(
        "File name for Form #@form_name:"
      )
    end

    begin
      ui = MarkingUI.new(@parser, self)
      Tk.mainloop
    rescue SystemExit
    ensure
      @parser.cleanup
    end
  end

  def export(f = STDOUT)
    f.puts "Form #@form_name, File #{@parser.file}"
    @line_order.each do |line|
      next unless @line_data[line]
      f.puts "\t#{line}\t[ #{@line_data[line].join(", ")} ]"
    end
  end

  def start_fill
    @fill_data = []
  end

  def fill(line, value)
    if value.is_a?(Array)
      multi_lines = (0...value.count).map { |x|
        x.zero? ? line : "#{line}##{x + 1}"
      }
      if self[multi_lines.last]
        multi_lines.zip(value).each do |l, v|
          fill(l, v)
        end
      else
        warn("Insufficient space for line #{line}; use attached sheet")
      end
      return
    end

    page, x, y, w, h = *self[line]
    ypos = [ 0, h - 9, 3 ].sort[1] + y
    res = [
      "-add-text", value.to_s.gsub("\n", "\\n"),
      "-font", "Courier", "-font-size", "10",
      "-range", "#{page}"
    ]
    if value.is_a?(Numeric) or value.is_a?(BlankNum)
      xpos = w - [ 0, w - 8, 6 ].sort[1] + x
      if value < 0
        res[1] = "(#{-value})"
        xpos += 6
      end
      res.push("-pos-right")
    elsif value == "X"
      xpos, ypos = x + w / 2, y + h / 2
      res.push("-midline", "-pos-center")
    else
      xpos = [ 0, w - 8, 6 ].sort[1] + x
      res.push("-pos-left")
      ypos = y + h - 10 if value =~ /\n/
    end
    res.push("#{xpos} #{ypos}")
    @fill_data.push(res)
  end

  def end_fill(filename)
    @parser.fill_form(@fill_data, filename)
  end

end

class MultiFormManager

  def initialize(filename = '', bio = nil)
    @form_data = {}
    @bio = bio
    import(filename)
  end

  def import(filename)
    @filename = filename
    return unless File.exist?(filename)

    lpd = nil
    File.open(filename) do |f|
      f.each do |l|
        case l
        when /^Form (.*), File (.*)/
          lpd = @form_data[$1] = LinePosData.new($2, $1)
        when /^\s*$/
        when /^\s+/
          line_no, data = $'.strip.split(/\s+/, 2)
          data = Interviewer.parse(line_no, data)
          lpd.add_line_data(line_no, data)
        else
          STDERR.puts("Unexpected line in #{filename}: #{l}")
        end
      end
    end
  end

  def mark_form(form, filename = '')
    if form.is_a?(Array)
      extra_forms = form
      form = extra_forms.shift
    else
      extra_forms = []
    end

    if @form_data.include?(form.name)
      lpd = @form_data[form.name]
      lpd.merge_lines(form)
    else
      lpd = @form_data[form.name] = LinePosData.new(filename, form)
    end

    extra_forms.each do |f| lpd.merge_lines(f) end

    lpd.show_ui unless lpd.all_filled?
  end

  def fill_form(form, filename)
    lpd = @form_data[form.name]
    lpd.start_fill

    @bio.line.each do |l, v|
      lpd.fill("bio:#{l}", v) if lpd["bio:#{l}"]
    end if @bio

    form.line.each do |l, v|
      if lpd[l]
        lpd.fill(l, v)
      else
        STDERR.puts("No position data for form #{form.name}, line #{l}")
      end
    end
    lpd.end_fill(filename)
  end

  def export(filename = @filename)
    File.open(filename, 'w') do |f|
      @form_data.each do |form, lpd|
        lpd.export(f)
        f.puts
      end
    end
  end

end

if __FILE__ == $0
  unless ARGV.count == 4
    puts "Usage: #{File.basename($0)} [input-data] [form] [pdf] [pos-data]"
    exit
  end

  input_data, form_name, pdf_file, pos_data = ARGV
  mgr = FormManager.new("Mark")
  mgr.import(input_data)

  if mgr.has_form?('Biographical')
    bio = mgr.form('Biographical')
  else
    bio = NamedForm.new('Biographical', mgr)
  end

  mfm = MultiFormManager.new(pos_data, bio)
  mfm.mark_form(mgr.forms(form_name), pdf_file)
  open(pos_data, 'w') do |f|
    mfm.export(f)
  end
end
