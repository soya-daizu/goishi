require "stumpy_png"
require "stumpy_utils"

module Goishi
  module Visualizer
    extend self

    @@count = 0
    @@canvas = StumpyPNG::Canvas.new(1, 1)

    def set_data(data)
      @@canvas = StumpyPNG::Canvas.new(data.size_x, data.size_y) do |x, y|
        data[x, y] == 1 ? StumpyPNG::RGBA::BLACK : StumpyPNG::RGBA::WHITE
      end
    end

    def add_point(p : Point, hex : String? = nil)
      @@canvas.circle(p.x.to_i, p.y.to_i, 2, hex ? StumpyPNG::RGBA.from_hex(hex) : StumpyPNG::RGBA::RED, true)
    end

    def add_line(a : Point, b : Point, hex : String? = nil)
      @@canvas.line(a.x, a.y, b.x, b.y, hex ? StumpyPNG::RGBA.from_hex(hex) : StumpyPNG::RGBA::RED)
    end

    def export
      StumpyPNG.write(@@canvas, "debug#{@@count}.png")
      @@count += 1
    end
  end
end
