#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'optparse'
require 'ostruct'

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

  opts.on("-d", "--download", "Download the form online") do
    @options.download = true
  end

  opts.on("-f", "--file FILE", "Select the form's PDF file") do |file|
    raise "#{file}: File not found" unless File.file?(file)
    @options.file = file
  end

  opts.on("--force", "Overwrite position data for existing form") do
    @options.force = true
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

end.parse!


@rubyRd, @nodeWr = IO.pipe
@nodeRd, @rubyWr = IO.pipe
@controller = Marking::Controller.new(@rubyWr)

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
  @controller.forms.each do |name, form|
    puts "  #{name}#{form.all_positioned? ? '' : ' (incomplete)'}"
  end
  exit
end

@controller.select_form(ARGV[0])


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

pid = fork do
  @rubyRd.close
  @rubyWr.close
  Dir.chdir(File.dirname(__FILE__))
  exec(
    './qode', 'main.js',
    @nodeRd.fileno.to_s, @nodeWr.fileno.to_s,
    @nodeRd => @nodeRd, @nodeWr => @nodeWr
  )
end

@nodeRd.close
@nodeWr.close

@controller.start

begin

  @rubyRd.each do |line|
    puts "<- #{line}"
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

end

@rubyRd.close
@rubyWr.close


Process.wait(pid)

