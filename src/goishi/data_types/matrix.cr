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

    def each_row_in_region(from : Goishi::Point, to : Goishi::Point, & : Iterator(Tuple(UInt8, Int32)), Int32 ->)
      (from.y.to_i..to.y.to_i).each do |y|
        row = (from.x.to_i..to.x.to_i).each.map { |x| {self[x, y], x} }
        yield row, y
      end
    end

    def each_column_in_region(from : Goishi::Point, to : Goishi::Point, & : Iterator(Tuple(UInt8, Int32)), Int32 ->)
      (from.x.to_i..to.x.to_i).each do |x|
        column = (from.y.to_i..to.y.to_i).each.map { |y| {self[x, y], y} }
        yield column, x
      end
    end
  end
end
