require "stumpy_png"
require "stumpy_utils"

module Goishi
  module Visualizer
    extend self

    @@count = 0
    @@canvas = StumpyPNG::Canvas.new(1, 1)
    @@font : PCFParser::Font = PCFParser::Font.from_file("./ter-x14n.pcf")

    def set_data(data)
      @@canvas = StumpyPNG::Canvas.new(data.size_x, data.size_y) do |x, y|
        data[x, y] == 1 ? StumpyPNG::RGBA::BLACK : StumpyPNG::RGBA::WHITE
      end
    end

    def add_point(p : Point, hex : String? = nil)
      color = hex ? StumpyPNG::RGBA.from_hex(hex) : StumpyPNG::RGBA::RED
      # @@canvas[p.x.round_even.to_i, p.y.round_even.to_i] = color
      @@canvas.circle(p.x.to_i, p.y.to_i, 2, hex ? StumpyPNG::RGBA.from_hex(hex) : StumpyPNG::RGBA::RED, true)
    end

    def add_line(a : Point, b : Point, hex : String? = nil)
      color = hex ? StumpyPNG::RGBA.from_hex(hex) : StumpyPNG::RGBA::RED
      @@canvas.line(a.x.round_even, a.y.round_even, b.x.round_even, b.y.round_even, color)
    end

    def add_text(p : Point, text : String, hex : String? = nil)
      color = hex ? StumpyPNG::RGBA.from_hex(hex) : StumpyPNG::RGBA::RED
      @@canvas.text(p.x.round_even.to_i, p.y.round_even.to_i, text, @@font, color)
    end

    def export
      StumpyPNG.write(@@canvas, "debug#{@@count}.png")
      @@count += 1
    end
  end
end
