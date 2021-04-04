class LinePosData

  def initialize(pdf_file, tax_form)
    @parser = PdfFileParser.new(pdf_file)

    @line_order = []
    @line_data = {}

    @notes = {}

    if tax_form.is_a?(TaxForm)
      @form_name = tax_form.name
      merge_lines(tax_form)
    else
      @form_name = tax_form.to_s
    end
  end

  def no_even_pages
    @parser.even_pages = false
  end

  def add_line_data(line, params)
    unless params.is_a?(Array) and params.count == 5
      raise "Invalid parameter #{params}"
    end
    @line_data[line.to_s] = params
    @line_order.push(line.to_s) unless @line_order.include?(line.to_s)
  end

  def merge_lines(tax_form)
    lines = []

    # Compute the set of line numbers that need to be added to this LinePosData,
    # which are all the line numbers plus extra numbers for array-type values
    tax_form.line.each do |l, v|
      next if l.end_with?('!')
      if tax_form.line.boxed?(l)
        1.upto(tax_form.line.embox(l).count) { |x|
          lines.push(x == 1 ? l : "#{l}##{x}")
        }
      else
        lines.push(l)
        if v.is_a?(Array) && v.count > 1
          lines.push(*(2..v.count).map { |x| "#{l}##{x}" })
        end
      end
    end

    # Swap @line_order and lines, so that the tax form's line order takes
    # precedence.
    @line_order, lines = lines, @line_order

    # Set a cursor insert_pos on array @line_order. For each value in lines, see
    # if it is already in @line_order; if so, move the cursor to that position.
    # Otherwise, advance the cursor and insert the line number from lines into
    # @line_order at that position, such that it will be placed after whatever
    # the last matching line number was. The cursor is initially set to -1 so
    # that non-matching values are placed at the start of the list.
    insert_pos = -1
    lines.each do |l|
      pos = @line_order.find_index(l)
      if pos
        insert_pos = pos
      else
        insert_pos += 1
        @line_order.insert(insert_pos, l)
      end
    end
  end

  def all_filled?
    @line_order.all? { |x| @line_data.include?(x) }
  end

  def lines(page = nil)
    return @line_order unless page
    return @line_order.select { |x| @line_data[x] && @line_data[x][0] == page }
  end

  def [](line)
    @line_data[line]
  end

  def []=(line, data)
    if data.nil?
      @line_data.delete(line)
      return
    end

    raise "Invalid data" unless data.is_a?(Array) and data.count == 5
    line = line.to_s
    @line_data[line] = data
    @line_order.push(line) unless @line_order.include?(line)
  end

  def show_ui
    until File.exist?(@parser.file)
      @parser.file = Interviewer.new.ask(
        "File name for Form #@form_name:"
      )
    end

    begin
      ui = MarkingUI.new(@parser, self)
      Tk.mainloop
    rescue SystemExit
    ensure
      @parser.cleanup
    end
  end

  def export(f = STDOUT)
    f.puts "Form #@form_name, File #{@parser.file}"
    @line_order.each do |line|
      next unless @line_data[line]
      f.puts "\t#{line}\t[ #{@line_data[line].join(", ")} ]"
    end
  end

  def start_fill
    @fill_data = []
    @continuation_lines = []
    @explanation_lines = []
  end

  #
  # Fill a multiple-entry line with an array of values.
  #
  def fill_multi(line, value)
    multi_lines = (0...value.count).map { |x|
      x.zero? ? line : "#{line}##{x + 1}"
    }
    if self[multi_lines.last]
      # If the form itself has enough spaces for the number of values given,
      # then just fill them.
      multi_lines.zip(value).each do |l, v|
        fill(l, v)
      end
      return
    else
      # Determine whether to suppress the continuation sheet message. It will
      # be suppressed if (1) another continuation message was displayed at
      # about the same height on the same page, (2) for which the line number
      # of that continuation message had the same prefix (including at least
      # one set of digits) as the current line number.
      if line =~ /^\D*\d+/
        start_num = $&
        page, x, y, w, h = *self[line]
        options = { :position => ContinuationPosData.new(start_num, page, y) }

        # @continuation_lines is a two-element array, the first item being a set
        # of options. Among those options, the :position option is a
        # ContinuationPosData object that allows for testing of whether the line
        # matches an existing continuation line record. The second item is an
        # array of lines to include on the continuation sheet; each item is a
        # two-element array of the line number and values array.
        @continuation_lines.each do |c_options, c_lines|
          if c_options[:position] == options[:position]
            c_lines.push([ line, value ])
            return
          end
        end
        @continuation_lines.push([ options, [ [ line, value ] ] ])
      else
        @continuation_lines.push([ {}, [ [ line, value ] ] ])
      end
      return fill(line, "See continuation sheet")
    end
  end

  def note_symbol(line)
    line = line.sub(/\*note$/, '')
    @notes[line] ||= '*' * (@notes.count + 1)
    return @notes[line]
  end

  def textify(line, value)
    offset = 0
    if value.is_a?(Float) && (value - value.round(2)).abs < 0.0000001
      res = "%.2f" % value
    else
      res = value.to_s.gsub("\n", "\\n")
    end
    if res.is_a?(Numeric) && res < 0
      res = "(#{res.sub(/^-/, '')})"
      offset += 1
    end
    if line =~ /\*note$/
      sym = note_symbol(line)
      res = sym + res
    elsif @line_data.include?("#{line}*note")
      sym = note_symbol(line)
      res += sym
      offset += sym.length
    end
    return [res, offset]
  end

  def fill(line, value)
    if value.is_a?(Array)
      return fill_multi(line, value)
    end

    page, x, y, w, h = *self[line]
    ypos = [ 0, h - 9, 3 ].sort[1] + y
    text, offset = textify(line, value)
    res = [
      "-add-text", text,
      "-font", "Courier", "-font-size", "10",
      "-range", "#{page}"
    ]
    if value.is_a?(Numeric) or value.is_a?(BlankNum)
      xpos = w - [ 0, w - 8, 6 ].sort[1] + x
      xpos += 6 * offset
      res.push("-pos-right")
    elsif value == "X"
      xpos, ypos = x + w / 2, y + h / 2
      res.push("-midline", "-pos-center")
    else
      xpos = [ 0, w - 8, 6 ].sort[1] + x
      res.push("-pos-left")
      ypos = y + h - 10 if text =~ /\\n/
    end
    res.push("#{xpos} #{ypos}")
    @fill_data.push(res)
  end

  #
  # Adds an explanatory text.
  #
  def add_explanation(line, value)
    @explanation_lines.push(value)
  end

  #
  # Adds a manually-entered table that contains all the lines of a tax form.
  #
  def add_continuation_table(form)
    lines = form.line.to_a
    @continuation_lines.push([ { :title => form.name }, lines ])
  end

  def make_continuation(bio)
    return nil if @continuation_lines.empty? && @explanation_lines.empty?

    text = ""
    text << <<-EOF
