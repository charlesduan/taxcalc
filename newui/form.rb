class Marking

  #
  # A tax form's line position data. The form is identified by name, associated
  # with a PDF file, and contains an array of Line objects.
  class Form

    def initialize(obj = {})
      @name = obj['name']
      @file = obj['file']
      @lines = (obj['lines'] || []).map { |line_obj| Line.new(line_obj) }
    end

    attr_accessor :name, :file

    #
    # Upon setting the file, clear @lines because the data is not valid.
    #
    def file=(filename)
      @file = filename
      @lines = []
    end

    #
    # Given a TaxForm object, add lines in that form to this object so that
    # their positions can be marked.
    #
    def merge_lines(tax_form)
      unless tax_form.name == @name
        raise "Wrong form #{tax_form.name} for Marking::Form #@name"
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

    #
    # Receives line data from the UI and updates the Form.
    #
    def update(obj)
      name = obj['name']

      if name =~ /\[(\d+)\]\z/
        name, boxnum = $`, $1.to_i
        pos = @lines.find_index { |l| l.name == name }
        if pos
          if @lines[pos].is_a?(BoxLine)
            bl = @lines[pos]
          else
            bl = @lines[pos] = BoxLine.new('name' => name)
          end
        else
          bl = BoxLine.new('name' => name)
          @lines.push(bl)
        end
        bl.update(obj)

      else
        pos = @lines.find_index { |l| l.name == name }
        if pos
          @lines[pos] = Line.new(obj)
        else
          @lines.push(Line.new(obj))
        end
      end
    end

    #
    # Exports this object in a proto-JSON format.
    #
    def to_obj
      return {
        'name' => @name,
        'file' => @file,
        'lines' => @lines.map { |line| line.to_obj }
      }
    end

  end

  class Line
    def initialize(obj = {})
      @name = obj['name']
      @pos = obj['pos'] && Position.new(obj['pos'])
    end

    def to_obj
      res = { 'name' => @name }
      res['pos'] = @pos.to_obj if @pos
      return res
    end

  end

  class BoxLine < Line

    def initialize(obj = {})
      @name = obj['name']
      @pos = (obj['pos'] || []).map { |pos| Position.new(pos) }
      @split = obj['split'] || ''
    end

    def to_obj
      return {
        'name' => @name,
        'pos' => @pos.map { |p| p.to_obj },
        'split' => @split,
      }
    end

    def update(obj)
      raise "Invalid BoxLine update name" unless obj.name =~ /\[(\d+)\]\z/
      name, num = $`, $1.to_i
      unless num > 0 && num - 1 <= @pos.count
        raise "Invalid BoxLine update number"
      end
      @pos[(num - 1)..-1] = Position.new(obj['pos'])
      @split = obj['split'] if obj['split']
    end

  end

  class Position
    def initialize(obj = {})
      @page = obj['p']
      @x = obj['x']
      @y = obj['y']
      @width = obj['w']
      @height = obj['h']
    end

    def to_obj
      return {
        'p' => @page,
        'x' => @x,
        'y' => @y,
        'w' => @width,
        'h' => @height,
      }
    end
  end

end

