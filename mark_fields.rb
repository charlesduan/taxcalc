#!/usr/bin/ruby

if __FILE__ == $0
  $LOAD_PATH.push(File.dirname(__FILE__))
  require 'form_manager'
  require 'optparse'
  require 'ostruct'
end

require 'tmpdir'
require 'tax_form'
require 'interviewer'

require 'ui/pdf_file_parser'
require 'ui/marking_ui.rb'
require 'ui/line_pos_data.rb'
require 'ui/multi_form_manager.rb'

if __FILE__ == $0

  @mgr = FormManager.new("Mark")
  @pos_data = "pos-data.txt"
  @fill_dir = nil
  @all = false

  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename $0} [options] [form] [file]"
    opts.separator("")
    opts.separator("Options:")

    opts.on('-i', '--input-data FILE', 'Tax form data file') do |f|
      @mgr.import(f)
    end
    opts.on('-p', '--pos-data FILE', 'Line position data file') do |f|
      @pos_data = f
    end
    opts.on('-f', '--fill DIR', 'Fill in forms, place in DIR') do |d|
      raise "#{d} must be a directory" unless File.directory?(d)
      @fill_dir = d
    end
    opts.on('-a', '--all', 'Fill worksheets') do
      @all = true
    end

    opts.on_tail('-h', '--help', 'Show this message') do
      puts opts
      exit
    end
  end

  opt_parser.parse!(ARGV)

  if @mgr.empty?
    warn("No tax form data provided; supply a file name with the -i option")
    exit 1
  end
  @mfm = MultiFormManager.new(@pos_data)

  def ignore_form?(name)
    return false if @all
    return true if name =~ /Worksheet/
    return false if name =~ /^[A-Z0-9-]*\d[A-Z0-9-]*(?: |$)/
    return true
  end

  def iterate_forms
    if ARGV.count == 1
      forms = @mgr.forms(ARGV[0])
      raise "No Form #{ARGV[0]} found" if forms.empty?
      forms.each do |form| yield(form) end
    else
      @mgr.each do |form|
        next if ignore_form?(form.name)
        yield(form)
      end
    end
  end

  if @fill_dir
    forms = {}
    iterate_forms do |form|
      if @mfm.has_form?(form.name)
        if forms.include?(form.name)
          forms[form.name] += 1
          filename = "#{form.name} ##{forms[form.name]}.pdf"
        else
          forms[form.name] = 1
          filename = "#{form.name}.pdf"
        end
        @mfm.fill_form(form, File.join(@fill_dir, filename))
      else
        warn("No position data for Form #{form.name}")
      end
    end
    exit
  end

  if ARGV.count == 0
    missing = {}
    @mgr.each do |form|
      next if ignore_form?(form.name)

      if @mfm.has_form?(form.name)
        form.line.each do |l, v|
          next if l.end_with?('!')
          all_lines = [ l ]
          if v.is_a?(Array) && v.count > 1
            # Anything over 3 lines and we can assume a continuation can be used
            all_lines.push(*(2..([ v.count, 3 ].min)).map { |x| "#{l}##{x}" })
          end
          all_lines.each do |line|
            unless @mfm.has_form_line?(form.name, line)
              (missing[form.name] ||= {})[line] = true
              break
            end
          end
        end
      else
        missing[form.name] = true
      end
    end

    if missing.empty?
      puts "All forms and lines have position data; done!"
      exit
    end

    puts "Unprocessed forms/lines:"
    missing.each do |form, lines|
      if lines.is_a?(Hash)
        puts "  #{form}, Lines #{lines.keys.join(", ")}"
      else
        puts "  #{form}"
      end
    end
    puts "Enter a form name as an argument to this command to process it"
    exit
  end

  @form_name = ARGV.shift
  @form_file = ARGV.shift
  if @mfm.has_form?(@form_name)
  elsif !@form_file
    warn("No blank PDF for Form #{@form_name}; trying to download.")
    uname = case @form_name
            when /^\d{4}$/ then "f#@form_name"
            when /^(\d{4}) Schedule (\w+)/ then "f#$1s#$2"
            else raise "Can't determine form URL"
            end
    url = "https://www.irs.gov/pub/irs-pdf/#{uname}.pdf"
    @form_file = "blank/#{uname}.pdf"
    system('curl', '--output', @form_file, url)
  end
end
require 'tk'
require 'tkextlib/tkimg/png'
require 'tkextlib/bwidget'

if __FILE__ == $0
  @mfm.mark_form(@mgr.forms(@form_name), @form_file)
  open(@pos_data, 'w') do |f|
    @mfm.export(f)
  end
end
