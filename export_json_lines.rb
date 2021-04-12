#!/usr/bin/env ruby

require 'json'
require_relative 'form_manager'

m = FormManager.new("");
ARGV.each do |f|
  m.import(f)
end

res = []

m.each do |form|
  lines = form.line.map { |l, v|
    next [] if l.end_with?("!")
    v.is_a?(Array) ? [ l, *(2..v.length).map { |i| "#{l}##{i}" } ] : l
  }.flatten
  res.push({
    'name' => form.name,
    'lines' => lines,
  })
end

node_dir = File.join(File.dirname(__FILE__), 'newui')
IO.popen([
  File.join(node_dir, 'qode'),
  File.join(node_dir, 'main.js')
], 'r+') do |io|
  io.write(res.to_json)
  io.close_write
  res = io.read
end





