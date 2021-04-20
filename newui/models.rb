require 'open-uri'

class Marking

  #
  # A tax form's line position data. The form is identified by name, associated
  # with a PDF file, and contains an array of Line objects initially empty.
  class Form

    def initialize(formname, filename)
      @name = formname
      @file = filename
      @lines = []
    end

    attr_accessor :name, :file

    def line_names
      @lines.map(&:name)
    end

    #
    # Upon setting the file, clear @lines because the data is not valid.
    #
    def file=(filename)
      @file = filename
      @lines = []
    end

    #
    # Downloads the form to the cache directory if it is not there already.
    #
    def download_form(cache_dir)
      uname = case @name
              when /^\d{4}$/ then "f#@name"
              when /^(\d{4}) Schedule (\w+)/ then "f#$1s#$2".downcase
              else raise "Can't determine form URL"
              end
      filename = File.join(cache_dir, uname)
      unless File.exist?(filename)
        url = "https://www.irs.gov/pub/irs-pdf/#{uname}.pdf"
        URI.open(url) do |url_io|
          File.open(filename, 'w') do |file_io|
            file_io.write(url_io.read)
          end
        end
      end
      self.file = filename
    end

    def line(num)
      return @lines.find { |l| l.name == num }
    end

    def add_line(num)
      line = Line.new(num)
      @lines.push(line)
      return line
    end

    #
    # Given a TaxForm object, add lines in that form to this object so that
    # their positions can be marked.
    #
    def merge_lines(tax_form)
      unless tax_form.name == @name
        raise "Wrong form #{tax_form.name} for #{self.class} #@name"
      end

      new_lines = form.line.map { |l, v|
        next [] if l.end_with?("!")
        v.is_a?(Array) ? [ l, *(2..v.length).map { |i| "#{l}##{i}" } ] : l
      }.flatten

      # This is going to be the replacement object for @lines. Initially, each
      # line in the form becomes a new Line object with no defined position.
      # This ensures that the order of the lines most closely matches the
      # TaxForm.
      new_lines_obj = new_lines.map { |nl| Line.new('name' => nl) }

      # insert_pos is a cursor to new_lines_obj that indicates which entry we
      # should insert any missing data after.
      insert_pos = -1

      # Now test each item in existing @lines to see where it should go with
      # respect to new_lines_obj.
      @lines.each do |l|
        pos = new_lines_obj.find_index { |nl| l.name == nl.name }
        if pos
          # If it is found, then replace the item in new_lines_pos with the one
          # from @lines, and move the insert_pos cursor to this item
          new_lines_obj[pos] = l
          insert_pos = pos

        else
          # Otherwise, advance the cursor and insert the item from @lines.
          insert_pos = advance_cursor(insert_pos, new_lines_obj, l)
          new_lines_obj.insert(insert_pos, l)
        end
      end
      @lines = new_lines_obj
    end

    #
    # Advances the cursor insert_pos to where the new item l should be inserted
    # into new_lines_obj. The cursor is advanced at least 1, but it might be
    # advanced more if (1) the cursor points to an array-type line, (2) 
    def advance_cursor(insert_pos, new_lines_obj, l)
      return 0 if insert_pos == -1
      insert_pos += 1 # In all cases, increment by at least one

      nl_name_nohash = new_lines_obj[insert_pos - 1].name.sub(/#.*/, '')

      # If this line and the current index line have the same prefix, then
      # don't do the next step
      unless l[name].sub(/#.*/, '') == nl_noname_hash

        # Increment insert_pos further until the prefix doesn't match the
        # current one.
        while insert_pos < new_lines_obj.length
          break if new_lines_obj[insert_pos].sub(/#.*/, '') != nl_noname_hash
          insert_pos += 1
        end
      end
      return insert_pos
    end

  end

  class Line
    def initialize(name)
      @name = name
      @pos = nil
      @separator = nil
    end

    def split?
      return !@separator.nil?
    end

    attr_reader :name

    def pos
      raise "Cannot call pos on line #@name; it is split" if split?
      return @pos
    end

    def add_pos(pos)
      unless pos.is_a?(Position)
        warn("Invalid Position #{pos} for Line #@name")
        return
      end
      if split?
        @pos.push(pos)
        return "#@name[#{@pos.count}]"
      else
        @pos = pos
      end
    end

    def ids_to_remove
      if split?
      else
        return @name
      end
    end
  end

  class SplitLine < Line

    def initialize(name)
      @name = name
      @pos = []
      @separator = ""
    end

    attr_reader :name
    attr_accessor :separator

    def to_obj
      return {
        'name' => @name,
        'pos' => @pos.map { |p| p.to_obj },
        'split' => @split,
      }
    end

  end

  class Position
    def initialize(page, pos)
      @page = page
      @min_x, @min_y, @max_x, @max_y = *pos
    end

    def to_a
      [ @min_x, @min_y, @max_x, @max_y ]
    end

  end

end

