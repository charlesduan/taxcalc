require 'minitest/autorun'
require_relative '../models'

class ShapesTest < Minitest::Test

  include Marking

  def test_point
    p = Point.new(3, 5)
    assert_equal(3, p.x)
    assert_equal(5, p.y)
  end

  def test_point_equal
    p1 = Point.new(3, 5)
    p2 = Point.new(3, 5)
    p3 = Point.new(4, 5)
    p4 = Point.new(3, 6)

    assert_equal(p1, p2)
    assert(p1 != p3)
    assert(p1 != p4)
  end

  def test_math
    p1 = Point.new(3, 5)
    p2 = Point.new(1, 2)

    assert_equal(Point.new(4, 7), p1 + p2)
    assert_equal(Point.new(2, 3), p1 - p2)

    assert_equal(Point.new(6, 10), p1 * 2)
    assert_equal(Point.new(1.5, 2.5), p1 / 2.0)

    assert_equal(p1, p1.round)
    assert_equal(Point.new(4, 5), Point.new(4.3, 4.9).round)
  end

  def test_point_compare
    p = Point.new(3, 4)
    assert(p < Point.new(4, 5))
    assert(p < Point.new(3, 5))
    assert(p < Point.new(4, 4))
    assert(p < Point.new(4, 2))
    assert(p > Point.new(2, 5))
  end

  def test_point_next_toward
    p = Point.new(3, 4)
    assert_equal(Point.new(4, 4), p.next_toward(Point.new(10, 10)))
    assert_equal(Point.new(4, 4), p.next_toward(Point.new(10, 4)))
    assert_equal(Point.new(3, 5), p.next_toward(Point.new(3, 10)))
    assert_equal(Point.new(2, 4), p.next_toward(Point.new(0, 0)))
    assert_nil(p.next_toward(p))
  end

  def test_upto
    p1 = Point.new(3, 4)
    p2 = Point.new(5, 6)
    arr = []
    p1.upto(p2) do |pt| arr.push(pt) end
    assert_equal([
      Point.new(3, 4),
      Point.new(4, 4),
      Point.new(5, 4),
      Point.new(5, 5),
      Point.new(5, 6)
    ], arr)
  end

  def test_point_to_s
    assert_equal("(3, 4)", Point.new(3, 4).to_s)
  end

  def test_rect
    r1 = Rectangle.new(1, 2, 3, 4)
    assert_equal(r1, r1)
    r2 = Rectangle.new(Point.new(3, 4), Point.new(1, 2))
    assert_equal(r1, r2)
    r3 = Rectangle.new(3, 2, 1, 4)
    assert_equal(r1, r3)
  end

  def test_rect_width_height
    r1 = Rectangle.new(1, 2, 3, 5)
    assert_equal 2, r1.width
    assert_equal 3, r1.height
  end

  def test_rect_include
    r = Rectangle.new(1, 2, 3, 5)
    assert r.include?(Point.new(1, 2))
    assert r.include?(Point.new(2, 4))
    assert r.include?(Point.new(1, 5))
    assert !r.include?(Point.new(1, 6))
    assert !r.include?(Point.new(1, 1))
    assert !r.include?(Point.new(0, 4))
    assert !r.include?(Point.new(4, 4))
  end

  def test_rect_constrain
    r = Rectangle.new(1, 2, 3, 5)
    assert_equal(Point.new(1, 2), r.constrain(Point.new(1, 2)))
    assert_equal(Point.new(2, 4), r.constrain(Point.new(2, 4)))
    assert_equal(Point.new(1, 5), r.constrain(Point.new(1, 5)))
    assert_equal(Point.new(1, 5), r.constrain(Point.new(1, 6)))
    assert_equal(Point.new(1, 2), r.constrain(Point.new(1, 1)))
    assert_equal(Point.new(1, 4), r.constrain(Point.new(0, 4)))
    assert_equal(Point.new(3, 4), r.constrain(Point.new(4, 4)))
    assert_equal(Point.new(3, 5), r.constrain(Point.new(7, 7)))
    assert_equal(Point.new(1, 2), r.constrain(Point.new(0, 0)))
  end

  def test_rect_math
    r = Rectangle.new(1, 2, 3, 5)
    assert_equal(Rectangle.new(2, 4, 6, 10), r * 2)
    assert_equal(Rectangle.new(0.5, 1.0, 1.5, 2.5), r / 2.0)
  end

  def test_rect_center
    r = Rectangle.new(1, 2, 3, 5)
    assert_equal(Point.new(2, 3), r.center)
  end

  def test_rect_convert
    r = Rectangle.new(1, 2, 3, 5)
    assert_equal([ 1, 2, 3, 5 ], r.to_a)
    assert_equal("[(1, 2)--(3, 5)]", r.to_s)
  end

  def test_rect_split_point
    r = Rectangle.new(1, 2, 3, 5)
    assert_equal(Point.new(4, 3), r.next_split_start_point)
  end



end
