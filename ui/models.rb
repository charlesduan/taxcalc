require 'open-uri'

module Marking

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
              when /1040 Schedule 8812/ then 'f1040s8'
              when /^(\d{4}) Schedule (\w+)$/ then "f#$1s#$2".downcase
              when /^(\d{4}) Schedule (\w+)-(\w+)$/ then "f#$1s#$2#$3".downcase
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

  class Point
    def initialize(x, y)
      raise "Invalid point coordinate" unless x.is_a?(Numeric)
      raise "Invalid point coordinate" unless y.is_a?(Numeric)
      @x, @y = x, y
    end

    attr_reader :x, :y

    def ==(point)
      raise "Not a point" unless point.is_a?(Point)
      return @x == point.x && @y == point.y
    end

    def +(point, y = nil)
      point = Point.new(point, y) if y
      return Point.new(@x + point.x, @y + point.y)
    end

    def -(point, y = nil)
      point = Point.new(point, y) if y
      return Point.new(@x - point.x, @y - point.y)
    end

    def *(scale)
      return Point.new(@x * scale, @y * scale)
    end

    def /(scale)
      return Point.new(@x / scale, @y / scale)
    end

    def round
      return self if @x.integer? && @y.integer?
      return Point.new(x.round, y.round)
    end

    #
    # Compare points based first on their x coordinates and then on their y
    # coordinates if the x coordinates are equal.
    #
    def <=>(other)
      raise "Not a point" unless other.is_a?(Point)
      res = (@x <=> other.x)
      res = (@y <=> other.y) if res == 0
      return res
    end

    include Comparable

    #
    # Computes a point that moves one unit horizontally or vertically toward the
    # argument. Consistent with the <=> operator, it moves the x coordinate
    # first, then the y coordinate. If the points are the same, return nil.
    #
    def next_toward(other)
      raise "Not a point" unless other.is_a?(Point)

      #
      # This operation produces:
      # * If other.x > @x by more than 1, then 1
      # * If other.x < @x by more than 1, then -1
      # * Otherwise, other.x - @x
      # So adding xdiff to @x moves @x closer to other.x, but by a magnitude of
      # at most 1.
      #
      xdiff = [ -1, other.x - @x, 1 ].sort[1]
      if xdiff != 0
        return Point.new(@x + xdiff, @y)
      else
        ydiff = [ -1, other.y - @y, 1 ].sort[1]
        return nil if ydiff == 0
        return Point.new(@x, @y + ydiff)
      end
    end

    #
    # Computes all the points from this point to the given one, using the
    # next_toward method.
    #
    def upto(other)
      pt = self
      loop do
        yield(pt)
        pt = pt.next_toward(other)
        return unless pt
      end
    end

    def to_s
      return "(#@x, #@y)"
    end

  end # Point

  Origin = Point.new(0, 0)


  class Rectangle
    def initialize(*args)
      args = args[0] if args.count == 1 && args[0].is_a?(Array)
      if args.count == 4
        p1, p2 = Point.new(args[0], args[1]), Point.new(args[2], args[3])
      else
        p1, p2 = args[0], args[1]
      end
      raise "Not a point" unless p1.is_a?(Point)
      raise "Not a point" unless p2.is_a?(Point)

      # Order by x coordinate
      p1, p2 = p2, p1 if p1.x > p2.x

      # If y coordinates are out of order, then reconstruct points
      if p1.y > p2.y
        p1, p2 = Point.new(p1.x, p2.y), Point.new(p2.x, p1.y)
      end

      @min, @max = p1, p2
    end

    attr_reader :min, :max

    def ==(other)
      raise "Not a rectangle" unless other.is_a?(Rectangle)
      return (@min == other.min && @max == other.max)
    end

    def width
      return @max.x - @min.x
    end

    def height
      return @max.y - @min.y
    end

    def include?(point)
      return false if point.x < @min.x
      return false if point.x > @max.x
      return false if point.y < @min.y
      return false if point.y > @max.y
      return true
    end

    #
    # Returns a point that is closest to the given point and within this
    # rectangle.
    #
    def constrain(point)
      return point if include?(point)
      return Point.new(
        [ @min.x, point.x, @max.x ].sort[1],
        [ @min.y, point.y, @max.y ].sort[1],
      )
    end

    def *(scale)
      return Rectangle.new(@min * scale, @max * scale)
    end

    def /(scale)
      return Rectangle.new(@min / scale, @max / scale)
    end

    def center
      return Point.new((@min.x + @max.x) / 2, (@min.y + @max.y) / 2)
    end

    def to_a
      return [ @min.x, @min.y, @max.x, @max.y ]
    end

    def to_s
      return "[#@min--#@max]"
    end

    #
    # Positions a widget on a Gtk::Layout consistent with this rectangle.
    #
    def position_widget(widget, layout)
      widget.set_size_request(width, height)
      layout.put(widget, @min.x, @min.y)
    end

    #
    # A "split" line consists of a series of boxes horizontally next to each
    # other, which are about evenly spaced apart. This method calculates a good
    # starting point for guessing the next box of a split. The guessed point is
    # at the vertical midpoint of the rectangle, and half a rectangle to the
    # right.
    #
    def next_split_start_point
      return Point.new(@max.x + (width / 2), (@max.y + @min.y) / 2)
    end

  end # Rectangle


end

