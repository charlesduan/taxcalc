#!/usr/bin/env ruby

require('json')

@rubyRd, @nodeWr = IO.pipe
@nodeRd, @rubyWr = IO.pipe

def transmit(command, payload)
  line = { 'command' => command, 'payload' => payload }.to_json
  @rubyWr.puts(line)
end

def dispatch(command, payload)
  case command
  when 'addLineBox'
    transmit('drawLineBox', {
      'line' => payload['toolbar']['line'],
      'id' => payload['toolbar']['line'],
      'pos' => payload['pos'],
    })
  when 'removeLine'
    transmit('removeLineBox', { 'id' => payload['id'] })
  when 'boxLineChanged'
    transmit('setToolbarInfo', payload)
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

@rubyRd.each do |line|
  puts "Ruby: #{line}"
  obj = JSON.parse(line)
  dispatch(obj['command'], obj['payload'])
end

@rubyRd.close
@rubyWr.close
Process.wait(pid)

puts "Ruby: Done"

