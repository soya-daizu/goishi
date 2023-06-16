struct Goishi::LocatorSession
  module LineScanner
    extend self

    def scan_finder_pat(data : Canvas(UInt8))
      finder_scangroups = [] of ScanGroup

      data.each_row do |row, y|
        self.scan_finder_line(row) do |left, right, color|
          extending_scangroup_idx = finder_scangroups.index do |sg|
            next unless sg.color == color

            y_range = (sg.bottom..sg.bottom + 5)
            next unless y.in?(y_range)

            unit_x = sg.unit_x
            l_range = (sg.left - unit_x..sg.left + unit_x)
            next unless left.in?(l_range)

            r_range = (sg.right - unit_x..sg.right + unit_x)
            next unless right.in?(r_range)

            true
          end

          if extending_scangroup_idx
            extending_scangroup = finder_scangroups[extending_scangroup_idx]
            x_line = XScan.new(y, left, right)
            extending_scangroup.extend(x_line)

            finder_scangroups[extending_scangroup_idx] = extending_scangroup
          else
            new_scangroup = ScanGroup.new(y, y, left, right, color)

            finder_scangroups.unshift(new_scangroup)
          end
        end
      end

      data.each_column do |column, x|
        self.scan_finder_line(column) do |top, bottom, color|
          extending_scangroup_idx = finder_scangroups.index do |sg|
            next unless sg.color == color

            lr_err = sg.unit_x
            lr_range = (sg.left + lr_err..sg.right - lr_err)
            next unless x.in?(lr_range)

            if sg.y_scan_count == 0
              center_y = (top + bottom) / 2
              unit_y = (bottom - top) / 7
              center_range = (center_y - unit_y..center_y + unit_y)
              next unless sg.center_y.in?(center_range)
            else
              unit_y = sg.unit_y
              t_range = (sg.top - unit_y..sg.top + unit_y)
              next unless top.in?(t_range)

              b_range = (sg.bottom - unit_y..sg.bottom + unit_y)
              next unless bottom.in?(b_range)
            end

            true
          end
          next unless extending_scangroup_idx

          extending_scangroup = finder_scangroups[extending_scangroup_idx]
          y_line = YScan.new(x, top, bottom)
          extending_scangroup.extend(y_line)

          finder_scangroups[extending_scangroup_idx] = extending_scangroup
        end
      end

      # Visualizer.set_data(data)
      # finder_scangroups.each do |sg|
      #  color = "##{Random::DEFAULT.hex(3)}"
      #  Visualizer.add_point(Point.new(sg.left, sg.top), color)
      #  Visualizer.add_point(Point.new(sg.right, sg.top), color)
      #  Visualizer.add_point(Point.new(sg.left, sg.bottom), color)
      #  Visualizer.add_point(Point.new(sg.right, sg.bottom), color)
      #  Visualizer.add_line(Point.new(sg.left, sg.top), Point.new(sg.right, sg.top), color)
      #  Visualizer.add_line(Point.new(sg.left, sg.bottom), Point.new(sg.right, sg.bottom), color)
      #  Visualizer.add_line(Point.new(sg.left, sg.top), Point.new(sg.left, sg.bottom), color)
      #  Visualizer.add_line(Point.new(sg.right, sg.top), Point.new(sg.right, sg.bottom), color)
      # end
      # Visualizer.export

      finder_scangroups.each.select { |sg| sg.x_scan_count > 1 && sg.y_scan_count > 1 }
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
            passed = buffer.each.with_index.all? { |length, j| length.in?(ratio[j]) }

            yield (i - buffer.sum), (i - 1), prev_value if passed
          end
        end

        run_length += 1
        prev_value = value
      end
    end

    protected def scan_alignment_pat(data : Canvas(UInt8), from : Point, to : Point, color : UInt8)
      alignment_scangroups = [] of ScanGroup

      data.each_row_in_region(from, to) do |row, y|
        self.scan_alignment_line(row, color) do |left, right|
          extending_scangroup_idx = alignment_scangroups.index do |sg|
            y_range = (sg.bottom..sg.bottom + 2)
            next unless y.in?(y_range)

            err = sg.unit_x(3)
            l_range = (sg.left - err..sg.left + err)
            next unless left.in?(l_range)

            r_range = (sg.right - err..sg.right + err)
            next unless right.in?(r_range)

            true
          end

          if extending_scangroup_idx
            extending_scangroup = alignment_scangroups[extending_scangroup_idx]
            x_line = XScan.new(y, left, right)
            extending_scangroup.extend(x_line)

            alignment_scangroups[extending_scangroup_idx] = extending_scangroup
          else
            new_scangroup = ScanGroup.new(y, y, left, right, color)

            alignment_scangroups.unshift(new_scangroup)
          end
        end
      end

      alignment_scangroups.select! do |sg|
        sg.x_scan_count > 1
      end

      # Visualizer.set_data(data)
      # alignment_scangroups.each do |sg|
      #   color = "##{Random::DEFAULT.hex(3)}"
      #   Visualizer.add_point(Point.new(sg.left, sg.top), color)
      #   Visualizer.add_point(Point.new(sg.right, sg.top), color)
      #   Visualizer.add_point(Point.new(sg.left, sg.bottom), color)
      #   Visualizer.add_point(Point.new(sg.right, sg.bottom), color)
      #   Visualizer.add_line(Point.new(sg.left, sg.top), Point.new(sg.right, sg.top), color)
      #   Visualizer.add_line(Point.new(sg.left, sg.bottom), Point.new(sg.right, sg.bottom), color)
      #   Visualizer.add_line(Point.new(sg.left, sg.top), Point.new(sg.left, sg.bottom), color)
      #   Visualizer.add_line(Point.new(sg.right, sg.top), Point.new(sg.right, sg.bottom), color)
      # end
      # Visualizer.export

      alignment_scangroups.each
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
            passed = buffer.all? { |length| length.in?(range) }

            yield (i - buffer.sum), (i - 1) if passed
          end
        end

        run_length += 1
        prev_value = value
      end
    end
  end
end
