#!/usr/bin/env ruby

require 'gtk3'
require 'poppler'
require 'cairo'

doc = Poppler::Document.new(file: 'f1040.pdf')

num = doc.count
puts "There are #{num} pages"

page = doc[0]

width, height = doc[0].size

surface = Cairo::ImageSurface.new(width, height)
context = Cairo::Context.new(surface)
page.render(context)

