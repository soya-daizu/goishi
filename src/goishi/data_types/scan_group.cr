module Goishi
  struct ScanGroup
    getter top : Int32
    getter bottom : Int32
    getter left : Int32
    getter right : Int32
    getter color : UInt8

    getter top_scans : YScanGroup
    getter bottom_scans : YScanGroup
    getter left_scans : XScanGroup
    getter right_scans : XScanGroup

    getter x_scan_count : Int32
    getter y_scan_count : Int32

    def initialize(@top, @bottom, @left, @right, @color)
      @top_scans = YScanGroup.empty
      @bottom_scans = YScanGroup.empty
      @left_scans = XScanGroup.new(XScan.new(@top, @left, @right))
      @right_scans = XScanGroup.new(XScan.new(@top, @left, @right))
      @x_scan_count = 1
      @y_scan_count = 0
    end

    def extend(x_line : XScan)
      @bottom = Math.max(@bottom, x_line.y)
      @left = Math.min(@left, x_line.left)
      @right = Math.max(@right, x_line.right)

      @left_scans.extend_by_left(x_line)
      @right_scans.extend_by_right(x_line)
      @x_scan_count += 1
    end

    def extend(y_line : YScan)
      @top = Math.min(@top, y_line.top)
      @bottom = Math.max(@bottom, y_line.bottom)

      @top_scans.extend_by_top(y_line)
      @bottom_scans.extend_by_bottom(y_line)
      @y_scan_count += 1
    end

    def width
      @right - @left
    end

    def height
      @bottom - @top
    end

    def unit_x(mod_count : Int = 7)
      (width / mod_count).round_even.to_i
    end

    def unit_y(mod_count : Int = 7)
      (height / mod_count).round_even.to_i
    end

    def aspect_ratio
      width / height
    end

    def center_x
      ((@left + @right) / 2).round_even.to_i
    end

    def center_y
      ((@top + @bottom) / 2).round_even.to_i
    end

    def center
      Point.new(center_x, center_y)
    end
  end

  struct XScanGroup
    getter first : XScan
    getter last : XScan
    getter min : XScan
    getter max : XScan
    getter count : Int32

    def initialize(@first, @count = 1)
      @last = @first
      @min = @first
      @max = @first
    end

    def self.empty
      self.new(XScan.new(0, 0, 0), 0)
    end

    macro extend_by(prop)
      if @count == 0
        @first = x_line
        @min = x_line
        @max = x_line
      end

      @last = x_line
      @min = x_line if x_line.{{prop.id}} < min.{{prop.id}}
      @max = x_line if x_line.{{prop.id}} > max.{{prop.id}}
      @count += 1
    end

    def extend_by_left(x_line : XScan)
      extend_by(:left)
    end

    def extend_by_right(x_line : XScan)
      extend_by(:right)
    end
  end

  struct YScanGroup
    getter first : YScan
    getter last : YScan
    getter min : YScan
    getter max : YScan
    getter count : Int32

    def initialize(@first, @count = 1)
      @last = @first
      @min = @first
      @max = @first
    end

    def self.empty
      self.new(YScan.new(0, 0, 0), 0)
    end

    macro extend_by(prop)
      if @count == 0
        @first = y_line
        @min = y_line
        @max = y_line
      end

      @last = y_line
      @min = y_line if y_line.{{prop.id}} < min.{{prop.id}}
      @max = y_line if y_line.{{prop.id}} > max.{{prop.id}}
      @count += 1
    end

    def extend_by_top(y_line : YScan)
      extend_by(:top)
    end

    def extend_by_bottom(y_line : YScan)
      extend_by(:bottom)
    end
  end

  struct XScan
    getter y : Int32
    getter left : Int32
    getter right : Int32

    def initialize(@y, @left, @right)
    end
  end

  struct YScan
    getter x : Int32
    getter top : Int32
    getter bottom : Int32

    def initialize(@x, @top, @bottom)
    end
  end
end
