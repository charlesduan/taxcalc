#!/usr/bin/env ruby

require 'yaml'
require 'json'

require_relative 'controller'
require_relative '../form_manager'


@rubyRd, @nodeWr = IO.pipe
@nodeRd, @rubyWr = IO.pipe

def transmit(command, payload)
  line = { 'command' => command, 'payload' => payload }.to_json
  @rubyWr.puts(line)
end

def dispatch(command, payload)
  if @controller.respond_to?("cmd_#{command}")
    @controller.send("cmd_#{command}", payload)
  else
    warn("Unknown command #{command}")
  end
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

@controller = Marking::Controller.new(@rubyWr)

input, form, file = ARGV

@controller.cmd_load('file' => 'posdata.yaml') if File.exist?('posdata.yaml')

@controller.add_form(form, file) if file

manager = FormManager.new
manager.import(input)
@controller.import_forms(manager)

@controller.select_form(form)
@controller.start

@rubyRd.each do |line|
  puts "Ruby: #{line}"
  obj = JSON.parse(line)
  dispatch(obj['command'], obj['payload'])
end

@controller.cmd_save('file' => 'posdata.yaml')

@rubyRd.close
@rubyWr.close
Process.wait(pid)

puts "Ruby: Done"

