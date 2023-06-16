struct Goishi::LocatorSession
  module RayScanner
    extend self

    def test_finder_scangroup(data : Canvas(UInt8), sg : ScanGroup)
      center = refine_center(data, sg.center, sg.color)

      vec = Point.new(1, 0)
      ray_groups = [] of Array(Tuple(Tuple(Point, Point), Int32))
      passed_count = 0
      180.times do |i|
        # Find the two edges of the finder pattern in the current vector's direction
        # and group them together by their length
        pair, length, passed = scan_finder_edges(data, center, vec, sg.color) || return
        if !ray_groups.empty? && length == ray_groups.last[0][1]
          ray_groups.last.push({pair, length})
        else
          ray_groups.push([{pair, length}])
        end
        passed_count += 1 if passed

        # Rotate the vector by 1°
        vec = Point.new(
          vec.x * Math.cos(Math::PI / 180) - vec.y * Math.sin(Math::PI / 180),
          vec.x * Math.sin(Math::PI / 180) + vec.y * Math.cos(Math::PI / 180),
        ) if i < 179
      end
      return if passed_count < 90

      scored_rays = [] of Tuple(Tuple(Point, Point), Float64)
      (0...ray_groups.size).each do |i|
        ray_lengths = {-2, -1, 0, 1, 2}.map { |j| (ray_groups[i + j]? || ray_groups[j - 1])[0][1] }
        next unless ray_lengths[1] < ray_lengths[2] && ray_lengths[2] > ray_lengths[3]

        pair, _ = ray_groups[i][ray_groups[i].size // 2]
        score = (pair[1] - pair[0]).length
        # score += (ray_lengths[2] - ray_lengths[1])
        # score += (ray_lengths[2] - ray_lengths[3])
        # score *= 1.1 if ray_lengths[1] == ray_lengths[3]

        if ray_lengths[0] < ray_lengths[1] && ray_lengths[3] > ray_lengths[4]
          # score += (ray_lengths[1] - ray_lengths[0])
          # score += (ray_lengths[3] - ray_lengths[4])
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

        # Visualizer.set_data(data)
        # Visualizer.add_point(center, "#ff0000")
        # Visualizer.add_line(pair1[0], pair1[1], "#ff0000")
        # Visualizer.add_line(pair2_cand[0], pair2_cand[1], "#0000ff")
        # Visualizer.add_text(center, score.to_s, "#ff0000")
        # Visualizer.export

        score
      end

      Quad.new(pair1, pair2, center, sg.color)
    end

    def test_alignment_scangroup(data : Canvas(UInt8), sg : ScanGroup)
      center = refine_center(data, sg.center, sg.color)

      vec = Point.new(1, 0)
      ray_groups = [] of Array(Tuple(Tuple(Point, Point), Int32))
      passed_count = 0
      180.times do |i|
        # Find the two edges of the alignment pattern in the current vector's direction
        # and group them together by their length
        pair, length, passed = scan_alignment_edges(data, center, vec, sg.color) || return
        if !ray_groups.empty? && length == ray_groups.last[0][1]
          ray_groups.last.push({pair, length})
        else
          ray_groups.push([{pair, length}])
        end
        passed_count += 1 if passed

        # Rotate the vector by 1°
        vec = Point.new(
          vec.x * Math.cos(Math::PI / 180) - vec.y * Math.sin(Math::PI / 180),
          vec.x * Math.sin(Math::PI / 180) + vec.y * Math.cos(Math::PI / 180),
        ) if i < 179
      end
      return if passed_count < 90

      scored_rays = [] of Tuple(Tuple(Point, Point), Float64)
      (0...ray_groups.size).each do |i|
        ray_lengths = {-2, -1, 0, 1, 2}.map { |j| (ray_groups[i + j]? || ray_groups[j - 1])[0][1] }
        next unless ray_lengths[1] < ray_lengths[2] && ray_lengths[2] > ray_lengths[3]

        pair, _ = ray_groups[i][ray_groups[i].size // 2]
        score = (pair[1] - pair[0]).length

        if ray_lengths[0] < ray_lengths[1] && ray_lengths[3] > ray_lengths[4]
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

        # Visualizer.set_data(data)
        # Visualizer.add_point(center, "#ff0000")
        # Visualizer.add_line(pair1[0], pair1[1], "#ff0000")
        # Visualizer.add_line(pair2_cand[0], pair2_cand[1], "#0000ff")
        # Visualizer.add_text(center, score.to_s, "#ff0000")
        # Visualizer.export

        score
      end

      Quad.new(pair1, pair2, center, sg.color)
    end

    # Recenter the point by performing runs in both direction
    private def refine_center(data : Canvas(UInt8), point : Point, color : UInt8)
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
      new_x = (left + right) / 2

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
      new_y = (top + bottom) / 2

      Point.new(new_x, new_y)
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

    private def scan_finder_edges(data : Canvas(UInt8), origin : Point, vec : Point, color : UInt8)
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

      return if (len2 - len1).abs / Math.min(len1, len2) > 2

      len = len1 + len2 + 1
      unit = len / 7
      passed = {
        {1, len1_3},
        {1, len1_2},
        {3, len1_1 + len2_1 + 1},
        {1, len2_2},
        {1, len2_3},
      }.all? do |r, l|
        range = ((r - 0.5) * unit).round_even..((r + 0.5) * unit).round_even
        l.in?(range)
      end

      { {e1, e2}, len1 + len2 + 1, passed }
    end

    private def scan_alignment_edges(data : Canvas(UInt8), origin : Point, vec : Point, color : UInt8)
      temp_point, prev_color = origin, color
      len1_1, len1_2 = 0, 0
      skip_same_color(:-, len1_1)
      skip_same_color(:-, len1_2)
      len1 = len1_1 + len1_2
      e1 = temp_point + vec

      temp_point, prev_color = origin, color
      len2_1, len2_2 = 0, 0
      skip_same_color(:+, len2_1)
      skip_same_color(:+, len2_2)
      len2 = len2_1 + len2_2
      e2 = temp_point - vec

      return if (len2 - len1).abs / Math.min(len1, len2) > 2

      len = len1 + len2 + 1
      unit = len / 3
      passed = {
        len1_2,
        len1_1 + len2_1 + 1,
        len2_2,
      }.all? do |l|
        range = (0.5 * unit).round_even..(1.5 * unit).round_even
        l.in?(range)
      end

      { {e1, e2}, len1 + len2 + 1, passed }
    end
  end
end
