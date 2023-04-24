require "./locator/*"

module Goishi
  struct LocatorSession
    @data : Matrix(UInt8)?
    @finder_quads : Array(Quad)

    def initialize
      @finder_quads = [] of Quad
    end

    private def data
      raise "Data not loaded" unless @data
      @data.not_nil!
    end

    def set_data(data : Matrix(UInt8))
      center = Point.new(data.size_x / 2, data.size_y / 2)

      @data = data
      @finder_quads = [] of Quad unless @finder_quads.empty?
      @finder_quads = @finder_quads.concat(LineScanner.scan_finder_pat(data))
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
        score -= 100 if data[q_center.x.to_i, q_center.y.to_i] != q.color

        -score.round_even.to_i
      end
    end

    def locate_qr(max_candidates : Int, & : QRLocation ->)
      candidates_count = 0

      (0...@finder_quads.size).each do |i|
        q1 = @finder_quads[i]

        (i + 1...@finder_quads.size).each do |j|
          q2 = @finder_quads[j]
          next unless q2.color == q1.color

          size1 = (q1.width + q1.height) / 2
          size2 = (q2.width + q2.height) / 2
          next unless ((size2 - size1).abs / size1) <= 1.3

          (j + 1...@finder_quads.size).each do |k|
            return if candidates_count >= max_candidates

            q3 = @finder_quads[k]
            next unless q3.color == q1.color

            size3 = (q3.width + q3.height) / 2
            next unless ((size3 - size1).abs / size1) <= 1.3

            location = test_finder_arrangement(q1, q2, q3)
            location = test_finder_arrangement(q2, q1, q3) unless location
            location = test_finder_arrangement(q3, q1, q2) unless location
            next unless location

            candidates_count += 1
            yield location
          end
        end
      end
    end

    private def test_finder_arrangement(a : Quad, b : Quad, c : Quad)
      a_center = refine_center(a.center, a.color)
      b_center = refine_center(b.center, b.color)
      c_center = refine_center(c.center, c.color)

      # Define vectors
      ab, ac = (b_center - a_center), (c_center - a_center)
      ab_len, ac_len = ab.length, ac.length

      sin_sita = Point.angle_between(ab, ac)
      # AB and AC must be near right angle
      return unless (0.85..1.15).includes?(sin_sita.abs)

      # Calculate unit size (= module size) and version
      a_unit_ab = refine_unit(a_center, ab, a.color)
      b_unit_ab = refine_unit(b_center, ab, a.color)
      ab_unit = (a_unit_ab + b_unit_ab) / 2
      version1 = (ab_len / ab_unit - 10) / 4

      a_unit_ac = refine_unit(a_center, ac, a.color)
      c_unit_ac = refine_unit(c_center, ac, a.color)
      ac_unit = (a_unit_ac + c_unit_ac) / 2
      version2 = (ac_len / ac_unit - 10) / 4

      unit = ((ab_unit + ac_unit) / 2).round_even.to_i
      version = ((version1 + version2) / 2).round_even.to_i

      # Orientation of B and C gained from the left-right and top-bottom endpoints
      b_angle_lr = b.angle_lr(ac)
      b_angle_tb = b.angle_tb(ac)
      c_angle_lr = c.angle_lr(ab)
      c_angle_tb = c.angle_tb(ab)

      top_left = a_center
      # Rearrange B and C according to sin_sita
      if sin_sita > 0
        top_right = c_center
        bottom_left = b_center

        # Make the vector of BD and CD
        if (0.7..1.3).includes?(Point.angle_between(ac, c_angle_lr).abs) &&
           (0.7..1.3).includes?(Point.angle_between(ab, b_angle_tb).abs)
          top_right_bottom_right_vec = top_right + c_angle_lr
          bottom_left_bottom_right_vec = bottom_left + b_angle_tb
        elsif (0.7..1.3).includes?(Point.angle_between(ac, c_angle_tb).abs) &&
              (0.7..1.3).includes?(Point.angle_between(ab, b_angle_lr).abs)
          top_right_bottom_right_vec = top_right + c_angle_tb
          bottom_left_bottom_right_vec = bottom_left + b_angle_lr
        else
          return
        end
      else
        top_right = b_center
        bottom_left = c_center

        # Make the vector of BD and CD
        if (0.7..1.3).includes?(Point.angle_between(ab, b_angle_lr).abs) &&
           (0.7..1.3).includes?(Point.angle_between(ac, c_angle_tb).abs)
          top_right_bottom_right_vec = top_right + b_angle_lr
          bottom_left_bottom_right_vec = bottom_left + c_angle_tb
        elsif (0.7..1.3).includes?(Point.angle_between(ab, b_angle_tb).abs) &&
              (0.7..1.3).includes?(Point.angle_between(ac, c_angle_lr).abs)
          top_right_bottom_right_vec = top_right + b_angle_tb
          bottom_left_bottom_right_vec = bottom_left + c_angle_lr
        else
          return
        end
      end

      # This will be the point D
      intersection = intersection(
        top_right, top_right_bottom_right_vec,
        bottom_left, bottom_left_bottom_right_vec
      )
      return unless intersection
      return unless (0...data.size_x).includes?(intersection.x) &&
                    (0...data.size_y).includes?(intersection.y)

      # Try finding an alignment pattern around D
      alignment_point = refine_bottom_right(intersection, a_center, unit, a.color) if version >= 2
      if alignment_point
        bottom_right = alignment_point
        bottom_right_type = QRLocation::BottomRightType::AlignmentPattern
      else
        bottom_right = intersection
        bottom_right_type = QRLocation::BottomRightType::Intersection
      end

      QRLocation.new(
        top_left, top_right,
        bottom_left, bottom_right,
        unit, version, a.color,
        bottom_right_type
      )
    end

    private def refine_unit(point : Point, vec : Point, color : UInt8)
      unit_vec = vec.unit_vec

      temp_point = point
      color_changes, prev_color = 0, color
      until color_changes == 3
        c = data[temp_point -= unit_vec]
        next if c == prev_color

        color_changes += 1
        prev_color = c
      end
      p1 = temp_point + unit_vec

      temp_point = point
      color_changes, prev_color = 0, color
      until color_changes == 3
        c = data[temp_point += unit_vec]
        next if c == prev_color

        color_changes += 1
        prev_color = c
      end
      p2 = temp_point - unit_vec

      dist = Point.distance(p1, p2)
      (dist / 7).round_even
    end

    # Recenter the point by performing runs in both direction
    private def refine_center(point : Point, color : UInt8)
      temp_x = point.x.to_i
      temp_y = point.y.to_i

      until data[temp_x - 1, temp_y] != color
        temp_x -= 1
      end
      left = temp_x
      temp_x = point.x.to_i
      until data[temp_x + 1, temp_y] != color
        temp_x += 1
      end
      right = temp_x
      new_x = ((left + right) / 2)

      temp_x = new_x.to_i
      until data[temp_x, temp_y - 1] != color
        temp_y -= 1
      end
      top = temp_y
      temp_y = point.y.to_i
      until data[temp_x, temp_y + 1] != color
        temp_y += 1
      end
      bottom = temp_y
      new_y = ((top + bottom) / 2)

      Point.new(new_x, new_y)
    end

    # Refine the bottom right point by finding an alignment pattern around the given starting point
    private def refine_bottom_right(point : Point, a : Point, unit : Int, color : UInt8)
      est_alignment = point - (point - a).unit_vec * 3 * unit
      from = est_alignment - 5 * unit
      to = est_alignment + 5 * unit

      alignment_quads = LineScanner.scan_alignment_pat(data, from, to, color).max_by? do |q|
        q_center = q.center
        score = 100
        # Penalize patterns that are far from the estimated point
        distance = Point.distance(q_center, est_alignment) / unit
        score -= distance * 5
        # Penalize patterns that are not close in unit size
        q_unit = ((q.unit_x(3) + q.height) / 2).round_even
        diff = (q_unit - unit).abs / unit
        score -= diff * 50
        # Penalize patterns that the center does not match the color
        score -= 100 if data[q_center.x.to_i, q_center.y.to_i] != q.color

        # pp({q, score, distance, q_unit, unit})

        score
      end

      alignment_quads.try(&.center)
    end

    # Get intersection point of EF and GH
    private def intersection(e : Point, f : Point, g : Point, h : Point)
      ef, gh = (f - e), (h - g)

      deno = Point.cross_prod(ef, gh)
      return if deno == 0

      s = Point.cross_prod(g - e, gh) / deno
      # t = Point.cross_prod(b - a, a - c) / deno

      Point.new(e.x + s * ef.x, e.y + s * ef.y)
    end
  end
end
