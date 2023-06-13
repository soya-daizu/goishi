module Goishi
  struct Point
    getter x : Float64
    getter y : Float64
    getter length : Float64 { Math.sqrt(@x ** 2 + @y ** 2) }

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

    def unit_vec
      self / self.length
    end

    def min(a : Float64, b : Float64)
      @x = Math.min(@x, a)
      @y = Math.min(@y, b)
    end

    def max(a : Float64, b : Float64)
      @x = Math.max(@x, a)
      @y = Math.max(@y, b)
    end

    # Get intersection point of EF and GH.
    # If `segment` is true, EF and GH are treated as line segments.
    def self.intersection(e : Point, f : Point, g : Point, h : Point, segment : Bool = false)
      ef, gh = (f - e), (h - g)

      deno = Point.cross_prod(ef, gh)
      return if deno == 0

      eg, ge = (g - e), (e - g)
      s = Point.cross_prod(eg, gh) / deno
      t = Point.cross_prod(ef, ge) / deno
      return if segment && !((0..1).includes?(s) && (0..1).includes?(t))

      Point.new(e.x + s * ef.x, e.y + s * ef.y)
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
