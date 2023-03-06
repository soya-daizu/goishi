require "./decoder/*"

module Goishi
  struct Decoder
    @data : Matrix(UInt8)
    @version : Int32?

    def initialize(@data)
      raise "Matrix not square" unless @data.size_x == @data.size_y
    end

    def decode
      version = read_version
      format_info = read_format
    end

    def read_version
      return @version.not_nil! if @version

      size = @data.size_x
      v = (size - 17) // 4
      return v if v < 7

      v1_bits, v2_bits = 0, 0
      (0...18).reverse_each do |i|
        x = size - 11 + i % 3
        y = i // 3

        v1_bits = (v1_bits << 1) | @data[x, y]
        v2_bits = (v2_bits << 1) | @data[y, x]
      end
      puts v1_bits.to_s(2).rjust(18, '0'), v2_bits.to_s(2).rjust(18, '0')

      v1_best, v1_best_diff = 0, 18
      v2_best, v2_best_diff = 0, 18
      VERSION_BITS.each_with_index do |bits, ver|
        ver = ver + 7

        v1_diff = count_diff(bits, v1_bits)
        if v1_diff < v1_best_diff
          v1_best = ver
          v1_best_diff = v1_diff
        end

        v2_diff = count_diff(bits, v2_bits)
        if v2_diff < v2_best_diff
          v2_best = ver
          v2_best_diff = v2_diff
        end
      end
      puts({v1_best, v1_best_diff})
      puts({v2_best, v2_best_diff})

      return -1 if v1_best_diff > 3 && v2_best_diff > 3

      @version = v1_best_diff <= v2_best_diff ? v1_best : v2_best
    end

    private def read_format
      size = @data.size_x

      f1_bits, f2_bits = 0, 0
      # 14..8
      (8..14).reverse_each do |i|
        pos = i == 8 ? 7 : (14 - i)
        f1_bits = (f1_bits << 1) | @data[pos, 8]
        pos = size - 1 - (14 - i)
        f2_bits = (f2_bits << 1) | @data[8, pos]
      end
      # 7..0
      (0..7).reverse_each do |i|
        pos = i >= 6 ? i + 1 : i
        f1_bits = (f1_bits << 1) | @data[8, pos]
        pos = size - 1 - i
        f2_bits = (f2_bits << 1) | @data[pos, 8]
      end
      puts f1_bits.to_s(2).rjust(15, '0'), f2_bits.to_s(2).rjust(15, '0')

      f1_best, f1_best_diff = nil, 15
      f2_best, f2_best_diff = nil, 15
      FORMAT_BITS.each do |bits, format_info|
        f1_diff = count_diff(bits, f1_bits)
        if f1_diff < f1_best_diff
          f1_best = format_info
          f1_best_diff = f1_diff
        end

        f2_diff = count_diff(bits, f2_bits)
        if f2_diff < f2_best_diff
          f2_best = format_info
          f2_best_diff = f2_diff
        end
      end
      puts({f1_best, f1_best_diff})
      puts({f2_best, f2_best_diff})

      return -1 if f1_best_diff > 3 && f2_best_diff > 3

      f1_best_diff <= f2_best_diff ? f1_best : f2_best
    end

    private def count_diff(x : Int, y : Int)
      z, count = (x ^ y), 0
      while z > 0
        z &= z - 1
        count += 1
      end

      count
    end
  end
end
