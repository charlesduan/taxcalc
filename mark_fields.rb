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



parser = PdfFileParser.new('f1040x--2016.pdf')

begin

  puts "File has #{parser.pages} pages"

  root = TkRoot.new {
    title("Mark Form Fields")
  }

  file_image = TkPhotoImage.new(file: parser.page_image(1, 144))

  puts "Dims are #{file_image.width} x #{file_image.height}"

  canvas = TkCanvas.new(root) do
    width file_image.width
    height 500
    scrollregion "0 0 #{file_image.width} #{file_image.height}"
  end
  canvas.pack(fill: 'both', expand: 1, side: 'left')
  canvas.bind('1') do |e|
    puts "Got #{canvas.canvasx(e.x)}, #{canvas.canvasy(e.y)}"
  end

  TkcImage.new(canvas, 0, 0, image: file_image, anchor: 'nw')
  vscroll = TkScrollbar.new(root) { orient 'vertical' }
  canvas.yscrollbar(vscroll)
  vscroll.pack(side: 'left', fill: 'y', expand: 1)

  root.bind_all("MouseWheel") do |e|
    canvas.yview_scroll(-e.delta, "units")
  end
  Tk.mainloop

ensure

  parser.cleanup

end

