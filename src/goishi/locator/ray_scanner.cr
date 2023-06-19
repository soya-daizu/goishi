struct Goishi::LocatorSession
  module RayScanner
    extend self

    private macro test_pattern(type)
      center = refine_center(data, center, color)

      vec = Point.new(1, 0)
      ray_groups = [] of Array(Tuple(Tuple(Point, Point), Int32))
      passed_count = 0
      180.times do |i|
        # Find the two edges of the pattern in the current vector's direction
        # and group them together by their length
        pair, length, passed = scan_{{type.id}}_edges(data, center, vec, color) || return
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

      Quad.new(pair1, pair2, center, color)
    end

    def test_finder_pattern(data : Canvas(UInt8), center : Point, color : UInt8)
      test_pattern(:finder)
    end

    def test_alignment_pattern(data : Canvas(UInt8), center : Point, color : UInt8)
      test_pattern(:alignment)
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

    private macro run_timing_pattern(operator, rmqr)
      while true
        point = temp_point {{operator.id}} vec
        c = data[point]? || break
        temp_point = point

        if c == prev_color
          len += 1
          {% if rmqr %}
            break if c != color && len > avg_len * 1.5
          {% else %}
            break if len > avg_len * 1.5
          {% end %}
        else
          break if len < avg_len * 0.5
          {% if rmqr %}
            ended_with_subalignment = prev_color == color && len.in?(avg_len * 2...avg_len * 4)
            ended_with_alignment = prev_color == color && len.in?(avg_len * 4..avg_len * 6)
            break if !ended_with_subalignment && !ended_with_alignment && len > avg_len * 1.5
          {% end %}

          lengths.push(len)
          avg_len = lengths.sum / lengths.size
          len = 1
          prev_color = c
          mod_points.push(temp_point)

          {% if rmqr %}
            break if ended_with_subalignment || ended_with_alignment
          {% end %}
        end
      end
    end

    def scan_timing_pattern(data : Canvas(UInt8), e1 : Point, e2 : Point, vec : Point, color : UInt8)
      unit = ((e1 - e2).length / 6).round_even.to_i

      temp_point, prev_color = e2, color
      skip_same_color(:+)

      mod_points = [temp_point]
      lengths, len, avg_len = [unit], 1, unit
      run_timing_pattern(:+, false)
      p = mod_points.last - vec * lengths.last / 2
      mod_count = mod_points.size - 1

      # Visualizer.set_data(data)
      # Visualizer.add_point(p, "#0000ff")
      # Visualizer.add_text(p, mod_count.to_s)
      # Visualizer.export

      return {p, mod_count} if prev_color == color && mod_count.in?(4..10)
    end

    def scan_timing_pattern_rmqr(data : Canvas(UInt8), e1 : Point, e2 : Point, first_mods : Int,
                                 est_vec : Point, color : UInt8, rev_search : Bool)
      unit = ((e1 - e2).length / first_mods).round_even.to_i

      fallback = nil
      stepper = rev_search ? (0..-5).step(by: -1) : (0..5).step(by: 1)
      stepper.each do |angle|
        vec = Point.new(
          est_vec.x * Math.cos(Math::PI / 180 * angle) - est_vec.y * Math.sin(Math::PI / 180 * angle),
          est_vec.x * Math.sin(Math::PI / 180 * angle) + est_vec.y * Math.cos(Math::PI / 180 * angle),
        )
        temp_point, prev_color = e2, color
        skip_same_color(:+)

        mod_points = [temp_point]
        lengths, len, avg_len = [unit], 1, unit
        ended_with_subalignment = false
        ended_with_alignment = false
        run_timing_pattern(:+, true)
        next unless mod_points.size > 1

        p = mod_points.last - vec * (lengths.last / 3) / 2
        p_e1 = mod_points[-2] + vec * (lengths.last / 3) / 2
        mod_count = mod_points.size - 1

        if ended_with_subalignment || ended_with_alignment
          mod_count += 2
          mod_count += 2 if ended_with_alignment

          # Visualizer.set_data(data)
          # Visualizer.add_point(e2, "#ff0000")
          # Visualizer.add_point(p, "#0000ff")
          # Visualizer.add_text(p, mod_count.to_s)
          # Visualizer.add_text(e1, ended_with_subalignment.to_s)
          # Visualizer.export

          return {p, p_e1, mod_count, ended_with_subalignment}
        end

        # Visualizer.set_data(data)
        # Visualizer.add_point(p, "#ff0000")
        # Visualizer.add_text(p, mod_count.to_s)
        # Visualizer.add_text(e1, angle.to_s)
        # Visualizer.export

        fallback = {p, p_e1, mod_count, ended_with_subalignment} if !fallback || mod_count > fallback[2]
      end
      return unless fallback

      # p, p_e1, mod_count, ended_with_subalignment = fallback
      # Visualizer.set_data(data)
      # Visualizer.add_point(e2, "#ff0000")
      # Visualizer.add_point(p, "#0000ff")
      # Visualizer.add_text(p, mod_count.to_s)
      # Visualizer.add_text(e1, ended_with_subalignment.to_s)
      # Visualizer.export

      fallback
    end

    def scan_subalignment_vec_rmqr(data : Canvas(UInt8), e1 : Point, v_vec : Point, h_vec : Point, color : UInt8)
      vec, len = h_vec, 0
      temp_point, prev_color = e1, color
      skip_same_color(:-, len)
      e1 = temp_point + vec * len / 0.5 / 4

      vec = v_vec
      temp_point, prev_color = e1, color
      skip_same_color(:+)
      v_e1 = temp_point - vec

      vec, len = h_vec, 0
      temp_point, prev_color = e1, color
      skip_same_color(:+, len)
      e2 = temp_point - vec * len / 2.5 / 4

      vec = v_vec
      temp_point, prev_color = e2, color
      skip_same_color(:+)
      v_e2 = temp_point - vec

      # Visualizer.set_data(data)
      # Visualizer.add_point(e1, "#ff0000")
      # Visualizer.add_point(e2, "#0000ff")
      # Visualizer.add_point(v_e1, "#ff0000")
      # Visualizer.add_point(v_e2, "#0000ff")
      # Visualizer.export

      subalignment_vec = (h_vec + (v_e2 - v_e1).unit_vec) / 2
      {subalignment_vec, e1, e2}
    end
  end
end
