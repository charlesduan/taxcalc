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

    @next_elt_button = TkButton.new(
      frame, text: "Skip line",
      command: proc { advance_listbox }
    )
    @next_elt_button.pack(side: 'left')

  end

  def initialize_canvas_frame

    frame = TkFrame.new(@root)
    frame.pack(fill: 'x', expand: true, side: 'top')

    @canvas = TkCanvas.new(
      frame,
      width: @resolution * 17 /2,
      height: 700,
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

  #
  # Given an array of coordinates and an increment vector, advance each
  # coordinate in the array by the increment vector until one of them falls on a
  # changed color. Returns a three-element array of the first changed coordinate
  # and the new color.
  #
  # coords is an array of coordinates (or a single coordinate that is
  # immediately converted to a one-element array. dx and dy are how much to
  # increment the x and y coordinates in the array at each step, up to max_steps
  # steps.
  #
  def find_change(coords, dx, dy, max_steps)
    coords = [ coords ] unless coords[0].is_a?(Enumerable)

    # First, to each of the coordinates, add a third element that is the color
    # at that coordinate.
    coords.each do |coord|
      coord.push(@image.get(*coord)) unless coord.count == 3
    end

    # Iterate through the maximum number of steps.
    1.upto(max_steps) do |i|

      # Test each coordinate in the list:
      coords.each do |x, y, color|

        # Advance the coordinate by the increment vector times the current step.
        tx, ty = x + dx * i, y + dy * i
        begin

          # Get the color and see if it is the same as the original color.
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


