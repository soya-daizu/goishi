struct Goishi::LocatorSession
  module QRLocator
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

            location = test_finder_qr(q1, q2, q3)
            location = test_finder_qr(q2, q1, q3) unless location
            location = test_finder_qr(q3, q1, q2) unless location
            next unless location

            candidates_count += 1
            yield location
          end
        end
      end
    end

    private def test_finder_qr(q1 : Quad, q2 : Quad, q3 : Quad)
      a = refine_center(q1.center, q1.color)
      b = refine_center(q2.center, q1.color)
      c = refine_center(q3.center, q1.color)

      # Define vectors
      ab, ac = (b - a), (c - a)
      ab_len, ac_len = ab.length, ac.length
      ab_vec, ac_vec = ab.unit_vec, ac.unit_vec

      sin_sita = Point.angle_between(ab, ac)
      # AB and AC must be near right angle
      return unless (0.85..1.15).includes?(sin_sita.abs)

      # Calculate unit size (= module size) and version
      a_unit_ab = refine_unit(a, ab_vec, q1.color)
      b_unit_ab = refine_unit(b, ab_vec, q1.color)
      ab_unit = (a_unit_ab + b_unit_ab) / 2
      version1 = (ab_len / ab_unit - 10) / 4

      a_unit_ac = refine_unit(a, ac_vec, q1.color)
      c_unit_ac = refine_unit(c, ac_vec, q1.color)
      ac_unit = (a_unit_ac + c_unit_ac) / 2
      version2 = (ac_len / ac_unit - 10) / 4

      unit = ((ab_unit + ac_unit) / 2).round_even.to_i
      version = ((version1 + version2) / 2).round_even.to_i
      version = Math.max(version, 1)
      version = Math.min(version, 40)

      begin
        # Orientation of B and C gained from the left-right and top-bottom endpoints
        b_angle_lr = q2.y_angle(ac)
        b_angle_tb = q2.x_angle(ac)
        c_angle_lr = q3.y_angle(ab)
        c_angle_tb = q3.x_angle(ab)
      rescue
        return
      end

      # Rearrange B and C according to sin_sita
      if sin_sita > 0
        b, c = c, b

        # Make the vector of BD and CD
        if (0.7..1.3).includes?(Point.angle_between(ac, c_angle_lr).abs) &&
           (0.7..1.3).includes?(Point.angle_between(ab, b_angle_tb).abs)
          bd_vec = b + c_angle_lr
          cd_vec = c + b_angle_tb
        elsif (0.7..1.3).includes?(Point.angle_between(ac, c_angle_tb).abs) &&
              (0.7..1.3).includes?(Point.angle_between(ab, b_angle_lr).abs)
          bd_vec = b + c_angle_tb
          cd_vec = c + b_angle_lr
        else
          return
        end
      else
        # Make the vector of BD and CD
        if (0.7..1.3).includes?(Point.angle_between(ab, b_angle_lr).abs) &&
           (0.7..1.3).includes?(Point.angle_between(ac, c_angle_tb).abs)
          bd_vec = b + b_angle_lr
          cd_vec = c + c_angle_tb
        elsif (0.7..1.3).includes?(Point.angle_between(ab, b_angle_tb).abs) &&
              (0.7..1.3).includes?(Point.angle_between(ac, c_angle_lr).abs)
          bd_vec = b + b_angle_tb
          cd_vec = c + c_angle_lr
        else
          return
        end
      end

      # This will be the point D
      intersection = intersection(b, bd_vec, c, cd_vec)
      return unless intersection
      return unless (0...data.size_x).includes?(intersection.x) &&
                    (0...data.size_y).includes?(intersection.y)

      # Try finding an alignment pattern around D
      alignment_point = refine_bottom_right(intersection, a, unit, q1.color) if version >= 2
      if alignment_point
        d = alignment_point
        bottom_right_offset = 6.5
      else
        d = intersection
        bottom_right_offset = 3.5
      end

      QRLocation.new(
        a, b, c, d,
        unit, version, q1.color,
        {3.5, 3.5, 3.5, bottom_right_offset}
      )
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
  end
end
