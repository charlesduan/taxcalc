#!/usr/bin/env ruby

require 'yaml'
require 'json'

require_relative 'controller'


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
  exec(
    './qode', 'main.js',
    @nodeRd.fileno.to_s, @nodeWr.fileno.to_s,
    @nodeRd => @nodeRd, @nodeWr => @nodeWr
  )
end

@nodeRd.close
@nodeWr.close

@controller = Marking::Controller.new(@rubyWr)

@controller.cmd_load('file' => 'posdata.yaml')
@controller.select_form('1040')
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

