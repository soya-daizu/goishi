module Goishi
  module Binarizer
    BLOCK_COUNT       = 18
    MIN_DYNAMIC_RANGE = 24

    # Creates a new binarized matrix from a matrix of Tuples of each containing
    # RGB values of the pixel in the image.
    def self.binarize(data : Matrix(Tuple(UInt8, UInt8, UInt8)))
      data = self.grayscale(data)

      block_size = (Math.max(data.size_x, data.size_y) / BLOCK_COUNT).ceil.to_i
      avg_blocks = self.make_avg_blocks(data, block_size)

      binarized = Matrix(UInt8).new(data.size_x, data.size_y, 0_u8)

      BLOCK_COUNT.times do |block_y|
        BLOCK_COUNT.times do |block_x|
          left = block_x < 2 ? 2 : block_x > BLOCK_COUNT - 3 ? BLOCK_COUNT - 3 : block_x
          top = block_y < 2 ? 2 : block_y > BLOCK_COUNT - 3 ? BLOCK_COUNT - 3 : block_y
          sum = 0
          (-2..2).each do |xx|
            (-2..2).each do |yy|
              sum += avg_blocks[left + xx, top + yy]
            end
          end

          threshold = sum / 25
          block_size.times do |yy|
            block_size.times do |xx|
              x = block_x * block_size + xx
              y = block_y * block_size + yy
              lum = data[x, y]?
              next unless lum
              binarized[x, y] = lum <= threshold ? 1_u8 : 0_u8
            end
          end
        end
      end

      binarized
    end

    private def self.grayscale(data : Matrix(Tuple(UInt8, UInt8, UInt8)))
      Matrix(UInt8).new_with_values(data.size_x, data.size_y) do |i|
        r, g, b = data.data[i]
        # Lazy grayscaling according to CIE XYZ
        v = 0.2126 * r + 0.7152 * g + 0.0722 * b
        v.round_even.to_u8
      end
    end

    private def self.make_avg_blocks(data : Matrix(UInt8), block_size : Int)
      block_avgs = Matrix(UInt8).new(BLOCK_COUNT, BLOCK_COUNT, 0_u8)

      BLOCK_COUNT.times do |block_y|
        BLOCK_COUNT.times do |block_x|
          sum, min, max, count = 0, 255, 0, 0

          block_size.times do |yy|
            block_size.times do |xx|
              x = block_x * block_size + xx
              y = block_y * block_size + yy
              pixel_lumosity = data[x, y]?
              next unless pixel_lumosity

              sum += pixel_lumosity
              min = Math.min(min, pixel_lumosity)
              max = Math.max(max, pixel_lumosity)
              count += 1
            end
          end

          avg = sum / count
          if max - min <= MIN_DYNAMIC_RANGE
            avg = min / 2

            if block_y > 0 && block_x > 0
              avg_neighbor_bp = (
                block_avgs[block_x, block_y - 1].to_i +
                2 * block_avgs[block_x - 1, block_y] +
                block_avgs[block_x - 1, block_y - 1]
              ) / 4

              avg = avg_neighbor_bp if min < avg_neighbor_bp
            end
          end

          block_avgs[block_x, block_y] = avg.round_even.to_u8
        end
      end

      block_avgs
    end
  end
end
