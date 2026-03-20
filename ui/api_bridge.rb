require 'glib2'
require 'json'

class TaxAPIBridge
  def initialize(read_io, write_io, app)
    @read_io = read_io
    @write_io = write_io
    @app = app
    @buffer = String.new("")

    @read_channel = GLib::IOChannel.new(@read_io, "r")
    @read_channel.add_watch(GLib::IOChannel::IN) do |io, condition|
      @buffer << io.read(4096)

      # Dispatches each line, and saves the last incomplete line back to
      # @buffer.
      @buffer = @buffer.split("\n", -1).inject do |memo, item|
        dispatch(memo)
        item
      end
      true
    end
  end

  def send(command, payload)
    json = JSON.generate({ "command" => command, "payload" => payload })
    @write_io.puts(json)
  end

  def dispatch(line)
    obj = JSON.parse(line)
    command = "cmd_#{obj["command"]}".to_sym
    if @app.respond_to?(command)
      begin
        @app.send(command, obj["payload"])
      rescue
        warn("API Bridge: caught error: #$!")
      end
    else
      warn("API Bridge: unknown command #{obj['command']}")
    end
  end


end
