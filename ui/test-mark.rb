#!/usr/bin/env ruby

require 'yaml'
require 'json'
require 'optparse'
require 'ostruct'
require 'fcntl'

@ctrl_read, @ui_write = IO.pipe
@ui_read, @ctrl_write = IO.pipe

pid = fork do
  @ctrl_read.close
  @ctrl_write.close
  Dir.chdir(File.dirname(__FILE__))
  require_relative 'ui'
  TaxUIApp.new(@ui_read, @ui_write).run
end

@ui_read.close
@ui_write.close

def send_cmd(cmd, args)
  res = JSON.generate({ 'command' => cmd, 'payload' => args})
  puts "-> #{res}"
  @ctrl_write.puts(res)
end           

begin

  @ctrl_read.each do |line|
    puts "<- #{line}"
    obj = JSON.parse(line)
    command, payload = obj['command'], obj['payload']
    case command
    when 'ready'
      send_cmd('load_pdf', {
        'form' => '1040',
        'file' => 'f1040.pdf',
        'lines' => [ 'a', 'b', 'c' ],
      })

    when 'select_page'
      page = payload['page']
      # Need to draw_line_boxes

    when 'split_changed'
      send_cmd('set_toolbar_info', {
        'line' => payload['line'],
        'split' => payload['split'],
        'separator' => ''
      })

    when 'split_sep_changed'

    when 'line_changed'
      if payload['line'] == 'a'
        send_cmd('set_toolbar_info', {
          'line' => payload['line'],
          'split' => true,
          'separator' => '-'
        })
      else
        send_cmd('set_toolbar_info', {
          'line' => payload['line'],
          'split' => false,
          'separator' => nil
        })
      end

    else
      warn("Unknown command #{command}")
    end
  end
rescue

  Process.kill("HUP", pid)
  raise

end
@ctrl_read.close
@ctrl_write.close


Process.wait(pid)

