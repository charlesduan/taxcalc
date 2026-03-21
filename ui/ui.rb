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
    @split_tools.hide
  end

  def initialize_toolbar
    toolbar = Gtk::Box.new(:horizontal)
    toolbar.name = "toolbar"
    @form_name_label = Gtk::Label.new("(No form loaded)")
    toolbar.pack_start(@form_name_label, padding: 3)

    toolbar.pack_start(Gtk::Separator.new(:vertical))

    add_page_tools(toolbar)

    toolbar.pack_start(Gtk::Separator.new(:vertical))

    toolbar.pack_start(Gtk::Label.new("Line"), padding: 3)
    @line_selector = Gtk::ComboBoxText.new
    @line_selector.name = "line_selector"
    toolbar.pack_start(@line_selector)

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
      @page_selector.active = [
        @page_selector.active - 1,
        0
      ].max
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
        @page_selector.active + 1,
        @page_selector.model.iter_n_children - 1
      ].min
    end
    toolbar.pack_start(next_page_button)
  end

  def add_split_tools(toolbar)
    toolbar.pack_start(Gtk::Label.new("Split line?"), padding: 3)
    @split_line_check = Gtk::CheckButton.new
    toolbar.pack_start(@split_line_check)

    @split_line_check.signal_connect("toggled") do
      if @split_line_check.active?
        @split_tools.show
      else
        @split_tools.hide
      end
    end

    @split_tools = Gtk::Box.new(:horizontal)
    @split_tools.pack_start(Gtk::Label.new("Split separator"), padding: 3)
    @split_sep_editor = Gtk::Entry.new
    @split_tools.pack_start(@split_sep_editor)
    toolbar.pack_start(@split_tools)
  end


  ########################################################################
  #
  # UI EVENT HANDLERS
  #
  ########################################################################


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
      lines.each do |line|
        @line_selector.append_text(line)
      end
    end
    load_page
  end

  def load_page
    return if @updating_toolbar

    page = @document[@page_selector.active]
    @surface = Cairo::ImageSurface.new(*page.size.map { |x| x * @zoom })
    context = Cairo::Context.new(@surface)
    context.scale(@zoom, @zoom)
    page.render(context)
    if @image
      @main_view.remove(@image)
      @image.destroy
    end
    @image = Gtk::Image.new(surface: @surface)
    @main_view.add(@image)
    @image.show
  end

end

