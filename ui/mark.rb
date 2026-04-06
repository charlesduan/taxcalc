#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'optparse'
require 'ostruct'
require 'fcntl'


require_relative 'controller'
require_relative '../form_manager'


#
# Gather options
#

@options = OpenStruct.new(
  blank_dir: "blank",
  posdata: "posdata.yaml",
  inputs: [],
  download: false,
  file: nil,
  force: false,
  pages: nil,
)

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options] [form]"
  opts.separator("")

  opts.on("-i", "--input FILE", "Add a TaxForm input file") do |file|
    raise "#{file}: File not found" unless File.file?(file)
    @options.inputs.push(file)
  end

  opts.on("-p", "--posdata FILE", "Set the position data file") do |file|
    raise "#{file}: File not found" unless File.file?(file)
    @options.posdata = file
  end

  opts.on("-d", "--download", "Download based on an expected IRS URL") do
    @options.download = true
  end

  opts.on("-u", "--url URL", "Download from the given URL") do |url|
    @options.download = url
  end

  opts.on("-f", "--file FILE", "Select the form's PDF file") do |file|
    raise "#{file}: File not found" unless File.file?(file)
    @options.file = file
  end

  opts.on("--pages RANGE", "Range of pages for the PDF file") do |range|
    @options.pages = range
  end

  opts.on("--force", "Overwrite position data for existing form") do
    @options.force = true
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

end.parse!


@ctrl_read, @ui_write = IO.pipe
@ui_read, @ctrl_write = IO.pipe

#
# Node.js expects blocking file descriptors
#
#@nodeRd.fcntl(
  #Fcntl::F_SETFL, @nodeRd.fcntl(Fcntl::F_GETFL) & ~Fcntl::O_NONBLOCK
#);
#@nodeWr.fcntl(
  #Fcntl::F_SETFL, @nodeWr.fcntl(Fcntl::F_GETFL) & ~Fcntl::O_NONBLOCK
#);

@controller = Marking::Controller.new(@ctrl_write)

# Load the posdata and import tax forms
@controller.load_posdata(@options.posdata) if File.exist?(@options.posdata)
@options.inputs.each do |input|
  manager = FormManager.new
  manager.import(input)
  @controller.import_forms(manager)
end

# Select the form to work on. If no form is selected, print a list of forms and
# exit.
if ARGV.count != 1
  puts("Provide a form name to work with. The following forms are available:")
  res = {
    'Managers' => [],
    'Complete forms' => [],
    'Incomplete not-for-filing' => [],
    'Incomplete forms' => [],
  }
  @controller.forms.each do |name, form|
    if form.all_positioned?
      res['Complete forms'].push(name)
    elsif %w(Manager Analysis).any? { |x| name.include?(x) }
      res['Managers'].push(name)
    elsif form.discarded
      res['Incomplete not-for-filing'].push(name)
    else
      res['Incomplete forms'].push(name)
    end
  end
  res.each do |cat, forms|
    puts "\n#{cat}"
    forms.each do |f| puts "  #{f}" end
  end
  exit
elsif ARGV[0] == 'next'
  @controller.forms.each do |name, form|
    next if form.all_positioned?
    next if name =~ /Manager|Worksheet|Analysis|Computation/
    @controller.select_form(name)
    break
  end
else
  @controller.select_form(ARGV[0])
end


# Select the file to be associated with the form.

if @options.file
  @controller.set_current_form_file(@options.file, force: @options.force)
elsif @options.download.is_a?(String)
  @controller.download_current_form_file(
    url: @options.download, dir: @options.blank_dir, force: @options.force
  )
elsif @options.download
  @controller.download_current_form_file(
    force: @options.force, dir: @options.blank_dir
  )
end

unless @controller.current_form_has_file?
  raise "Must provide a file or download URL for this form"
end

if @options.pages
  @controller.select_pdf_pages(
    @options.pages, dir: @options.blank_dir, force: @options.force
  )
end

pid = fork do
  @ctrl_read.close
  @ctrl_write.close
  Dir.chdir(File.dirname(__FILE__))

  #
  # I'm not sure why, but loading the UI in the forked process fails on MacOS.
  # Thus, a new Ruby instance is started.
  #
  exec(
    "./ui.rb", @ui_read.to_i.to_s, @ui_write.to_i.to_s,
    # This indicates to exec that the pipes should remain open in the exec'ed
    # process.
    @ui_read => @ui_read, @ui_write => @ui_write
  )
end

@ui_read.close
@ui_write.close

begin

  @ctrl_read.each do |line|
    # puts "<- #{line}"
    obj = JSON.parse(line)
    command, payload = obj['command'], obj['payload']
    if @controller.respond_to?("cmd_#{command}")
      @controller.send("cmd_#{command}", payload)
    else
      warn("Unknown command #{command}")
    end
  end

  @controller.cmd_save('file' => 'posdata.yaml')

rescue
  Process.kill("HUP", pid)
  @controller.cmd_save('file' => 'autosave-posdata.yaml')
  raise

ensure
  @ctrl_read.close
  @ctrl_write.close
end


Process.wait(pid)

