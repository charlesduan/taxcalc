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

filler = FormFiller.new(posdata, manager)

manager.each do |tax_form|
  filler.fill_form(tax_form, File.join(output_dir, "#{tax_form.name}.pdf"))
end
