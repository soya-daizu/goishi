struct Goishi::LocatorSession
  module MQRLocator
    def locate_mqr(max_candidates : Int, & : QRLocation ->)
      candidates_count = 0

      @finder_quads.each do |q|
        return if candidates_count >= max_candidates

        top_angle, top_edges = q.ab.unit_vec, {q.inner_a, q.inner_b}
        left_angle, left_edges = q.ac.unit_vec, {q.inner_a, q.inner_c}
        bottom_angle, bottom_edges = q.cd.unit_vec, {q.inner_c, q.inner_d}
        right_angle, right_edges = q.bd.unit_vec, {q.inner_b, q.inner_d}

        location = nil
        {% for set in {
                        {:top, :left, :a},
                        {:left, :bottom, :c},
                        {:bottom, :right, :d},
                        {:right, :top, :b},
                      } %}
          {% s1, s2, top_left = set %}

          location = test_finder_mqr(
            q, q.inner_{{top_left.id}},
            {{s1.id}}_edges, {{s2.id}}_edges,
            {{s1.id}}_angle, {{s2.id}}_angle,
          ) unless location

        {% end %}
        next unless location

        yield location, candidates_count
        candidates_count += 1
      end
    end

    private def test_finder_mqr(q : Quad, top_left : Point,
                                side1 : Tuple(Point, Point), side2 : Tuple(Point, Point),
                                side1_vec : Point, side2_vec : Point)
      result = test_timing_patterns_mqr(
        side1, side2, side1_vec, side2_vec, q.color
      )
      return unless result

      a = top_left
      b, c, timing_mods = result
      version = timing_mods // 2 - 1
      mods = timing_mods + 7

      bd_vec = b + (c - a)
      cd_vec = c + (b - a)
      d_ab = Point.intersection(a, q.center, b, bd_vec) || return
      d_ac = Point.intersection(a, q.center, c, cd_vec) || return

      d = (d_ab + d_ac) / 2
      return unless d.x.in?(0...data.size_x) && d.y.in?(0...data.size_y)

      # Visualizer.set_data(data)
      # Visualizer.add_point(a, "#ff0000")
      # Visualizer.add_point(b, "#0000ff")
      # Visualizer.add_point(c, "#00ff00")
      # Visualizer.add_point(d, "#ffff00")
      # Visualizer.add_point(d_ab.not_nil!, "#ff00ff")
      # Visualizer.add_point(d_ac.not_nil!, "#ff00ff")
      # Visualizer.export

      QRLocation.new(MQR,
        a, b, c, d,
        version, q.color,
        {0.5, 0.5, 0.5, 0.5}
      )
    end

    private def test_timing_patterns_mqr(side1 : Tuple(Point, Point), side2 : Tuple(Point, Point),
                                         side1_vec : Point, side2_vec : Point, color : UInt8)
      b, ab_timing_mods = RayScanner.scan_timing_pattern(data, *side1, side1_vec, color) || return
      c, ac_timing_mods = RayScanner.scan_timing_pattern(data, *side2, side2_vec, color) || return
      return unless ab_timing_mods == ac_timing_mods

      {b, c, ab_timing_mods}
    end
  end
end
