#!/usr/bin/ruby

require 'tk'
require 'tkextlib/tkimg/png'
require 'tmpdir'

dir = File.dirname(__FILE__)
entries = Dir.entries(dir)
CPDF = entries.include?("cpdf") ? File.join(dir, "cpdf") : "cpdf"
GS = entries.include?("gs") ? File.join(dir, "gs") : "gs"

class PdfFileParser

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
          puts line
        end
      end
      @resolutions[resolution] = true
    end
    page_file = "#{tempdir}/img-#{resolution}-#{"%03d" % num}.png"
    return nil unless File.exist?(page_file)
    return page_file
  end

end

class MarkingUI

  def initialize(parser)

    @parser = parser
    @resolution = 144

    @root = TkRoot.new {
      title("Mark Form Fields")
    }

    initialize_top_frame

    initialize_canvas_frame

    load_image(1)

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

    @canvas.itembind('image', '1') do |e|
      process_click(e)
    end
    @canvas.itembind('rect', '1') do |e|
      @canvas.find_withtag('current')[0].destroy
    end

    @vscroll = TkScrollbar.new(frame) { orient 'vertical' }
    @canvas.yscrollbar(@vscroll)
    @vscroll.pack(side: 'left', fill: 'y', expand: 1)

    frame.bind_all("MouseWheel") do |e|
      @canvas.yview_scroll(-e.delta, "units")
    end
  end

  def process_click(e)
    cx, cy = @canvas.canvasx(e.x).round, @canvas.canvasy(e.y).round
    puts "Got #{cx}, #{cy}"
    coords = find_box(cx, cy)
    if coords
      TkcRectangle.new(@canvas, *coords, fill: 'red', width: 0, tags: 'rect')
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

    update_buttons
  end

  def update_buttons
    @prev_page_button.configure(state: @page == 1 ? 'disabled' : 'normal')
    @next_page_button.configure(
      state: @page == @parser.pages ? 'disabled' : 'normal'
    )
  end
end



parser = PdfFileParser.new('f1040x--2016.pdf')

begin

  puts "File has #{parser.pages} pages"

  ui = MarkingUI.new(parser)

  Tk.mainloop

ensure

  parser.cleanup

end

