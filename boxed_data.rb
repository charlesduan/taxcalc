#
# A data structure for line data that is meant to go in individual boxes for
# parts of the data.
#
class BoxedData
  def initialize(split, count, data)
    @split, @count, @data = split, count, data
  end

  attr_reader :split, :count, :data

  def to_s
    data.to_s
  end

end
