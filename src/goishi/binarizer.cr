module Goishi
  module Binarizer
    MIN_DYNAMIC_RANGE = 24

    # Creates a new binarized canvas from a matrix of Tuples of each containing
    # RGB values of the pixel in the image.
    def self.binarize(data : Canvas(Tuple(UInt8, UInt8, UInt8)))
      data = self.grayscale(data)

      width, height = data.size_x, data.size_y
      x_block_count = width >> 3
      y_block_count = height >> 3
      x_block_size = (width / x_block_count).ceil.to_i
      y_block_size = (height / y_block_count).ceil.to_i

      avg_blocks = self.make_avg_blocks(data, x_block_count, y_block_count, x_block_size, y_block_size)

      binarized = Canvas(UInt8).new(data.size_x, data.size_y, 0_u8)

      y_block_count.times do |block_y|
        x_block_count.times do |block_x|
          left = block_x < 2 ? 2 : block_x > x_block_count - 3 ? x_block_count - 3 : block_x
          top = block_y < 2 ? 2 : block_y > y_block_count - 3 ? y_block_count - 3 : block_y
          sum = 0
          (-2..2).each do |xx|
            (-2..2).each do |yy|
              sum += avg_blocks[left + xx, top + yy]
            end
          end

          threshold = sum / 25
          y_block_size.times do |yy|
            x_block_size.times do |xx|
              x = block_x * x_block_size + xx
              y = block_y * y_block_size + yy
              lum = data[x, y]?
              next unless lum
              binarized[x, y] = lum <= threshold ? 1_u8 : 0_u8
            end
          end
        end
      end

      binarized
    end

    private def self.grayscale(data : Canvas(Tuple(UInt8, UInt8, UInt8)))
      Canvas(UInt8).new_with_values(data.size_x, data.size_y) do |i|
        r, g, b = data.data[i]
        # Lazy grayscaling according to CIE XYZ
        v = 0.2126 * r + 0.7152 * g + 0.0722 * b
        v.round_even.to_u8
      end
    end

    private def self.make_avg_blocks(data : Canvas(UInt8), x_block_count : Int, y_block_count : Int,
                                     x_block_size : Int, y_block_size : Int)
      block_avgs = Canvas(UInt8).new(x_block_count, y_block_count, 0_u8)

      y_block_count.times do |block_y|
        x_block_count.times do |block_x|
          sum, min, max, count = 0, 255, 0, 0

          y_block_size.times do |yy|
            x_block_size.times do |xx|
              x = block_x * x_block_size + xx
              y = block_y * y_block_size + yy
              pixel_lumosity = data[x, y]?
              next unless pixel_lumosity

              sum += pixel_lumosity
              count += 1
              next if max - min > MIN_DYNAMIC_RANGE

              min = Math.min(min, pixel_lumosity)
              max = Math.max(max, pixel_lumosity)
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
