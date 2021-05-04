class PdfAssembler
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

  def initialize(infile, outfile)
    @infile, @outfile = infile, outfile
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
    @tempdir = nil
  end

  def fill_form(commands)
    command = [ CPDF, "-merge", @infile ]
    commands.each do |cmd|
      command.push("AND", *cmd)
    end
    command.push("AND", "-pad-multiple", "2") if @even_pages
    command.push("-o", @outfile)
    popen(*command) do |io|
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
    cleanup
  end

end
