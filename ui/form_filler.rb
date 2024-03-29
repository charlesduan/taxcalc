require_relative 'pdf_assembler'

class FormFiller

  def initialize(tax_form, pos_form)
    @tax_form, @pos_form = tax_form, pos_form
    @even_pages = true

    @fill_data = []

    # @continuation_lines is a two-element array. The first is a hash of
    # options; the second an array of line-value pairs for the continuation.
    # (See multi_line for further explanation.)
    @continuation_lines = []
    @explanation_lines = []


    @note_syms = compute_note_symbols

  end

  attr_accessor :continuation_bio
  attr_accessor :even_pages

  def fill(outfile)
    @assembler = PdfAssembler.new(@pos_form.file, outfile)
    @assembler.even_pages = @even_pages

    unless @pos_form
      warn("No position data for Form #{@tax_form.name}")
      return
    end
    unless @pos_form.file
      warn("No PDF file for Form #{@tax_form.name}")
      return
    end

    @tax_form.line.each do |l, v|
      if l =~ /explanation!$/
        @explanation_lines.push(v)
      elsif l == 'continuation!'
        continuation_form = @tax_form.manager.form(v)
        if continuation_form
          @continuation_lines.push([
            { :title => continuation_form.name },
            continuation_form.line.to_a
          ])
        else
          warn("Expected continuation Form #{v} not found")
        end

      elsif l.end_with?("!") # Ignore
      elsif v.is_a?(Array)
        fill_multi(l, v)
      else
        fill_line(@pos_form.line(l), v)
      end
    end
    @assembler.fill_form(@fill_data)
    ct = make_continuation
    @assembler.add_continuation(ct) if ct
  end

  def compute_note_symbols
    count = 1
    note_syms = {}
    @tax_form.line.each do |l, v|
      next unless l =~ /\*note$/
      ref_line = $`
      unless @tax_form.line[ref_line]
        warn("No line #{ref_line} corresponding to footnote")
      end
      note_syms[l] = note_syms[ref_line] = "*" * count
      count += 1
    end
    return note_syms
  end

  #
  # Fills a TaxForm line that is an array. This first converts the line name to
  # the convention of [line]#[array_pos], sees if the pos_form has enough slots,
  # and either fills them if so or produces a continuation sheet otherwise.
  #
  def fill_multi(line, array)
    # Compute the line names
    line_names = [ line, *(2..array.count).map { |x| "#{line}##{x}" } ]

    #
    # If the last line has a position, then fill all the lines.
    #
    last_line = @pos_form.line(line_names.last)
    if last_line && last_line.positioned?
      line_names.zip(array).each do |l, v|
        fill_line(@pos_form.line(l), v)
      end
      return
    end

    # A continuation sheet is needed at this point.
    first_line = @pos_form.line(line)
    unless first_line.positioned?
      warn("Line #{first_line.name} has no position data")
      return
    end

    #
    # Determine whether to suppress the continuation sheet message. First,
    # construct the options for this line. :prefix is the portion of the line
    # name up to the first numeric portion; :pos is the lower left corner of
    # where this line will go.
    options = {
      :prefix => line =~ /^\D*\d+/ ? $& : line,
      :pos_x => first_line.lower_left.first,
      :pos_y => first_line.lower_left.last,
    }
    # We look through the existing continuation lines to see if any of them
    # match this one, in the sense that they have the same prefix and are
    # vertically or horizontally aligned. If so, then append this line's data
    # onto the matching continuation and return.
    @continuation_lines.each do |c_options, c_lines|
      next unless c_options[:prefix] == options[:prefix]
      next if (c_options[:pos_x] - options[:pos_x]).abs > 10 and
        (c_options[:pos_y] - options[:pos_y]).abs > 10
      c_lines.push([ line, array ])
      return
    end
    # If no match is found, add a new entry to @continuation lines and fill this
    # line with the continuation message.
    @continuation_lines.push([ options, [ [ line, array ] ] ])
    fill_line(first_line, "See continuation sheet")
  end

  def fill_line(marking_line, value)
    if marking_line.nil?
      warn("Line to be filled is unknown; run marking program")
      return
    end
    unless marking_line.positioned?
      warn("Line #{marking_line.name} has no position data")
      return
    end

    if marking_line.split?
      split_val = value.to_s.split(
        marking_line.separator, marking_line.split_count
      )
      split_val.pop if split_val.last == ''

      if value.is_a?(Numeric) || value.is_a?(BlankNum)
        offset = 1 + marking_line.split_count - split_val.count
      else
        offset = 1
      end
      split_val.each_with_index do |v, i|
        insert_value(marking_line.pos(i + offset), marking_line.name, v)
      end

    else
      insert_value(marking_line.pos, marking_line.name, value)
    end
  end

  def insert_value(pos, line_name, value)
    text, offset = textify(line_name, value)
    # TODO: Should use the actual page height
    ypos = [ 0, pos.h - 9, 3 ].sort[1] + (792 - pos.max_y)
    res = [
      "-add-text", text,
      "-font", "Courier", "-font-size", "10",
      "-range", "#{pos.page}"
    ]
    if value.is_a?(Numeric) or value.is_a?(BlankNum)
      xpos = pos.w - [ 0, pos.w - 8, 6 ].sort[1] + pos.x
      xpos += 6 * offset
      res.push("-pos-right")
    elsif value == "X"
      xpos, ypos = pos.x + pos.w / 2, (792 - pos.max_y) + pos.h / 2
      res.push("-midline", "-pos-center")
    else
      xpos = [ 0, pos.w - 8, 6 ].sort[1] + pos.x
      res.push("-pos-left")
      ypos = (792 - pos.max_y) + pos.h - 10 if text =~ /\\n/
    end
    res.push("#{xpos} #{ypos}")
    @fill_data.push(res)
  end

  def textify(line, value)
    offset = 0
    if value.is_a?(Float) && (value - value.round(2)).abs < 0.0000001
      res = "%.2f" % value
    else
      res = value.to_s.gsub("\n", "\\n")
    end
    if value.is_a?(Numeric) && value < 0
      res = "(#{res.sub(/^-/, '')})"
      offset += 1
    end
    if line =~ /\*note$/
      res = @note_syms[line] + res
    elsif sym = @note_syms[line.split('/').last]
      res += sym
      offset += sym.length
    end
    return [res, offset]
  end

  def make_continuation
    return nil if @continuation_lines.empty? && @explanation_lines.empty?

    text = ""
    text << <<~EOF
      .PRINTSTYLE TYPESET
      .T_MARGIN 1i
      .FAMILY H
      .PARA_INDENT 0p
      .PARA_SPACE
      .START
    EOF
    text << "\\f[B]Form #{@tax_form.name} Continuation Sheet\\f[]\n.PP\n"
    text << @continuation_bio.gsub("\n", "\n.PP\n") + "\n.PP\n"

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
          align = (v.all? { |x|
            x.is_a?(Numeric) || x.is_a?(BlankNum)
          }) ? 'R' : 'L'
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

        text << ".TQ\n\n"

      end
    end
    return text
  end


end
