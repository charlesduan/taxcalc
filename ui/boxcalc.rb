require_relative 'models'

class BoxCalculator

  include Marking

  def initialize(app, maxdx = 72 * 6, maxdy = 72)
    @app = app
    @maxdx = maxdx
    @maxdy = maxdy
    @min_width = 20
    @max_color_diff = 10
    @max_errs = 5
    @max_err_frac = 0.1
  end

  def compute_box_at_point(x, y = nil)
    p = y.nil? ? x.round : Point.new(x.round, y.round)

    max_rect = surface_rect
    return nil unless max_rect.include?(p)

    # Bottom edge
    ymax = p + advance_line(p, p, Point.new(0, 1), @maxdy)

    # Right edge
    xmax = p + advance_line(p, ymax, Point.new(1, 0), @maxdx)

    # Left edge
    xmin = p + advance_line(p, ymax, Point.new(-1, 0), @maxdx)

    # Find the line immediately below the bottom edge (by 2px to be safe).
    # Calculate a left and right boundary based on this, and choose the more
    # reasonable boundary.
    ybot = ymax + Point.new(0, 2)
    if max_rect.include?(ybot)
      xbotmax = ymax + advance_line(ybot, ybot, Point.new(1, 0), @maxdx)
      xbotmin = ymax + advance_line(ybot, ybot, Point.new(-1, 0), @maxdx)
      xbotdiff = xbotmax.x - xbotmin.x
      if xbotdiff > @min_width
        xmax = xbotmax if xmax.x > xbotmax.x
        xmin = xbotmin if xmin.x < xbotmin.x
      end
    end

    # Top edge
    ymin = p + advance_line(
      Point.new(xmin.x, p.y), Point.new(xmax.x, p.y),
      Point.new(0, -1), @maxdy
    )

    return Rectangle.new(
      max_rect.constrain(Point.new(xmin.x, ymin.y)),
      max_rect.constrain(Point.new(xmax.x, ymax.y))
    )
  end

  def advance_line(pmin, pmax, increment, max_steps)
    last_delta = Origin
    1.upto(max_steps) do |i|
      delta = increment * i

      # The edges must match exactly
      break unless same_color(pmin, pmin + delta)
      break unless same_color(pmax, pmax + delta)

      # For other points, check for a threshold error
      errs, count = 0, 0
      pmin.upto(pmax) do |pt|
        count += 1
        errs += 1 unless same_color(pt, pt + delta)
      end
      break if errs > @max_errs
      break if errs.to_f / count > @max_err_frac
      last_delta = delta
    end
    return last_delta
  end

  def color_at(x, y = nil)
    x, y = x.x, x.y if y.nil?
    if x < 0 || y < 0 || x >= surface.width || y >= surface.height
      return [ -100, -100, -100, -100 ]
    end

    index = (y * surface.width + x) * 4
    return surface_data[index, 4].unpack("C*")
  end

  def same_color(p1, p2)
    color_at(p1).zip(color_at(p2)).each do |v1, v2|
      return false if (v1 - v2).abs > @max_color_diff
    end
    return true
  end

  def surface_data
    @app.surface_data
  end

  def surface
    @app.surface
  end

  def surface_rect
    Rectangle.new(Origin, Point.new(surface.width - 1, surface.height - 1))
  end

end
