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
    @even_pages = true
  end

  attr_accessor :file
  attr_accessor :even_pages

  def fill_form(commands)
    command = [ CPDF, "-merge", @infile ]
    commands.each do |cmd|
      command.push("AND", *cmd)
    end
    command.push("AND", "-pad-multiple", "2") if @even_pages
    command.push("-o", @outfile)
    popen(*command, :err => '/dev/null') do |io|
      puts io.read
    end
  end

  def add_continuation(ct)
    IO.popen("groff -mom -t | ps2pdf - form-con.pdf", 'w') do |io|
      io.write(ct)
    end
    command = [ CPDF, '-merge', '-i', @outfile, '-i', "form-con.pdf" ]
    command.push('AND', '-pad-multiple', '2') if @even_pages
    command.push('-o', @outfile)
    popen(*command, :err => "/dev/null") do |io|
      puts io.read
    end
    File.unlink("form-con.pdf")
  end

end