.PRINTSTYLE TYPESET
.T_MARGIN 1i
.FAMILY H
.PARA_INDENT 0p
.PARA_SPACE
.START
    EOF
    text << "\\f[B]Form #@form_name Continuation Sheet\\f[]\n.PP\n"
    text << bio.gsub("\n", "\n.PP\n") + "\n.PP\n"

    @explanation_lines.each do |explanation|
      text << "\\f[B]#{explanation[0]}\\f[]\n.PP\n"
      text << explanation[1..-1].join("\n") + "\n.PP\n"
    end

    @continuation_lines.each do |options, lines|

      if options[:title]
        text << "\\f[B]#{options[:title]}\\f[]\n.PP\n"
      end

      if lines.count == 1 && !lines[0][1].is_a?(Array)
        l, v = *lines[0]
        text << "Line #{l}: #{v}\n\n"

      elsif lines.none? { |l, v| v.is_a?(Array) }
        # TODO Should output line numbers in left column, values in right

      else

        # Each line is assumed to contain an array of values. The table will be
        # shown with line numbers at the top and values for each line in
        # columns.
        #
        # First, review each line to figure out its alignment and to convert all
        # the values to text. Each item in the elements array contains [0] the
        # line number, [1] the alignment, and [2] the array of values.
        elements = lines.map { |l, v|
          v = [ v ].flatten
          align = (v.all? { |x| x.is_a?(Numeric) }) ? 'R' : 'L'
          [ l.to_s, align, v.map { |x| textify(l, x)[0] } ]
        }

        #
        # The longest element of each line will be the metric for the column
        # width. (Presumably the alignment value isn't the longest.) Then
        # generate the string tabs line; see
        # https://www.schaffter.ca/mom/momdoc/typesetting.html#string-tabs
        #
        text << ".SILENT\n"
        text << ".PAD \""
        1.upto(elements.length) do |i|
          longest = elements[i - 1].flatten.max_by(&:length)
          text << "\\*[FWD 1p]" if i > 1
          text << "\\*[ST#{i}]#{longest}#\\*[ST#{i}X]"
        end
        text << "\"\n"
        text << ".SILENT OFF\n"

        #
        # Generate the tab definition lines.
        #
        1.upto(elements.length) do |i|
          text << ".ST #{i} #{elements[i - 1][1]} QUAD\n"
        end

        # Generate the header
        text << ".TAB 1\n" << elements.map { |e|
          "\\f[B]#{e[0]}\\f[]"
        }.join("\\*[TB+]\n") << "\n"

        # Compute the number of rows in the table and print out each row.
        0.upto(elements.map { |x| x[2].count }.max - 1) do |i|
          text << ".TAB 1\n" << elements.map { |e|
            e[2][i] || ''
          }.join("\\*[TB+]\n") << "\n"
        end

        text << ".TQ"

      end
    end
    return text
  end

  def end_fill(filename)
    @parser.fill_form(@fill_data, filename)
  end

  # Adds the continuation data to the output PDF.
  def add_continuation(continuation_data, filename)
    @parser.add_continuation(continuation_data, filename)
  end



  class ContinuationPosData
    def initialize(start_num, page, y)
      @start_num, @page, @y = start_num, page, y
    end
    attr_reader :start_num, :page, :y
    def ==(obj)
      return false unless obj.is_a?(ContinuationPosData)
      return false unless obj.start_num == @start_num && obj.page == @page
      return false unless (obj.y - @y).abs < 10
      return true
    end
  end

end


