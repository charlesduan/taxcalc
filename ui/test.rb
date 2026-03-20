#!/usr/bin/env ruby

require 'gtk3'
require 'poppler'
require 'cairo'

doc = Poppler::Document.new(file: 'f1040.pdf')

num = doc.n_pages
puts "There are #{num} pages"

page = doc.get_page(0)

