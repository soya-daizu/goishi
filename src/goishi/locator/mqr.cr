struct Goishi::LocatorSession
  module MQRLocator
    def locate_mqr(max_candidates : Int, & : QRLocation ->)
      candidates_count = 0

      @finder_quads.each do |q|
        location = test_finder_mqr(q)
        next unless location

        candidates_count += 1
        yield location
      end
    end

    private def test_finder_mqr(q : Quad)
      center = refine_center(q.center, q.color)

      ab_angle = q.x_angle(Point.new(0, 0)) rescue return
      ac_angle = q.y_angle(Point.new(0, 0)) rescue return
      ab_vec = ab_angle.unit_vec
      ac_vec = ac_angle.unit_vec

      ab_unit = refine_unit(center, ab_vec, q.color)
      ac_unit = refine_unit(center, ac_vec, q.color)
      unit = ((ab_unit + ac_unit) / 2).round_even.to_i
      top = center - ac_vec * ac_unit * 3
      bottom = center + ac_vec * ac_unit * 3
      left = center - ab_vec * ab_unit * 3
      right = center + ab_vec * ab_unit * 3
      pp!({top, bottom, left, right})

      location = test_timing_patterns(top, left, ab_vec, ac_vec, q.color, unit)
      location = test_timing_patterns(left, bottom, ac_vec, ab_vec, q.color, unit) unless location
      location = test_timing_patterns(bottom, right, ab_vec, ac_vec, q.color, unit) unless location
      location = test_timing_patterns(right, top, ac_vec, ab_vec, q.color, unit) unless location

      location
    end

    private def test_timing_patterns(p1 : Point, p2 : Point, p1_vec : Point, p2_vec : Point, color : UInt8, unit : Int)
      b, ab_mods = run_timing_pattern(p1, p1_vec, color)
      c, ac_mods = run_timing_pattern(p2, p2_vec, color)
      return unless ab_mods == ac_mods

      a = intersection(p1, b, p2, c)
      return unless a
      return unless (0...data.size_x).includes?(a.x) &&
                    (0...data.size_y).includes?(a.y)

      d = intersection(b, b + p2_vec, c, c + p1_vec)
      return unless d
      return unless (0...data.size_x).includes?(d.x) &&
                    (0...data.size_y).includes?(d.y)

      version = ab_mods // 2 - 1

      QRLocation.new(
        a, b, c, d,
        unit, version, color,
        {0.5, 0.5, 0.5, 0.5}
      )
    end

    private def run_timing_pattern(origin : Point, vec : Point, color : UInt8)
      temp_point, prev_color = origin, color
      len = 0
      while prev_color == color
        prev_color = data[temp_point -= vec]
        len += 1
      end

      last_black_point, mod_count = temp_point, 0
      len, prev_len = 1, (len / 3.5).round_even.to_i
      while true
        c = data[temp_point -= vec] || break
        last_black_point = temp_point if c == color
        if c == prev_color
          len += 1
          next if len <= prev_len * 1.3
          break
        end

        if len >= prev_len * 0.7
          prev_len, len = len, 1
          prev_color = c
          mod_count += 1
          next
        end

        break
      end
      p1, p1_mod_count = last_black_point + vec * prev_len / 2, mod_count

      temp_point, prev_color = origin, color
      len = 0
      while prev_color == color
        prev_color = data[temp_point += vec]
        len += 1
      end

      last_black_point, mod_count = temp_point, 0
      len, prev_len = 1, (len / 3.5).round_even.to_i
      while true
        c = data[temp_point += vec] || break
        last_black_point = temp_point if c == color
        if c == prev_color
          len += 1
          next if len <= prev_len * 1.3
          break
        end

        if len >= prev_len * 0.7
          prev_len, len = len, 1
          prev_color = c
          mod_count += 1
          next
        end

        break
      end
      p2, p2_mod_count = last_black_point - vec * prev_len / 2, mod_count

      p1_mod_count > p2_mod_count ? {p1, p1_mod_count} : {p2, p2_mod_count}
    end
  end
end
