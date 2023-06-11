module Goishi
  struct Quad
    getter a : Point
    getter b : Point
    getter c : Point
    getter d : Point
    getter center : Point

    def initialize(pair1 : Tuple(Point, Point), pair2 : Tuple(Point, Point), @center)
      if pair1[0].x <= pair2[0].x
        @a, @d = pair1
        @b, @c = pair2
      else
        @a, @d = pair2
        @b, @c = pair1
      end
    end

    {% for x in {:a, :b, :c, :d} %}
      {% for y in {:a, :b, :c, :d} %}
        {% if x != y %}
          def {{x.id}}{{y.id}}
            {{y.id}} - {{x.id}}
          end
        {% end %}
      {% end %}
    {% end %}

    def closer_vec(vec : Point)
      w_vec, h_vec = self.w_vec, self.h_vec

      w_sin_sita = Point.angle_between(vec, w_vec).abs
      h_sin_sita = Point.angle_between(vec, h_vec).abs

      return w_vec if w_sin_sita < h_sin_sita
      return h_vec if h_sin_sita < w_sin_sita
      w_vec
    end

    def w_vec
      (ab + cd) / 2
    end

    def h_vec
      (ac + bd) / 2
    end
  end
end
