require "stumpy_png"
require "stumpy_jpeg"
require "../src/goishi"

def read_file(input_name : String)
  img = if input_name.ends_with?(".png")
          StumpyPNG.read(input_name)
        elsif input_name.ends_with?(".jpg")
          StumpyJPEG.read(input_name)
        else
          raise "Unsupported image format"
        end
  canvas = Goishi::Canvas(Tuple(UInt8, UInt8, UInt8)).new_with_values(img.width, img.height) do |i|
    img.pixels[i].to_rgb8
  end

  Goishi::Binarizer.binarize(canvas)
end

def write_file(output_name : String, canvas : Goishi::Canvas(UInt8))
  canvas = StumpyPNG::Canvas.new(canvas.size_x, canvas.size_y) do |x, y|
    StumpyPNG::RGBA.from_gray_n(canvas[x, y] == 1 ? 0 : 255, 8)
  end

  StumpyPNG.write(canvas, output_name)
end

def decode_qr(input_name : String)
  puts input_name
  canvas = read_file(input_name)

  locator = Goishi::LocatorSession.new
  locator.set_data(canvas)
  locator.locate_qr(100) do |location, i|
    # p! location
    extractor = Goishi::Extractor.new(canvas)
    extracted_canvas = extractor.extract(location)
    extracted_canvas.invert if location.color == 0
    write_file("extracted#{i}.png", extracted_canvas)

    string = begin
      Goishi::QR::Decoder.decode_to_string(extracted_canvas)
    rescue e : Goishi::QR::Decoder::VersionMismatchError
      puts e
      location.version = e.actual_version
      extracted_canvas = extractor.extract(location)
      Goishi::QR::Decoder.decode_to_string(extracted_canvas) rescue next
    rescue e
      puts e
      extracted_canvas = extractor.extract(location)
      extracted_canvas.flip_tr_bl
      Goishi::QR::Decoder.decode_to_string(extracted_canvas) rescue next
    end
    p! string

    break
  end
end

def decode_mqr(input_name : String)
  puts input_name
  canvas = read_file(input_name)

  locator = Goishi::LocatorSession.new
  locator.set_data(canvas)
  locator.locate_mqr(100) do |location, i|
    # p! location
    extractor = Goishi::Extractor.new(canvas)
    extracted_canvas = extractor.extract(location)
    extracted_canvas.invert if location.color == 0
    write_file("extracted#{i}.png", extracted_canvas)

    string = begin
      Goishi::MQR::Decoder.decode_to_string(extracted_canvas)
    rescue e : Goishi::MQR::Decoder::VersionMismatchError
      location.version = e.actual_version
      extracted_canvas = extractor.extract(location)
      Goishi::MQR::Decoder.decode_to_string(extracted_canvas) rescue next
    rescue e
      extracted_canvas = extractor.extract(location)
      extracted_canvas.flip_tr_bl
      Goishi::MQR::Decoder.decode_to_string(extracted_canvas) rescue next
    end
    p! string

    break
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
