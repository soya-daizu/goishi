module Goban
  struct Matrix(T)
    @[AlwaysInline]
    def [](point : Goishi::Point)
      self[point.x.to_i, point.y.to_i]
    end

    @[AlwaysInline]
    def [](point : Goishi::Point)
      self[point.x.to_i, point.y.to_i]?
    end

    def invert
      @data.map! do |v|
        v == 0 ? 1_u8 : 0_u8
      end
    end

    def flip_tr_bl
      (0...@size_x).each do |x|
        (x...@size_y).each do |y|
          a, b = self[x, y], self[y, x]
          next if a == b
          self[x, y] = a == 0_u8 ? 1_u8 : 0_u8
          self[y, x] = b == 0_u8 ? 1_u8 : 0_u8
        end
      end
    end

    def each_row_in_region(from : Goishi::Point, to : Goishi::Point, & : Iterator(Tuple(UInt8, Int32)), Int32 ->)
      from.max(0, 0)
      to.min(@size_x - 1, @size_y - 1)

      (from.y.to_i..to.y.to_i).each do |y|
        row = (from.x.to_i..to.x.to_i).each.map { |x| {self[x, y], x} }
        yield row, y
      end
    end

    def each_column_in_region(from : Goishi::Point, to : Goishi::Point, & : Iterator(Tuple(UInt8, Int32)), Int32 ->)
      from.max(0, 0)
      to.min(@size_x - 1, @size_y - 1)

      (from.x.to_i..to.x.to_i).each do |x|
        column = (from.y.to_i..to.y.to_i).each.map { |y| {self[x, y], y} }
        yield column, x
      end
    end
  end
end
