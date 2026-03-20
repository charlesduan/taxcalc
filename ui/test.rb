#!/usr/bin/env ruby

require 'glib2'

reader, writer = IO.pipe

pid = fork do
  ch = GLib::IOChannel.new(reader, "r")
  ch.add_watch(GLib::IOChannel::IN) { |io, condition|
    puts "Got condition #{condition} on #{io}"
    text = io.read(3)
    puts "Read #{text}"
    true
  }

  context = GLib::MainContext.default
  mainloop = GLib::MainLoop.new(context, true)

  ch.add_watch(GLib::IOChannel::ERR) { |io, condition|
    puts "Error"
    mainloop.quit
  }
  ch.add_watch(GLib::IOChannel::HUP) { |io, condition|
    puts "Hung up"
    mainloop.quit
  }
  puts "Starting main loop"
  mainloop.run
  puts "Done with main loop"
end

loop do
  text = gets
  break unless text
  puts "Sending #{text}"
  writer.write(text)
end
puts "Closing"
writer.close
reader.close

Process.wait(pid)
