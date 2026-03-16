#!/usr/bin/env ruby

require 'gtk3'

the_app = Gtk::Application.new("org.sbf5.taxcalc", :flags_none)

the_app.signal_connect("activate") do |app|
  puts(the_app.equal?(app))
  window = Gtk::ApplicationWindow.new(app)
  window.set_title("Hello world")
  window.set_default_size(300, 300)
  window.show_all
end

the_app.run
