struct Goishi::LocatorSession
  module LineScanner
    extend self

    def scan_finder_pat(data : Matrix(UInt8))
      finder_quads = [] of Quad

      data.each_row do |row, y|
        self.scan_finder_line(row) do |left, right, color|
          extending_quad_idx = finder_quads.index do |q|
            next unless q.color == color

            next unless q.bottom == y - 1 || q.bottom == y - 2

            err = q.unit_x * 2
            l_range = (q.left - err..q.left + err)
            next unless l_range.includes?(left)

            r_range = (q.right - err..q.right + err)
            next unless r_range.includes?(right)

            true
          end

          if extending_quad_idx
            extending_quad = finder_quads[extending_quad_idx]
            x_line = XScan.new(y, left, right)
            extending_quad.extend(x_line)

            finder_quads[extending_quad_idx] = extending_quad
          else
            new_quad = Quad.new(y, y, left, right, color)

            finder_quads.unshift(new_quad)
          end
        end
      end

      data.each_column do |column, x|
        self.scan_finder_line(column) do |top, bottom, color|
          extending_quad_idx = finder_quads.index do |q|
            next unless q.color == color

            lr_err = q.unit_x * 2
            lr_range = (q.left + lr_err..q.right - lr_err)
            next unless lr_range.includes?(x)

            unit_y = (bottom - top) / 7
            tb_err = unit_y * 2
            tb_range = (top + tb_err..bottom - tb_err)
            next unless tb_range.includes?(q.center_y)

            true
          end
          next unless extending_quad_idx

          extending_quad = finder_quads[extending_quad_idx]
          y_line = YScan.new(x, top, bottom)
          extending_quad.extend(y_line)

          finder_quads[extending_quad_idx] = extending_quad
        end
      end

      finder_quads.each.select { |q| q.x_scan_count > 1 && q.y_scan_count > 1 }
    end

    private def scan_finder_line(line : Enumerable(UInt8), & : Int32, Int32, UInt8 ->)
      buffer = Slice(Int32).new(5, 0)
      run_length, prev_value = 0, 0_u8

      line.each_with_index do |v, i|
        value = v > 0_u8 ? 1_u8 : 0_u8

        if i > 0 && value != prev_value
          buffer.rotate!
          buffer[4] = run_length
          run_length = 0

          if i >= 5
            unit = (buffer[0] + buffer[1] + buffer[3] + buffer[4]) / 4
            ratio = {1, 1, 3, 1, 1}.map do |r|
              ((r - 0.5) * unit).round_even..((r + 0.5) * unit).round_even
            end
            passed = buffer.each.with_index.all? { |length, j| ratio[j].includes?(length) }

            yield (i - buffer.sum), (i - 1), prev_value if passed
          end
        end

        run_length += 1
        prev_value = value
      end
    end

    protected def scan_alignment_pat(data : Matrix(UInt8), from : Point, to : Point, color : UInt8)
      alignment_quads = [] of Quad

      data.each_row_in_region(from, to) do |row, y|
        self.scan_alignment_line(row, color) do |left, right|
          extending_quad_idx = alignment_quads.index do |q|
            next unless q.bottom == y - 1

            err = q.unit_x
            l_range = (q.left - err..q.left + err)
            next unless l_range.includes?(left)

            r_range = (q.right - err..q.right + err)
            next unless r_range.includes?(right)

            true
          end

          if extending_quad_idx
            extending_quad = alignment_quads[extending_quad_idx]
            x_line = XScan.new(y, left, right)
            extending_quad.extend(x_line)

            alignment_quads[extending_quad_idx] = extending_quad
          else
            new_quad = Quad.new(y, y, left, right, color)

            alignment_quads.unshift(new_quad)
          end
        end
      end

      alignment_quads.select! do |q|
        next unless q.x_scan_count > 1

        unit_x, unit_y = q.unit_x(3), q.height
        unit = ((unit_x + unit_y) / 2).round_even

        center_x, center_y = q.center_x, q.center_y
        m1_x, m2_x, m3_x = (center_x - unit_x), center_x, (center_x + unit_x)

        temp_y = center_y
        until (data[m1_x, temp_y - 1]? || color) == color
          temp_y -= 1
        end
        m1_top = temp_y
        temp_y = center_y
        until (data[m1_x, temp_y + 1]? || color) == color
          temp_y += 1
        end
        m1_bottom = temp_y
        m1_unit_y = (m1_bottom - m1_top) / 3
        # The left and right tend to be shorter when the pattern is rhombus
        next unless (0.4..1.25).includes?(m1_unit_y / unit)

        temp_y = center_y
        color_changes, prev_color = 0, color
        until color_changes == 2
          c = data[m2_x, temp_y -= 1]?
          next if c == prev_color

          color_changes += 1
          prev_color = c
        end
        m2_top = temp_y + 1
        temp_y = center_y
        color_changes, prev_color = 0, color
        until color_changes == 2
          c = data[m2_x, temp_y += 1]?
          next if c == prev_color

          color_changes += 1
          prev_color = c
        end
        m2_bottom = temp_y - 1
        m2_unit_y = (m2_bottom - m2_top) / 3
        # The middle tend to be longer when the pattern is rhombus
        next unless (0.75..1.6).includes?(m2_unit_y / unit)

        temp_y = center_y
        until (data[m3_x, temp_y - 1]? || color) == color
          temp_y -= 1
        end
        m3_top = temp_y
        temp_y = center_y
        until (data[m3_x, temp_y + 1]? || color) == color
          temp_y += 1
        end
        m3_bottom = temp_y
        m3_unit_y = (m3_bottom - m3_top) / 3
        # The left and right tend to be be shorter when the pattern is rhombus
        next unless (0.4..1.25).includes?(m3_unit_y / unit)
        next unless (-0.4..0.4).includes?((m1_unit_y / unit) - (m3_unit_y / unit))

        true
      end

      alignment_quads.each
    end

    private def scan_alignment_line(line : Enumerable(Tuple(UInt8, Int32)), color : UInt8, & : Int32, Int32 ->)
      buffer = Slice(Int32).new(3, 0)
      run_length, prev_value = 0, 0_u8

      # i: index in the image
      # j: index in the region
      line.each_with_index do |v, j|
        value = v[0] > 0_u8 ? 1_u8 : 0_u8
        i = v[1]

        if j > 0 && value != prev_value
          buffer.rotate!
          buffer[2] = run_length
          run_length = 0

          if j >= 3 && value == color
            unit = buffer.sum / 3
            range = (0.6 * unit).round_even..(1.4 * unit).round_even
            passed = buffer.all? { |length| range.includes?(length) }

            yield (i - buffer.sum), (i - 1) if passed
          end
        end

        run_length += 1
        prev_value = value
      end
    end
  end
end
