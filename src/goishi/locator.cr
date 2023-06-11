require "./locator/*"

module Goishi
  struct LocatorSession
    include QRLocator
    include MQRLocator

    @data : Canvas(UInt8)?
    @finder_scangroups : Array(ScanGroup)

    def initialize
      @finder_scangroups = [] of ScanGroup
    end

    private def data
      raise "Data not loaded" unless @data
      @data.not_nil!
    end

    def set_data(data : Canvas(UInt8))
      center = Point.new(data.size_x / 2, data.size_y / 2)

      @data = data
      @finder_scangroups = LineScanner.scan_finder_pat(data).to_a
      @finder_scangroups.sort_by! do |q|
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
      # pp! @finder_scangroups.map(&.center)
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

    private def scangroup_to_quad(sg : ScanGroup)
      scan1, scan2, center = find_finder_corners(sg) || return
      Quad.new(scan1, scan2, center)
    end

    private def find_finder_corners(sg : ScanGroup)
      center = refine_center(sg.center, sg.color)

      vec = Point.new(1, 0)
      ray_groups = [[scan_finder_edges(center, vec, sg.color)]]
      179.times do |i|
        vec = Point.new(
          vec.x * Math.cos(Math::PI / 180) - vec.y * Math.sin(Math::PI / 180),
          vec.x * Math.sin(Math::PI / 180) + vec.y * Math.cos(Math::PI / 180),
        )

        pair, length = scan_finder_edges(center, vec, sg.color)
        diff = length - ray_groups.last[0][1]
        if diff == 0
          ray_groups.last.push({pair, length})
        else
          ray_groups.push([{pair, length}])
        end
      end
      ray_groups.push(ray_groups[0])

      scored_rays = [] of Tuple(Tuple(Point, Point), Float64)
      (0...ray_groups.size - 2).each do |i|
        ray_lengths = {-1, 0, 1}.map { |j| ray_groups[i + j][0][1] }
        next unless ray_lengths[0] < ray_lengths[1] && ray_lengths[1] > ray_lengths[2]

        pair, _ = ray_groups[i][ray_groups[i].size // 2]
        score = (pair[1] - pair[0]).length
        score += (ray_lengths[1] - ray_lengths[0])
        score += (ray_lengths[1] - ray_lengths[2])
        score *= 1.1 if ray_lengths[0] == ray_lengths[2]

        ray_lengths = {-2, -1, 1, 2}.map { |j| ray_groups[i + j][0][1] }
        if ray_lengths[0] < ray_lengths[1] && ray_lengths[2] > ray_lengths[3]
          score += (ray_lengths[1] - ray_lengths[0])
          score += (ray_lengths[2] - ray_lengths[3])
          score *= 1.1 if ray_lengths[0] == ray_lengths[3]
          score *= 1.1 if ray_lengths[1] == ray_lengths[2]
        end

        scored_rays.push({pair, score})
      end
      return if scored_rays.empty?

      pair1, pair1_score = scored_rays.max_by { |x| x[1] }
      pair2, pair2_score = scored_rays.max_by do |item|
        pair2_cand, pair2_cand_score = item
        sin_sita = Point.angle_between(pair1[1] - pair1[0], pair2_cand[1] - pair2_cand[0]).abs
        score = (pair1_score + pair2_cand_score * 10) * Math.min(sin_sita, 0.9)

        # Visualizer.set_data(data)
        # Visualizer.add_text(center, score.to_s)
        # Visualizer.add_line(pair1[0], pair1[1])
        # Visualizer.add_line(pair2_cand[0], pair2_cand[1])
        # Visualizer.add_point(pair1[0], "#00ffff")
        # Visualizer.add_point(pair1[1], "#ffff00")
        # Visualizer.add_text(pair1[0], pair1_score.to_s)
        # Visualizer.add_point(pair2_cand[0], "#00ffff")
        # Visualizer.add_point(pair2_cand[1], "#ffff00")
        # Visualizer.add_text(pair2_cand[0], pair2_cand_score.to_s)
        # Visualizer.export

        score
      end

      {pair1, pair2, center}
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
      len1 = 0
      skip_same_color(:-, len1)
      skip_same_color(:-, len1)
      skip_same_color(:-, len1)
      e1 = temp_point + vec # + vec * (len1 / 3.5) / 2

      temp_point, prev_color = origin, color
      len2 = 0
      skip_same_color(:+, len2)
      skip_same_color(:+, len2)
      skip_same_color(:+, len2)
      e2 = temp_point - vec # - vec * (len2 / 3.5) / 2

      { {e1, e2}, len1 + len2 + 1 }
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
