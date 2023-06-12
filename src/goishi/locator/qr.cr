struct Goishi::LocatorSession
  module QRLocator
    def locate_qr(max_candidates : Int, & : QRLocation ->)
      candidates_count = 0

      (0...@finder_scangroups.size).each do |i|
        sg1 = @finder_scangroups[i]
        q1 = scangroup_to_quad(sg1) || next

        (i + 1...@finder_scangroups.size).each do |j|
          sg2 = @finder_scangroups[j]
          q2 = scangroup_to_quad(sg2) || next
          next unless sg2.color == sg1.color

          size1 = (sg1.width + sg1.height) / 2
          size2 = (sg2.width + sg2.height) / 2
          next unless ((size2 - size1).abs / size1) <= 1.3

          (j + 1...@finder_scangroups.size).each do |k|
            return if candidates_count >= max_candidates

            sg3 = @finder_scangroups[k]
            q3 = scangroup_to_quad(sg3) || next
            next unless sg3.color == sg1.color

            size3 = (sg3.width + sg3.height) / 2
            next unless ((size3 - size1).abs / size1) <= 1.3

            location = test_finder_qr(q1, q2, q3, sg1.color)
            location = test_finder_qr(q2, q3, q1, sg1.color) unless location
            location = test_finder_qr(q3, q1, q2, sg1.color) unless location
            next unless location

            candidates_count += 1
            yield location
          end
        end
      end
    end

    private def test_finder_qr(q1 : Quad, q2 : Quad, q3 : Quad, color : UInt8)
      a_quad, b_quad, c_quad = q1, q2, q3

      # Define vectors
      ab_vec, ac_vec = (b_quad.center - a_quad.center), (c_quad.center - a_quad.center)
      ab_len, ac_len = ab_vec.length, ac_vec.length

      sin_sita = Point.angle_between(ab_vec, ac_vec)
      # AB and AC must be near right angle
      return unless (0.85..1.15).includes?(sin_sita.abs)

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
      intersection = intersection(b_quad.center, b_quad.center + bd_vec, c_quad.center, c_quad.center + cd_vec)
      return unless intersection
      return unless (0...data.size_x).includes?(intersection.x) &&
                    (0...data.size_y).includes?(intersection.y)

      # Try finding an alignment pattern around D
      alignment_point = refine_bottom_right(intersection, a_quad.center, unit, color) if version >= 2
      if alignment_point
        d = alignment_point
        bottom_right_offset = 6.5
      else
        d = intersection
        bottom_right_offset = 3.5
      end

      # Visualizer.set_data(data)
      # Visualizer.add_text(a_quad.center, "A")
      # Visualizer.add_point(a_quad.center, "#ff00ff")
      # Visualizer.add_point(a_quad.a, "#ff0000")
      # Visualizer.add_point(a_quad.b, "#0000ff")
      # Visualizer.add_point(a_quad.c, "#00ff00")
      # Visualizer.add_point(a_quad.d, "#ffff00")
      # Visualizer.add_text(b_quad.center, "B")
      # Visualizer.add_point(b_quad.center, "#ff00ff")
      # Visualizer.add_point(b_quad.a, "#ff0000")
      # Visualizer.add_point(b_quad.b, "#0000ff")
      # Visualizer.add_point(b_quad.c, "#00ff00")
      # Visualizer.add_point(b_quad.d, "#ffff00")
      # Visualizer.add_text(c_quad.center, "C")
      # Visualizer.add_point(c_quad.center, "#ff00ff")
      # Visualizer.add_point(c_quad.a, "#ff0000")
      # Visualizer.add_point(c_quad.b, "#0000ff")
      # Visualizer.add_point(c_quad.c, "#00ff00")
      # Visualizer.add_point(c_quad.d, "#ffff00")
      # Visualizer.add_point(d, "#ff00ff")
      # Visualizer.add_line(b_quad.center, b_quad.center + bd_vec*10)
      # Visualizer.add_line(c_quad.center, c_quad.center + cd_vec*10)
      # Visualizer.export

      QRLocation.new(
      QRLocation.new(QR,
        a_quad.center, b_quad.center, c_quad.center, d,
        version, color, {3.5, 3.5, 3.5, bottom_right_offset}
      )
    end

    # Refine the bottom right point by finding an alignment pattern around the given starting point
    private def refine_bottom_right(point : Point, a : Point, unit : Int, color : UInt8)
      est_alignment = point - (point - a).unit_vec * 3 * unit
      from = est_alignment - 5 * unit
      to = est_alignment + 5 * unit

      alignment_scangroups = LineScanner.scan_alignment_pat(data, from, to, color).max_by? do |q|
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

      alignment_scangroups.try(&.center)
    end
  end
end
