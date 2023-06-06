require "./locator/*"

module Goishi
  struct LocatorSession
    include QRLocator
    include MQRLocator

    @data : Canvas(UInt8)?
    @finder_quads : Array(Quad)

    def initialize
      @finder_quads = [] of Quad
    end

    private def data
      raise "Data not loaded" unless @data
      @data.not_nil!
    end

    def set_data(data : Canvas(UInt8))
      center = Point.new(data.size_x / 2, data.size_y / 2)

      @data = data
      @finder_quads = LineScanner.scan_finder_pat(data).to_a
      @finder_quads.sort_by! do |q|
        q_center = q.center
        score = 0
        # Prefer patterns with b:w:bbb:w:b
        score += 25 if q.color == 1
        # Penalize patterns that are far from the center
        distance = Point.distance(q_center, center) / ((data.size_x + data.size_y) / 2)
        score -= distance * 100
        # Prefer patterns that are detected with more scan lines
        score += (q.x_scan_count + q.y_scan_count) ** 2
        # Penalize patterns that the center does not match the color
        score -= 100 if data[q_center]? != q.color

        score += (1.0 - (q.width / q.height)).abs * 25

        -score.round_even.to_i
      end
      # pp! @finder_quads.map(&.center)
    end

    private def refine_unit(point : Point, vec : Point, color : UInt8)
      temp_point = point
      color_changes, prev_color = 0, color
      until color_changes == 3
        c = data[temp_point -= vec]? || break
        next if c == prev_color

        color_changes += 1
        prev_color = c
      end
      p1 = temp_point + vec

      temp_point = point
      color_changes, prev_color = 0, color
      until color_changes == 3
        c = data[temp_point += vec]? || break
        next if c == prev_color

        color_changes += 1
        prev_color = c
      end
      p2 = temp_point - vec

      dist = Point.distance(p1, p2)
      (dist / 7).round_even
    end

    # Recenter the point by performing runs in both direction
    private def refine_center(point : Point, color : UInt8)
      temp_x = point.x.to_i
      temp_y = point.y.to_i

      until data[temp_x - 1, temp_y]? != color
        temp_x -= 1
      end
      left = temp_x
      temp_x = point.x.to_i
      until data[temp_x + 1, temp_y]? != color
        temp_x += 1
      end
      right = temp_x
      new_x = ((left + right) / 2)

      temp_x = new_x.to_i
      until data[temp_x, temp_y - 1]? != color
        temp_y -= 1
      end
      top = temp_y
      temp_y = point.y.to_i
      until data[temp_x, temp_y + 1]? != color
        temp_y += 1
      end
      bottom = temp_y
      new_y = ((top + bottom) / 2)

      Point.new(new_x, new_y)
    end

    # Get intersection point of EF and GH
    private def intersection(e : Point, f : Point, g : Point, h : Point)
      ef, gh = (f - e), (h - g)

      deno = Point.cross_prod(ef, gh)
      return if deno == 0

      eg = g - e
      s = Point.cross_prod(eg, gh) / deno
      # t = Point.cross_prod(b - a, a - c) / deno

      Point.new(e.x + s * ef.x, e.y + s * ef.y)
    end
  end
end
