class MultiFormManager

  def initialize(filename = '')
    @form_data = {}
    import(filename)
    @continuation_display = :show
  end

  attr_accessor :continuation_bio
  attr_accessor :continuation_display

  def import(filename)
    @filename = filename
    return unless File.exist?(filename)

    lpd = nil
    File.open(filename) do |f|
      f.each do |l|
        case l
        when /^Form (.*), File (.*)/
          lpd = @form_data[$1] = LinePosData.new($2, $1)
        when /^\s*$/
        when /^\s+/
          line_no, data = $'.strip.split(/\s+/, 2)
          data = Interviewer.parse(line_no, data)
          lpd.add_line_data(line_no, data)
        else
          STDERR.puts("Unexpected line in #{filename}: #{l}")
        end
      end
    end
  end

  def has_form?(form_name)
    @form_data.include?(form_name)
  end

  def has_form_line?(form_name, line)
    !@form_data[form_name][line].nil?
  end

  def mark_form(form, filename = nil)
    if form.is_a?(Array)
      extra_forms = form
      form = extra_forms.shift
    else
      extra_forms = []
    end

    if @form_data.include?(form.name)
      lpd = @form_data[form.name]
      lpd.merge_lines(form)
    else
      lpd = @form_data[form.name] = LinePosData.new(filename, form)
    end

    extra_forms.each do |f| lpd.merge_lines(f) end

    lpd.show_ui
  end

  def fill_form(form, filename, no_even_pages = false)
    lpd = @form_data[form.name]
    unless lpd
      warn("No form data for filling in #{form.name}")
      return
    end
    lpd.no_even_pages if no_even_pages
    lpd.start_fill

    form.line.each do |l, v|
      if l.end_with?("!") # Ignore
      elsif l =~ /explanation$/
        lpd.add_explanation(l, v)
      elsif l == 'continuation'
        lpd.add_continuation_table(form.manager.form(v))
      elsif lpd[l]
        if form.line.boxed?(l)
          lpd.fill(l, form.line.embox(l))
        else
          lpd.fill(l, v)
        end
      else
        STDERR.puts("No position data for form #{form.name}, line #{l}")
      end
    end
    ct = lpd.make_continuation(continuation_bio)
    lpd.end_fill(filename)
    if ct
      case @continuation_display
      when :raw then puts ct
      when :show
        IO.popen([ 'nroff', '-mom', '-t' ], 'w') do |io|
          io.write(ct)
        end
      when :append
        lpd.add_continuation(ct, filename)
      else
        raise "Unknown continuation display #@continuation_display"
      end
    end
  end

  def export(filename = @filename)
    File.open(filename, 'w') do |f|
      @form_data.each do |form, lpd|
        lpd.export(f)
        f.puts
      end
    end
  end

end


