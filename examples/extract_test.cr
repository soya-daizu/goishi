require "stumpy_png"
require "../src/goishi"

def read_file(input_name : String)
  img = StumpyPNG.read(input_name)
  matrix = Goishi::Matrix(Tuple(UInt8, UInt8, UInt8)).new_with_values(img.width, img.height) do |i|
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

def decode_qr(input_name : String)
  puts input_name
  matrix = read_file(input_name)

  locator = Goishi::LocatorSession.new
  locator.set_data(matrix)
  locator.locate_qr(3) do |location|
    extractor = Goishi::Extractor.new(matrix)
    extracted_matrix = extractor.extract(location)
    extracted_matrix.invert if location.color == 0
    # write_file("debug.png", extracted_matrix)

    segments = begin
      Goishi::QR::Decoder.decode(extracted_matrix).segments
    rescue e : Goishi::QR::Decoder::VersionMismatchError
      location.version = e.actual_version
      extracted_matrix = extractor.extract(location)
      Goishi::QR::Decoder.decode(extracted_matrix).segments rescue next
    rescue e
      extracted_matrix = extractor.extract(location)
      extracted_matrix.flip_tr_bl
      Goishi::QR::Decoder.decode(extracted_matrix).segments rescue next
    end
    p! segments.join(&.text)

    break
  end
end

def decode_mqr(input_name : String)
  puts input_name
  matrix = read_file(input_name)

  locator = Goishi::LocatorSession.new
  locator.set_data(matrix)
  locator.locate_mqr(3) do |location|
    extractor = Goishi::Extractor.new(matrix)
    extracted_matrix = extractor.extract(location)
    extracted_matrix.invert if location.color == 0
    write_file("debug.png", extracted_matrix)

  end
end

# decode_qr("examples/assets/qr/test.png")
# decode_qr("examples/assets/qr/skewed1.png")
# decode_qr("examples/assets/qr/skewed2.png")
# decode_qr("examples/assets/qr/hflipped.png")
# decode_qr("examples/assets/qr/vflipped.png")
# 0.step(to: 330, by: 30) do |i|
#  decode_qr("examples/assets/qr/rotate#{i}.png")
# end
# 5.times do |i|
#   decode_qr("examples/assets/qr/real_world#{i + 1}.png")
# end

decode_mqr("examples/assets/mqr/test.png")
