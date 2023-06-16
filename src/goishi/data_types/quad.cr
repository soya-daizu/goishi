module Goishi
  struct Quad
    getter a : Point
    getter b : Point
    getter c : Point
    getter d : Point
    getter center : Point
    getter color : UInt8

    {% for x in {:a, :b, :c, :d} %}
      {% for y in {:a, :b, :c, :d} %}
        {% if x != y %}
          getter {{x.id}}{{y.id}} : Point { {{y.id}} - {{x.id}} }
        {% end %}
      {% end %}

      getter inner_{{x.id}} : Point do
        vec_to_center = @center - {{x.id}}
        {{x.id}} + vec_to_center.unit_vec * (vec_to_center.length / 3.5) / 2
      end
    {% end %}

    getter w_vec : Point { (ab + cd) / 2 }
    getter h_vec : Point { (ac + bd) / 2 }
    getter width : Float64 { w_vec.length }
    getter height : Float64 { h_vec.length }

    def initialize(pair1 : Tuple(Point, Point), pair2 : Tuple(Point, Point), @center, @color)
      if pair1[0].x <= pair2[0].x
        @a, @d = pair1
        @b, @c = pair2
      else
        @a, @d = pair2
        @b, @c = pair1
      end
    end

    def intersecting_side(to_quad : Quad)
      intersection = Point.intersection(a, b, @center, to_quad.center, true)
      return { {a, b}, intersection } if intersection
      intersection = Point.intersection(c, d, @center, to_quad.center, true)
      return { {c, d}, intersection } if intersection
      intersection = Point.intersection(a, c, @center, to_quad.center, true)
      return { {a, c}, intersection } if intersection
      intersection = Point.intersection(b, d, @center, to_quad.center, true)
      return { {b, d}, intersection } if intersection
    end

    def closer_vec(vec : Point)
      w_vec, h_vec = self.w_vec, self.h_vec

      w_sin_sita = Point.angle_between(vec, w_vec).abs
      h_sin_sita = Point.angle_between(vec, h_vec).abs

      w_sin_sita <= h_sin_sita ? w_vec : h_vec
    end

    def add_to_visualizer(text : String)
      Visualizer.add_point(@center, "#ff00ff")
      Visualizer.add_point(@a, "#ff0000")
      Visualizer.add_point(@b, "#0000ff")
      Visualizer.add_point(@c, "#00ff00")
      Visualizer.add_point(@d, "#ffff00")
      Visualizer.add_line(@a, @b, "#ff00ff")
      Visualizer.add_line(@c, @d, "#ff00ff")
      Visualizer.add_line(@a, @c, "#ff00ff")
      Visualizer.add_line(@b, @d, "#ff00ff")
      Visualizer.add_text(@center, text)
    end
  end
end
