#!/usr/bin/env ruby

require 'yaml'
require 'optparse'
require 'ostruct'

require_relative '../form_manager'
require_relative 'models'
require_relative 'form_filler'

#
# Gather options
#

@options = OpenStruct.new(
  fill_dir: "filled",
  posdata: "posdata.yaml",
  prefix: nil,
  bio: nil,
)

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($0)} [options] [form]"
  opts.separator("")

  opts.on("-b", "--biographical TEXT", "Set the biographical text") do |bio|
    @options.bio = bio
  end

  opts.on("-d", "--output-dir DIR", "Output directory for files") do |dir|
    @options.fill_dir = dir
  end

  opts.on("--posdata FILE", "Set the position data file") do |file|
    raise "#{file}: File not found" unless File.file?(file)
    @options.posdata = file
  end

  opts.on("-p", "--prefix PREFIX", "Set a filename prefix") do |prefix|
    @options.prefix = "#{prefix}-"
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end

end.parse!


posdata = YAML.load(open(@options.posdata, &:read))
form_file, *form_names = ARGV

Dir.mkdir(@options.fill_dir) unless File.directory?(@options.fill_dir)

#
# Select the forms to fill
#
manager = FormManager.new
manager.import(form_file)

if form_names.empty?
  forms = manager.to_a
else
  forms = form_names.map { |name| manager.forms(name) }.flatten
end

#
# This is a somewhat hackish way of finding the biographical information but it
# works for most purposes, I think
#
bio = @options.bio
bio ||= manager.with_form(1040) { |f|
  "#{f.line[:first_name]} #{f.line[:last_name]}, SSN #{f.line[:ssn]}"
}
bio ||= manager.with_form(1065) { |f|
  "#{f.line[:name]}, EIN #{f.line[:D]}"
}
bio ||= manager.with_form('D-40') { |f|
  "#{f.line[:first_name]} #{f.line[:last_name]}, SSN #{f.line[:tin]}"
}
unless bio
  raise "No biographical information found; use --biographical option"
end


files_created = {}

forms.each do |tax_form|
  pos_form = posdata[tax_form.name]
  next unless pos_form && pos_form.file
  puts "Filling Form #{tax_form.name}"

  filler = FormFiller.new(tax_form, pos_form)
  filler.continuation_bio = bio

  # Deal with multiple forms of the same name
  filename = [
    @options.prefix, tax_form.name.downcase.gsub(/\W+/, '-'), ".pdf"
  ].join("")
  if files_created[filename]
    files_created[filename] += 1
    filename = filename.sub(/\.pdf\z/, "-#{files_created[filename]}.pdf")
  else
    files_created[filename] = 0
  end

  filler.fill(File.join(@options.fill_dir, filename))
end
