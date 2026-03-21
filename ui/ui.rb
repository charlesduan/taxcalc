require 'gtk3'
require 'poppler'
require 'cairo'
require_relative 'api_bridge'

class TaxUIApp < Gtk::Application
  def initialize(read_io, write_io)
    super("org.sbf5.taxcalc", :flags_none)

    @api_bridge = TaxAPIBridge.new(read_io, write_io, self)
    @updating_toolbar = false

    @zoom = 2

    initialize_css

    signal_connect("activate") do |app|
      @window = Gtk::ApplicationWindow.new(self)
      @window.set_title("Tax Calculation UI")
      @window.set_default_size(612 * @zoom + 20, 1000)

      initialize_window_contents

      @api_bridge.send("ready", nil)
    end
  end

  ########################################################################
  #
  # INTERFACE WIDGETS
  #
  ########################################################################

  def initialize_css
    @provider = Gtk::CssProvider.new
    Gtk::StyleContext.add_provider_for_screen(
      Gdk::Screen.default, @provider, Gtk::StyleProvider::PRIORITY_APPLICATION
    )
    @provider.load_from_data(<<~CSS)
      #toolbar separator {
        margin-left: 8px;
        margin-right: 8px;
      }
      #page_selector {
        min-width: 60px;
      }
      #line_selector {
        min-width: 300px;
      }
    CSS
  end

  def initialize_window_contents
    vbox = Gtk::Box.new(:vertical)
    toolbar = initialize_toolbar
    vbox.pack_start(toolbar, expand: false)
    vbox.pack_start(Gtk::Separator.new(:horizontal))
    @main_view = Gtk::ScrolledWindow.new()
    vbox.pack_start(@main_view, expand: true, fill: true)
    @window.add(vbox)
    @window.show_all
    hide_split_tools
  end

  def initialize_toolbar
    toolbar = Gtk::Box.new(:horizontal)
    toolbar.name = "toolbar"

    @form_name_label = Gtk::Label.new("(No form loaded)")
    toolbar.pack_start(@form_name_label, padding: 3)
    toolbar.pack_start(Gtk::Separator.new(:vertical))
    add_page_tools(toolbar)
    toolbar.pack_start(Gtk::Separator.new(:vertical))
    add_line_tools(toolbar)
    toolbar.pack_start(Gtk::Separator.new(:vertical))
    add_split_tools(toolbar)

    return toolbar
  end

  def add_page_tools(toolbar)
    page_label = Gtk::Label.new("Page")
    toolbar.pack_start(page_label, padding: 3)

    prev_page_button = Gtk::Button.new
    prev_page_button.add(Gtk::Label.new("<"))
    prev_page_button.signal_connect("clicked") do
      @page_selector.active = [ @page_selector.active - 1, 0 ].max
    end
    toolbar.pack_start(prev_page_button)

    @page_selector = Gtk::ComboBoxText.new
    @page_selector.name = "page_selector"
    @page_selector.signal_connect("changed") { load_page }
    toolbar.pack_start(@page_selector)

    next_page_button = Gtk::Button.new
    next_page_button.add(Gtk::Label.new(">"))
    next_page_button.signal_connect("clicked") do
      @page_selector.active = [
        @page_selector.active + 1, @page_selector.model.iter_n_children - 1
      ].min
    end
    toolbar.pack_start(next_page_button)
  end

  def add_line_tools(toolbar)
    toolbar.pack_start(Gtk::Label.new("Line"), padding: 3)
    @line_selector = Gtk::ComboBoxText.new
    @line_selector.name = "line_selector"
    @line_selector.signal_connect("changed") do
      send_toolbar_update("line_changed")
    end
    toolbar.pack_start(@line_selector)
  end

  def add_split_tools(toolbar)
    toolbar.pack_start(Gtk::Label.new("Split line?"), padding: 3)
    @split_line_check = Gtk::CheckButton.new
    toolbar.pack_start(@split_line_check)

    @split_line_check.signal_connect("toggled") do
      send_toolbar_update("split_changed")
    end

    @split_tools = Gtk::Box.new(:horizontal)
    @split_tools.pack_start(Gtk::Label.new("Split separator"), padding: 3)
    @split_sep_editor = Gtk::Entry.new
    @split_sep_editor.signal_connect("changed") do
      send_toolbar_update("split_sep_changed")
    end
    @split_tools.pack_start(@split_sep_editor)
    toolbar.pack_start(@split_tools)
  end


  ########################################################################
  #
  # UI EVENT HANDLERS
  #
  ########################################################################

  def load_page
    return if @updating_toolbar

    # By coincidence, the combo box index and Poppler page index are both
    # zero-indexed and thus match.
    page = @document[@page_selector.active]

    @surface = Cairo::ImageSurface.new(*page.size.map { |x| x * @zoom })
    context = Cairo::Context.new(@surface)
    context.scale(@zoom, @zoom)
    page.render(context)
    if (c = @main_view.child)
      @main_view.remove(c)
      c.destroy
    end

    @image = Gtk::Image.new(surface: @surface)
    @fixed = Gtk::Layout.new
    @fixed.set_size(*page.size.map { |x| x * @zoom })
    @fixed.signal_connect("button-press-event") { |widget, event|
      handle_click(widget, event)
    }
    @fixed.add_events([
      :button_press_mask, :pointer_motion_mask
    ])
    @fixed.put(@image, 0, 0)
    @main_view.add(@fixed)
    @fixed.show_all

    @api_bridge.send('select_page', { 'page' => current_page })
  end

  def current_page
    return @page_selector.active + 1
  end

  def send_toolbar_update(event)
    return if @updating_toolbar
    return if @line_selector.active == -1
    @api_bridge.send(event, toolbar_info)
  end

  def toolbar_info
    return {
      'line' => @line_selector.active_text,
      'split' => @split_line_check.active?,
      'separator' => @split_sep_editor.text,
    }
  end

  def show_split_tools(separator)
    @split_line_check.active = true
    @split_sep_editor.text = separator
    @split_tools.show
  end

  def hide_split_tools
    @split_line_check.active = false
    @split_sep_editor.text = ''
    @split_tools.hide
  end

  def handle_click(widget, event)
    puts "Got a click at (#{event.x}, #{event.y})"
  end

  ########################################################################
  #
  # CONTROLLER COMMAND RESPONSES
  #
  ########################################################################

  def updating_toolbar
    begin
      @updating_toolbar = true
      yield
    ensure
      @updating_toolbar = false
    end
  end

  def cmd_load_pdf(payload)
    form = payload["form"]
    file = payload["file"]
    lines = payload["lines"]

    @document = Poppler::Document.new(file: file)
    pages = @document.n_pages

    updating_toolbar do
      @form_name_label.text = "Form #{form}"
      @page_selector.remove_all
      1.upto(pages) do |page|
        @page_selector.append_text(page.to_s)
      end
      @page_selector.active = 0
      @line_selector.remove_all
      @line_map = {}
      lines.each_with_index do |line, i|
        @line_selector.append_text(line)
        @line_map[line] = i
      end
    end
    load_page
  end

  def cmd_set_toolbar_info(payload)
    updating_toolbar do
      if payload.include?('line') && @line_map.include?(payload['line'])
        @line_selector.active = @line_map[payload['line']]
      end
      if payload.include?('split')
        if payload['split']
          show_split_tools(payload['separator'])
        else
          hide_split_tools
        end
      end
    end
  end

end

