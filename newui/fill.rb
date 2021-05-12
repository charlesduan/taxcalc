#!/usr/bin/env ruby

require 'yaml'

require_relative '../form_manager'
require_relative 'models'
require_relative 'form_filler'

posdata = YAML.load(open('posdata.yaml', &:read))
form_file, output_dir = ARGV

Dir.mkdir(output_dir) unless File.directory?(output_dir)

manager = FormManager.new
manager.import(form_file)

bio = nil
bio ||= manager.with_form(1040) { |f|
  "#{f.line[:first_name]} #{f.line[:last_name]}, SSN #{f.line[:ssn]}"
}
bio ||= manager.with_form(1065) { |f|
  "#{f.line[:name]}, EIN #{f.line[:D]}"
}
unless bio
  warn "No biographical information found"
  bio = "???"
end


manager.each do |tax_form|
  pos_form = posdata[tax_form.name]
  next unless pos_form && pos_form.file
  puts "Filling Form #{tax_form.name}"

  filler = FormFiller.new(tax_form, pos_form)
  filler.continuation_bio = bio
  filler.fill(File.join(output_dir, "#{tax_form.name}.pdf"))
end
