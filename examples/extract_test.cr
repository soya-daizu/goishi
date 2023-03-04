require "stumpy_png"
require "../src/goishi"

def extract(input_name : String, output_name : String)
  img = StumpyPNG.read(input_name)

  matrix = Goishi::Matrix(Tuple(UInt8, UInt8, UInt8)).new(img.width, img.height) do |i|
    img.pixels[i].to_rgb8
  end

  matrix = Goishi::Preprocessor.binarize(matrix)
  locator = Goishi::Locator.new(matrix)
  location = locator.locate_qr.first
  extractor = Goishi::Extractor.new(matrix, location)
  matrix = extractor.extract

  canvas = StumpyPNG::Canvas.new(matrix.size_x, matrix.size_y) do |x, y|
    StumpyPNG::RGBA.from_gray_n(matrix[x, y] == 1 ? 0 : 255, 8)
  end
  StumpyPNG.write(canvas, output_name)
end

# extract("examples/assets/skewed1.png", "examples/assets/skewed1_b.png")
# extract("examples/assets/skewed2.png", "examples/assets/skewed2_b.png")
# extract("examples/assets/hflipped.png", "examples/assets/hflipped_b.png")
# extract("examples/assets/vflipped.png", "examples/assets/vflipped_b.png")
# 0.step(to: 330, by: 30) do |i|
#  extract("examples/assets/rotate#{i}.png", "examples/assets/rotate#{i}_b.png")
# end
# 4.times do |i|
#  extract("examples/assets/rotate#{i + 1}.png", "examples/assets/rotate#{i + 1}_b.png")
# end
