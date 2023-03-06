require "stumpy_png"
require "../src/goishi"

def read_file(input_name : String)
  img = StumpyPNG.read(input_name)
  matrix = Goishi::Matrix(Tuple(UInt8, UInt8, UInt8)).new(img.width, img.height) do |i|
    img.pixels[i].to_rgb8
  end

  Goishi::Binarizer.binarize(matrix)
end

def write_file(output_name : String, matrix : Goishi::Matrix(UInt8))
  canvas = StumpyPNG::Canvas.new(matrix.size_x, matrix.size_y) do |x, y|
    StumpyPNG::RGBA.from_gray_n(matrix[x, y] == 1 ? 0 : 255, 8)
  end

  StumpyPNG.write(canvas, output_name)
end

def extract(input_name : String, output_name : String)
  puts input_name
  matrix = read_file(input_name)

  locator = Goishi::Locator.new(matrix)
  locator.locate_qr(20) do |location|
    puts location
    extractor = Goishi::Extractor.new(matrix)
    extracted_matrix = extractor.extract(location) rescue next

    decoder = Goishi::Decoder.new(extracted_matrix)
    actual_version = decoder.read_version
    next if actual_version < 1

    if location.version != actual_version
      location.version = actual_version
      extracted_matrix = extractor.extract(location) rescue next
      decoder = Goishi::Decoder.new(extracted_matrix)

      # Double check the version corrected
      next unless decoder.read_version == actual_version
    end

    decoder.decode

    write_file(output_name, extracted_matrix)
    break
  end
end

# extract("examples/assets/test.png", "examples/assets/test_b.png")
# extract("examples/assets/skewed1.png", "examples/assets/skewed1_b.png")
# extract("examples/assets/skewed2.png", "examples/assets/skewed2_b.png")
# extract("examples/assets/hflipped.png", "examples/assets/hflipped_b.png")
# extract("examples/assets/vflipped.png", "examples/assets/vflipped_b.png")
# 0.step(to: 330, by: 30) do |i|
#  extract("examples/assets/rotate#{i}.png", "examples/assets/rotate#{i}_b.png")
# end
5.times do |i|
 extract("examples/assets/real_world#{i + 1}.png", "examples/assets/real_world#{i + 1}_b.png")
end
