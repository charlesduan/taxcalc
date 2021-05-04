require_relative 'pdf_assembler'

class FormFiller

  def initialize(posdata, manager)
    @posdata = posdata
    @manager = manager
    @even_pages = true
  end

  attr_accessor :continuation_bio
  attr_accessor :even_pages

  def has_form?(form_name)
    @posdata.include?(form_name)
  end

  def has_form_line?(form_name, line)
    !@posdata[form_name].line(line).nil?
  end

  def fill_form(tax_form, outfile)

    @note_syms = compute_note_symbols(tax_form)

    @fill_data = []
    @continuation_lines = []
    @explanation_lines = []

    pos_form = @posdata[tax_form.name]
    @assembler = PdfAssembler.new(pos_form.file, outfile)
    @assembler.even_pages = @even_pages
    unless pos_form
      warn("No form data for filling in #{tax_form.name}")
      return
    end

    tax_form.line.each do |l, v|
      if l =~ /explanation!$/
        @explanation_lines.push(v)
      elsif l == 'continuation!'
        continuation_form = form.manager.form(v)
        @continuation_lines.push([
          { :title => continuation_form.name },
          form.line.to_a
        ])
      elsif l.end_with?("!") # Ignore
      elsif v.is_a?(Array)
        fill_multi(l, v)
      elsif pos_form.line(l)
        fill_line(pos_form.line(l), v)
      else
        STDERR.puts("No position data for form #{tax_form.name}, line #{l}")
      end
    end
    @assembler.fill_form(@fill_data)
    ct = make_continuation(tax_form.name)
    @assembler.add_continuation(ct) if ct
  end

  def compute_note_symbols(tax_form)
    syms = %w(* + ^ ** ++ ^^ *** +++ ^^^ **** ++++ ^^^^)
    note_syms = {}
    tax_form.line.each do |l, v|
      next unless l =~ /\*note$/
      raise "Too many notes" if syms.empty?
      note_syms[l] = note_syms[$`] = syms.shift
    end
    return note_syms
  end

  def fill_line(marking_line, value)
    if marking_line.split?
      value.to_s.split(
        marking_line.separator, marking_line.split_count
      ).each_with_index do |v, i|
        insert_value(marking_line.pos(i), marking_line.name, v)
      end
    else
      insert_value(marking_line.pos, marking_line.name, value)
    end
  end

  def insert_value(pos, line_name, value)
    puts "Inserting value #{value} for #{line_name} at #{pos}"
    text, offset = textify(line_name, value)
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
    if res.is_a?(Numeric) && res < 0
      res = "(#{res.sub(/^-/, '')})"
      offset += 1
    end
    if line =~ /\*note$/
      res = @note_syms[line] + res
    elsif @note_syms[line]
      res += @note_syms[line]
      offset += sym.length
    end
    return [res, offset]
  end

  def make_continuation(form_name)
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
    text << "\\f[B]Form #{form_name} Continuation Sheet\\f[]\n.PP\n"
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


end
