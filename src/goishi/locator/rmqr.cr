struct Goishi::LocatorSession
  module RMQRLocator
    def locate_rmqr(max_candidates : Int, & : QRLocation ->)
      candidates_count = 0

      @finder_quads.each do |q|
        return if candidates_count >= max_candidates

        location = nil
        {% for set in { {:ab, :ac}, {:ca, :cd}, {:dc, :db}, {:bd, :ba} } %}
          {% s1, s2 = set %}
          {% top_left = s1.chars[0].id %}
          s1_edges = { q.inner_{{s1.chars[0].id}}, q.inner_{{s1.chars[1].id}} }
          s2_edges = { q.inner_{{s2.chars[0].id}}, q.inner_{{s2.chars[1].id}} }

          location = test_finder_rmqr(
            q, q.inner_{{top_left.id}},
            s1_edges, s2_edges,
            q.{{s1.id}}.unit_vec, q.{{s2.id}}.unit_vec,
          ) unless location

        {% end %}
        next unless location

        yield location, candidates_count
        candidates_count += 1
      end
    end

    private def test_finder_rmqr(q : Quad, top_left : Point,
                                 side1 : Tuple(Point, Point), side2 : Tuple(Point, Point),
                                 side1_vec : Point, side2_vec : Point)
      b, c, d, w_mods, h_mods = test_timing_patterns_rmqr(
        side1, side2, side1_vec, side2_vec, q.color
      ) || return

      a = top_left
      version = RMQR::VersionValue.parse("R#{h_mods}x#{w_mods}") rescue return

      ac, cd = (c - a), (d - c)
      ac_unit = ac.length / (h_mods - 1)
      cd_unit = cd.length / (w_mods - 1)
      est_alignment = d - ac.unit_vec*ac_unit*2 - cd.unit_vec*cd_unit*2
      unit = ((ac_unit + cd_unit) / 2).round_even.to_i
      d = refine_bottom_right(est_alignment, unit, q.color)
      return unless d

      Visualizer.set_data(data)
      Visualizer.add_point(a, "#ff0000")
      Visualizer.add_point(b, "#0000ff")
      Visualizer.add_point(c, "#00ff00")
      Visualizer.add_point(d, "#ffff00")
      Visualizer.export

      QRLocation.new(RMQR,
        a, b, c, d,
        version.to_i, q.color,
        {0.5, 0.5, 0.5, 2.5}
      )
    end

    private def test_timing_patterns_rmqr(side1 : Tuple(Point, Point), side2 : Tuple(Point, Point),
                                          side1_vec : Point, side2_vec : Point, color : UInt8)
      b, h_timing_e1, ab_timing_mods, b_success = RayScanner.scan_timing_pattern_rmqr(
        data, *side1, 6, side1_vec, color, false
      ) || return
      c, v_timing_e1, ac_timing_mods, c_success = RayScanner.scan_timing_pattern_rmqr(
        data, *side2, 6, side2_vec, color, true
      ) || return
      return if ab_timing_mods == ac_timing_mods
      return unless b_success && c_success
      if ab_timing_mods < ac_timing_mods
        b, c = c, b
        h_timing_e1, v_timing_e1 = v_timing_e1, h_timing_e1
        ab_timing_mods, ac_timing_mods = ac_timing_mods, ab_timing_mods
      end

      v_timing_vec = (c - v_timing_e1).unit_vec
      h_timing_vec = (b - h_timing_e1).unit_vec

      h_timing2_e1 = c
      h_timing2_vec, h_timing2_e1, h_timing2_e2 = RayScanner.scan_subalignment_vec_rmqr(
        data, h_timing2_e1, v_timing_vec, h_timing_vec, color
      )
      h_timing_vec, h_timing_e1, h_timing_e2 = RayScanner.scan_subalignment_vec_rmqr(
        data, h_timing_e1, v_timing_vec.inv, h_timing_vec, color
      )

      d, h_timing2_e1, cd_timing_mods, d_success = RayScanner.scan_timing_pattern_rmqr(
        data, h_timing2_e1, h_timing2_e2, 3, h_timing2_vec, color, true
      ) || return
      h_timing2_vec, h_timing2_e1, h_timing2_e2 = RayScanner.scan_subalignment_vec_rmqr(
        data, h_timing2_e1, v_timing_vec, h_timing2_vec, color
      )

      until !d_success
        ab_scan_result = RayScanner.scan_timing_pattern_rmqr(
          data, h_timing_e1, h_timing_e2, 3, h_timing_vec, color, false
        )
        cd_scan_result = RayScanner.scan_timing_pattern_rmqr(
          data, h_timing2_e1, h_timing2_e2, 3, h_timing2_vec, color, true
        )
        break unless ab_scan_result && cd_scan_result
        b, h_timing_e1, ab_timing_mods_, b_success = ab_scan_result
        d, h_timing2_e1, cd_timing_mods_, d_success = cd_scan_result
        ab_timing_mods += ab_timing_mods_
        cd_timing_mods += cd_timing_mods_
        break unless b_success && d_success

        h_timing_vec, h_timing_e1, h_timing_e2 = RayScanner.scan_subalignment_vec_rmqr(
          data, h_timing_e1, v_timing_vec.inv, h_timing_vec, color
        )
        h_timing2_vec, h_timing2_e1, h_timing2_e2 = RayScanner.scan_subalignment_vec_rmqr(
          data, h_timing2_e1, v_timing_vec, h_timing2_vec, color
        )
      end

      ab_mods = 7 + ab_timing_mods
      cd_mods = 3 + cd_timing_mods
      ac_mods = 7 + ac_timing_mods
      return unless ab_mods == cd_mods

      {b, c, d, ab_mods, ac_mods}
    end
  end
end
