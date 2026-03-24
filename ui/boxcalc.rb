require_relative 'models'

class BoxCalculator

  include Marking

  def initialize(app)
    @app = app
  end

  def compute_box_at_point(x, y)
  end

  def surface_data
    @app.surface_data
  end

  def surface
    @app.surface
  end

  def color_at(x, y = nil)
    x, y = x.x, x.y if y.nil?
    if x < 0 || y < 0 || x >= surface.width || y >= surface.height
      return [ -100, -100, -100, -100 ]
    end

    index = (y * surface.width + x) * 4
    return surface_data[index, 4].unpack("C*")
  end
end
