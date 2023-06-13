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
      @data = data
      @finder_quads.clear

      LineScanner.scan_finder_pat(data).each do |sg|
        q = test_finder_scangroup(sg)
        @finder_quads.push(q) if q
      end

      Visualizer.set_data(data)
      @finder_quads.sort_by! do |q|
        score = 0
        # Prefer patterns with b:w:bbb:w:b
        score += 25 if q.color == 1
        # Prefer bigger patterns
        score += q.longest_side_length

        # Prefer near-square patterns
        q_width, q_height = q.w_vec.length, q.h_vec.length
        score *= Math.min(q_width, q_height) / Math.max(q_width, q_height)

        # Visualizer.add_line(q.a, q.b, "#ff00ff")
        # Visualizer.add_line(q.c, q.d, "#ff00ff")
        # Visualizer.add_line(q.a, q.c, "#ff00ff")
        # Visualizer.add_line(q.b, q.d, "#ff00ff")
        # Visualizer.add_point(q.center, "#ff00ff")
        # Visualizer.add_point(q.a, "#ff0000")
        # Visualizer.add_point(q.b, "#0000ff")
        # Visualizer.add_point(q.c, "#00ff00")
        # Visualizer.add_point(q.d, "#ffff00")
        # Visualizer.add_text(q.center, score.to_s)

        -score
      end
      Visualizer.export
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

    private def test_finder_scangroup(sg : ScanGroup)
      center = refine_center(sg.center, sg.color)

      vec = Point.new(1, 0)
      ray_groups = [[scan_finder_edges(center, vec, sg.color) || return]]
      179.times do |i|
        # Rotate the vector by 1°
        vec = Point.new(
          vec.x * Math.cos(Math::PI / 180) - vec.y * Math.sin(Math::PI / 180),
          vec.x * Math.sin(Math::PI / 180) + vec.y * Math.cos(Math::PI / 180),
        )

        # Find the two edges of the finder pattern in the current vector's direction
        # and group them together by their length
        pair, length = scan_finder_edges(center, vec, sg.color) || return
        if length == ray_groups.last[0][1]
          ray_groups.last.push({pair, length})
        else
          ray_groups.push([{pair, length}])
        end
      end

      scored_rays = [] of Tuple(Tuple(Point, Point), Float64)
      (0...ray_groups.size).each do |i|
        ray_lengths = {-2, -1, 0, 1, 2}.map { |j| (ray_groups[i + j]? || ray_groups[j - 1])[0][1] }
        next unless ray_lengths[1] < ray_lengths[2] && ray_lengths[2] > ray_lengths[3]

        pair, _ = ray_groups[i][ray_groups[i].size // 2]
        score = (pair[1] - pair[0]).length
        score += (ray_lengths[2] - ray_lengths[1])
        score += (ray_lengths[2] - ray_lengths[3])
        score *= 1.1 if ray_lengths[1] == ray_lengths[3]

        if ray_lengths[0] < ray_lengths[1] && ray_lengths[3] > ray_lengths[4]
          score += (ray_lengths[1] - ray_lengths[0])
          score += (ray_lengths[3] - ray_lengths[4])
          score *= 1.1 if ray_lengths[0] == ray_lengths[4]
          score *= 1.1 if ray_lengths[1] == ray_lengths[3]
        end

        scored_rays.push({pair, score})
      end
      return if scored_rays.empty?

      pair1, pair1_score = scored_rays.max_by { |x| x[1] }
      pair2, pair2_score = scored_rays.max_by do |item|
        pair2_cand, pair2_cand_score = item
        sin_sita = Point.angle_between(pair1[1] - pair1[0], pair2_cand[1] - pair2_cand[0]).abs
        score = (pair1_score + pair2_cand_score * 10) * Math.min(sin_sita, 0.9)
        score
      end

      Quad.new(pair1, pair2, center, sg.color)
    end

    private macro skip_same_color(operator, counter = nil)
      while true
        temp_point {{operator.id}}= vec
        c = data[temp_point]? || break
        {% if counter %}
          {{counter.id}} += 1
        {% end %}

        is_color_different = c != prev_color
        prev_color = c
        break if is_color_different
      end
    end

    private def scan_finder_edges(origin : Point, vec : Point, color : UInt8)
      temp_point, prev_color = origin, color
      len1_1, len1_2, len1_3 = 0, 0, 0
      skip_same_color(:-, len1_1)
      skip_same_color(:-, len1_2)
      skip_same_color(:-, len1_3)
      len1 = len1_1 + len1_2 + len1_3
      e1 = temp_point + vec

      temp_point, prev_color = origin, color
      len2_1, len2_2, len2_3 = 0, 0, 0
      skip_same_color(:+, len2_1)
      skip_same_color(:+, len2_2)
      skip_same_color(:+, len2_3)
      len2 = len2_1 + len2_2 + len2_3
      e2 = temp_point - vec

      len = len1 + len2 + 1
      unit = len / 7
      passed = {
        {1, len1_3},
        {1, len1_2},
        {3, len1_1 + len2_1 + 1},
        {1, len2_2},
        {1, len2_3},
      }.all? do |r, l|
        range = (((r - 1) * unit).round_even..((r + 1) * unit).round_even)
        range.includes?(l)
      end
      return unless passed

      return if (len2 - len1).abs / Math.min(len1, len2) > 2

      { {e1, e2}, len1 + len2 + 1 }
    end
  end
end
