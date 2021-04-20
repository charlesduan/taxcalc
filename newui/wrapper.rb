#!/usr/bin/env ruby

require_relative 'controller'

require('json')

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

# Initialize controller's data here
form = Marking::Form.new('1040', 'f1040.pdf')
%w(1 2a 2b 3a 3b 4a 4b 5a 5b 6a 6b).each do |l|
  form.add_line(l)
end

@controller.add_form(form)
@controller.start

@rubyRd.each do |line|
  puts "Ruby: #{line}"
  obj = JSON.parse(line)
  dispatch(obj['command'], obj['payload'])
end

@rubyRd.close
@rubyWr.close
Process.wait(pid)

puts "Ruby: Done"

