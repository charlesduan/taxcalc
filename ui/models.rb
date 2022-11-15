require 'open-uri'

class Marking

  #
  # A tax form's line position data. The form is identified by name, associated
  # with a PDF file, and contains an array of Line objects initially empty.
  class Form

    def initialize(formname)
      @name = formname
      @file = nil
      @lines = []
    end

    attr_reader :name, :file, :lines

    def line_names
      @lines.map(&:name)
    end

    #
    # Upon setting the file, clear @lines because the data is not valid.
    #
    def file=(filename)
      @file = filename
      @lines.each(&:reset)
    end

    #
    # Returns the predicted URL for the form.
    #
    def file_url
      uname = case @name
              when /^\d{4}$/ then "f#@name"
              when /^\d{4}X$/ then "f#{@name.downcase}"
              when /^(\d{4})-(\w+)$/ then "f#$1#$2".downcase
              when /^(\d{4})-(\w+) Schedule (\w+)$/ then "f#$1#$2#$3".downcase
              when /^(\d{4}) Schedule (\w+)$/ then "f#$1s#$2".downcase
              when /Pub\. ([\w-]+)/ then "p#$1".downcase.gsub('-', '')
              when /^1040 .*Worksheet/ then "i1040gi"
              when /^(\d{4}) .*Worksheet/ then "i#$1"
              else raise "Can't determine form URL"
              end
      return "https://www.irs.gov/pub/irs-pdf/#{uname}.pdf"
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

      new_lines = tax_form.line.map { |l, v|
        next [] if l.end_with?("!")
        v.is_a?(Array) ? [ l, *(2..v.length).map { |i| "#{l}##{i}" } ] : l
      }.flatten

      # This is going to be the replacement object for @lines. Initially, each
      # line in the form becomes a new Line object with no defined position.
      # This ensures that the order of the lines most closely matches the
      # TaxForm.
      new_lines_obj = new_lines.map { |nl| Line.new(nl) }

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
      unless l.name.sub(/#.*/, '') == nl_name_nohash

        # Increment insert_pos further until the prefix doesn't match the
        # current one.
        while insert_pos < new_lines_obj.length
          break if new_lines_obj[insert_pos].name.sub(/#.*/, '') != nl_name_nohash
          insert_pos += 1
        end
      end
      return insert_pos
    end

    #
    # Returns true if all the lines are either (1) positioned or (2) an
    # array-type line where the first line of that array is positioned.
    #
    def all_positioned?
      return @lines.all? { |l|
        l.positioned? || (l.name =~ /#/ && line($`).positioned?)
      }
    end

  end

  class Line
    def initialize(name)
      @name = name
      reset
    end

    def reset
      @pos = nil
      @separator = nil
    end

    attr_reader :name, :separator

    def split?
      return !@separator.nil?
    end

    def positioned?
      if split?
        return !@pos.empty?
      else
        return !@pos.nil?
      end
    end

    def make_split(sep)
      raise "Invalid separator #{sep}" unless sep.is_a?(String)
      @separator = sep
      if @pos
        @pos = [ @pos ]
      else
        @pos = []
      end
    end

    def make_not_split
      @separator = nil
      @pos = @pos[0]
    end

    def separator=(sep)
      raise "Cannot set separator on non-split line" unless split?
      raise "Invalid separator #{sep}" unless sep.is_a?(String)
      @separator = sep
    end

    def split_count
      raise "Cannot call split_count on non-split line" unless split?
      return @pos.count
    end

    def split_id(i)
      raise "Cannot call split_id on non-split line" unless split?
      return "#{name}[#{i}]"
    end

    def page
      if split?
        return @pos[0] && @pos[0].page
      else
        return @pos && @pos.page
      end
    end

    def pos(index = nil)
      if split?
        return @pos[index - 1]
      else
        raise "pos for non-split line takes no index" unless index.nil?
        return @pos
      end
    end

    # Returns the lower left coordinate.
    def lower_left
      unless positioned?
        raise "Check that lower_left is only called on positioned lines"
      end
      if split?
        return [ pos.first.min_x, pos.first.max_y ]
      else
        return [ pos.min_x, pos.max_y ]
      end
    end

    #
    # Adds a position for this line. If this is a split line, then the position
    # is added as the next split box, and the ID of the newly created box is
    # returned. Otherwise, sets the position for the line.
    #
    def add_pos(pos)
      unless pos.is_a?(Position)
        warn("Invalid Position #{pos} for Line #@name")
        return
      end
      if split?
        @pos.push(pos)
        return split_id(@pos.count)
      else
        @pos = pos
      end
    end

    #
    # Removes position data from this line. For a split line, removes all boxes
    # greater than or equal to the given index, and returns a reversed list of
    # the box IDs removed. Otherwise, returns a single-element array of the line
    # number itself.
    #
    def remove_pos(index = nil)
      if split?
        old_count = split_count
        @pos[(index - 1)..-1] = []
        return (index..old_count).to_a.reverse.map { |i| split_id(i) }
      else
        @pos = nil
        return [ @name ]
      end
    end

  end

  class Position
    def initialize(page, pos)
      @page = page
      @min_x, @min_y, @max_x, @max_y = *pos
    end

    attr_accessor :page, :min_x, :min_y, :max_x, :max_y

    def to_a
      [ @min_x, @min_y, @max_x, @max_y ]
    end

    def to_s
      "Position (#@min_x, #@min_y)..(#@max_x, #@max_y)"
    end

    def w
      @max_x - @min_x
    end

    def h
      @max_y - @min_y
    end

    def x
      @min_x
    end

    def y
      @min_y
    end

    def too_small?
      return (w < 6 || h < 6)
    end

  end

end

