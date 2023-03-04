module Goishi
  struct Matrix(T)
    include Indexable::Mutable(T)

    getter size_x : Int32
    getter size_y : Int32
    getter data : Slice(T)

    delegate size, to: @data
    delegate unsafe_fetch, to: @data
    delegate unsafe_put, to: @data

    def initialize(@size_x, @size_y, value)
      @data = Slice.new(@size_x * @size_y, value)
    end

    def initialize(@size_x, @size_y, & : Int32, Int32, Int32 -> T)
      x, y = 0, 0
      @data = Slice.new(@size_x * @size_y) do |i|
        v = yield i, x, y

        x += 1
        if x == @size_x
          x = 0
          y += 1
        end

        v
      end
    end

    def each_row(& : Iterator(UInt8), Int32 ->)
      @size_y.times do |y|
        row = @size_x.times.map { |x| self[x, y] }
        yield row, y
      end
    end

    def each_column(& : Iterator(UInt8), Int32 ->)
      @size_x.times do |x|
        column = @size_y.times.map { |y| self[x, y] }
        yield column, x
      end
    end

    def each_row_in_region(from : Point, to : Point, & : Iterator(Tuple(UInt8, Int32)), Int32 ->)
      (from.y.to_i..to.y.to_i).each do |y|
        row = (from.x.to_i..to.x.to_i).each.map { |x| {self[x, y], x} }
        yield row, y
      end
    end

    def each_column_in_region(from : Point, to : Point, & : Iterator(Tuple(UInt8, Int32)), Int32 ->)
      (from.x.to_i..to.x.to_i).each do |x|
        column = (from.y.to_i..to.y.to_i).each.map { |y| {self[x, y], y} }
        yield column, x
      end
    end

    @[AlwaysInline]
    def [](x : Int, y : Int)
      @data[y * @size_x + x]
    end

    @[AlwaysInline]
    def []?(x : Int, y : Int)
      @data[y * @size_x + x]?
    end

    @[AlwaysInline]
    def [](point : Point)
      self[point.x.to_i, point.y.to_i]
    end

    @[AlwaysInline]
    def [](point : Point)
      self[point.x.to_i, point.y.to_i]?
    end

    @[AlwaysInline]
    def []=(x : Int, y : Int, value : UInt8)
      @data[y * @size_x + x] = value
    end

    @[AlwaysInline]
    def []=(x : Int, y : Int, w : Int, h : Int, value : UInt8)
      (x...x + w).each do |xx|
        (y...y + h).each do |yy|
          self[xx, yy] = value
        end
      end
    end
  end
end
