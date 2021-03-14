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
    @even_pages = true
  end

  attr_accessor :file
  attr_accessor :even_pages

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

    popen(CPDF, '-pages', @file, :err => '/dev/null') do |io|
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
        GS, '-dSAFER', '-dBATCH', '-dNOPAUSE',
        '-sDEVICE=pnggray',
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
    command.push("AND", "-pad-multiple", "2") if @even_pages
    command.push("-o", new_file)
    popen(*command, :err => '/dev/null') do |io|
      io.each do |line|
        puts line
      end
    end
  end

  def add_continuation(ct, filename)
    IO.popen("groff -mom -t | ps2pdf - #{tempdir}/ct.pdf", 'w') do |io|
      io.write(ct)
    end
    command = [ CPDF, '-merge', '-i', filename, '-i', "#{tempdir}/ct.pdf" ]
    command.push('AND', '-pad-multiple', '2') if @even_pages
    command.push('-o', filename)
    popen(*command, :err => "/dev/null") do |io|
      puts io.read
    end
  end

end


