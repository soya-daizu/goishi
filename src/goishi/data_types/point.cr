module Goishi
  struct Point
    getter x : Float64
    getter y : Float64

    def initialize(@x, @y)
    end

    def +(other : Point)
      Point.new(@x + other.x, @y + other.y)
    end

    def +(other : Float64)
      Point.new(@x + other, @y + other)
    end

    def -(other : Point)
      Point.new(@x - other.x, @y - other.y)
    end

    def -(other : Float64)
      Point.new(@x - other, @y - other)
    end

    def *(other : Point)
      Point.new(@x * other.x, @y * other.y)
    end

    def *(other : Float64)
      Point.new(@x * other, @y * other)
    end

    def /(other : Point)
      Point.new(@x / other.x, @y / other.y)
    end

    def /(other : Float64)
      Point.new(@x / other, @y / other)
    end

    def length
      Math.sqrt(@x ** 2 + @y ** 2)
    end

    def unit_vec
      self / self.length
    end

    def self.distance(a : Point, b : Point)
      Point.new(b.x - a.x, b.y - a.y).length
    end

    def self.cross_prod(a : Point, b : Point)
      a.x * b.y - a.y * b.x
    end

    # Returns the value of sin sita whose sita is the angle between the vector a and b
    def self.angle_between(a : Point, b : Point)
      # Reverse the cross product as y is positive towards the bottom
      -Point.cross_prod(a, b) / (a.length * b.length)
    end
  end
end
