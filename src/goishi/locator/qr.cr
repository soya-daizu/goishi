struct Goishi::LocatorSession
  module QRLocator
    def locate_qr(max_candidates : Int, & : QRLocation ->)
      candidates_count = 0

      best_quad_groups = [] of Tuple(Quad, Quad, Quad, Float64)
      (0...@finder_quads.size).each do |i|
        q1 = @finder_quads[i]
        max_qr_width = q1.w_vec.length/7 * (17 + 4*40 - 7)
        max_qr_height = q1.h_vec.length/7 * (17 + 4*40 - 7)
        search_radius = Math.sqrt(max_qr_width ** 2 + max_qr_height ** 2) * 1.2

        nearby_quads = [] of Tuple(Quad, Float64)
        (i + 1...@finder_quads.size).each do |j|
          q = @finder_quads[j]
          next unless q.color == q1.color
          dist = (q.center - q1.center).length
          next unless dist <= search_radius
          nearby_quads.push({q, dist})
        end

        nearby_quads.each_combination(2, reuse: true) do |pair|
          q2, dist2 = pair[0]
          q3, dist3 = pair[1]
          dist1 = (q2.center - q3.center).length
          best_quad_groups.push({q1, q2, q3, dist1 + dist2 + dist3})
        end
      end

      best_quad_groups.sort_by! do |_, _, _, penalty|
        penalty
      end

      # Visualizer.set_data(data)
      # best_quad_groups.each do |q1, q2, q3, penalty|
      #  Visualizer.add_line(q1.center, q2.center, "#ff00ff")
      #  Visualizer.add_line(q2.center, q3.center, "#ff00ff")
      #  Visualizer.add_line(q3.center, q1.center, "#ff00ff")
      # end
      # Visualizer.export

      best_quad_groups.each do |q1, q2, q3, _|
        return if candidates_count >= max_candidates

        location = test_finder_qr(q1, q2, q3)
        location = test_finder_qr(q2, q3, q1) unless location
        location = test_finder_qr(q3, q1, q2) unless location
        next unless location

        yield location, candidates_count
        candidates_count += 1
      end
    end

    private def test_finder_facing_sides(a_quad : Quad, b_quad : Quad)
      a_side_pts, a_side_intersection = a_quad.intersecting_side(b_quad) || return false
      b_side_pts, b_side_intersection = b_quad.intersecting_side(a_quad) || return false

      a_side = a_side_pts[0] - a_side_pts[1]
      b_side = b_side_pts[0] - b_side_pts[1]
      a_side_intersection_ratio = (a_side_pts[0] - a_side_intersection).length / a_side.length
      b_side_intersection_ratio = (b_side_pts[0] - b_side_intersection).length / b_side.length
      return false if (a_side_intersection_ratio - 0.5).abs > 0.35 || (b_side_intersection_ratio - 0.5).abs > 0.35
      return false if (a_side.length - b_side.length).abs / Math.max(a_side.length, b_side.length) > 0.25
      sin_sita = Point.angle_between(a_side, b_side).abs
      return false if sin_sita > Math.sin(Math::PI / 4)

      true
    end

    private def test_finder_qr(q1 : Quad, q2 : Quad, q3 : Quad)
      return unless test_finder_facing_sides(q1, q2)
      return unless test_finder_facing_sides(q1, q3)

      a_quad, b_quad, c_quad = q1, q2, q3
      color = q1.color

      ab_vec, ac_vec = (b_quad.center - a_quad.center), (c_quad.center - a_quad.center)
      ab_len, ac_len = ab_vec.length, ac_vec.length
      sin_sita = Point.angle_between(ab_vec, ac_vec)

      # Swap B and C according to sin_sita
      if sin_sita > 0
        b_quad, c_quad = c_quad, b_quad
        ab_vec, ac_vec = ac_vec, ab_vec
        ab_len, ac_len = ab_vec.length, ac_vec.length
      end
      bd_vec, cd_vec = b_quad.closer_vec(ac_vec), c_quad.closer_vec(ab_vec)

      # Calculate unit size (= module size) and version
      a_x_unit = a_quad.closer_vec(ab_vec).length / 7
      b_x_unit = b_quad.closer_vec(ab_vec).length / 7
      x_unit = (a_x_unit + b_x_unit) / 2
      version1 = (ab_len / x_unit - 10) / 4

      a_y_unit = a_quad.closer_vec(ac_vec).length / 7
      c_y_unit = c_quad.closer_vec(ac_vec).length / 7
      y_unit = (a_y_unit + c_y_unit) / 2
      version2 = (ac_len / y_unit - 10) / 4

      unit = ((x_unit + y_unit) / 2).round_even.to_i
      version = ((version1 + version2) / 2).round_even.to_i
      version = version.clamp(1, 40)

      # This will be the point D
      intersection = Point.intersection(
        b_quad.center, b_quad.center + bd_vec,
        c_quad.center, c_quad.center + cd_vec
      ) || return
      return unless intersection.x.in?(0...data.size_x) &&
                    intersection.y.in?(0...data.size_y)

      # Try finding an alignment pattern around D
      est_alignment = intersection - (intersection - a_quad.center).unit_vec * 3 * unit
      alignment_point = refine_bottom_right(est_alignment, unit, color) if version >= 2
      if alignment_point
        d = alignment_point
        bottom_right_offset = 6.5
      else
        d = intersection
        bottom_right_offset = 3.5
      end

      # Visualizer.set_data(data)
      # a_quad.add_to_visualizer("A")
      # b_quad.add_to_visualizer("B")
      # c_quad.add_to_visualizer("C")
      # Visualizer.add_point(d, "#ff00ff")
      # Visualizer.export

      QRLocation.new(QR,
        a_quad.center, b_quad.center, c_quad.center, d,
        version, color, {3.5, 3.5, 3.5, bottom_right_offset}
      )
    end
  end
end
