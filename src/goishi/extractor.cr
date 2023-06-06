module Goishi
  struct Extractor
    @data : Canvas(UInt8)

    def initialize(@data)
    end

    def extract(location : QRLocation)
      # TODO: change dst_size based on the qr type
      # dst_size = 17 + location.version * 4
      dst_size = 9 + location.version * 2
      dst = Canvas(UInt8).new(dst_size, dst_size, 0_u8)

      transformer = get_transformer(location, dst_size)

      dst_size.times do |y|
        dst_size.times do |x|
          src_pixel = transformer.call(x + 0.5, y + 0.5)
          dst[x, y] = @data[src_pixel.x.to_i, src_pixel.y.to_i]? || 0_u8
        end
      end

      dst
    end

    private def get_transformer(location : QRLocation, dst_size : Int)
      q2s = quad_to_square(
        Point.new(location.offset[0], location.offset[0]),
        Point.new(dst_size - location.offset[1], location.offset[1]),
        Point.new(dst_size - location.offset[3], dst_size - location.offset[3]),
        Point.new(location.offset[2], dst_size - location.offset[2])
      )
      s2q = square_to_quad(
        location.top_left, location.top_right,
        location.bottom_right, location.bottom_left,
      )
      transform = times(s2q, q2s)

      ->(x : Float64, y : Float64) {
        denominator = transform.a13 * x + transform.a23 * y + transform.a33

        Point.new(
          ((transform.a11 * x + transform.a21 * y + transform.a31) / denominator).to_i,
          ((transform.a12 * x + transform.a22 * y + transform.a32) / denominator).to_i,
        )
      }
    end

    private def quad_to_square(p1 : Point, p2 : Point, p3 : Point, p4 : Point)
      s2q = square_to_quad(p1, p2, p3, p4)

      PerspectiveTransform.new(
        a11: s2q.a22 * s2q.a33 - s2q.a23 * s2q.a32,
        a12: s2q.a13 * s2q.a32 - s2q.a12 * s2q.a33,
        a13: s2q.a12 * s2q.a23 - s2q.a13 * s2q.a22,
        a21: s2q.a23 * s2q.a31 - s2q.a21 * s2q.a33,
        a22: s2q.a11 * s2q.a33 - s2q.a13 * s2q.a31,
        a23: s2q.a13 * s2q.a21 - s2q.a11 * s2q.a23,
        a31: s2q.a21 * s2q.a32 - s2q.a22 * s2q.a31,
        a32: s2q.a12 * s2q.a31 - s2q.a11 * s2q.a32,
        a33: s2q.a11 * s2q.a22 - s2q.a12 * s2q.a21,
      )
    end

    private def square_to_quad(p1 : Point, p2 : Point, p3 : Point, p4 : Point)
      dx3 = p1.x - p2.x + p3.x - p4.x
      dy3 = p1.y - p2.y + p3.y - p4.y

      if dx3 == 0 && dy3 == 0
        PerspectiveTransform.new(
          a11: p2.x - p1.x,
          a12: p2.y - p1.y,
          a13: 0,
          a21: p3.x - p2.x,
          a22: p3.y - p2.y,
          a23: 0,
          a31: p1.x,
          a32: p1.y,
          a33: 1,
        )
      else
        dx1 = p2.x - p3.x
        dx2 = p4.x - p3.x
        dy1 = p2.y - p3.y
        dy2 = p4.y - p3.y
        denominator = dx1 * dy2 - dx2 * dy1
        a13 = (dx3 * dy2 - dx2 * dy3) / denominator
        a23 = (dx1 * dy3 - dx3 * dy1) / denominator

        PerspectiveTransform.new(
          a11: p2.x - p1.x + a13 * p2.x,
          a12: p2.y - p1.y + a13 * p2.y,
          a13: a13,
          a21: p4.x - p1.x + a23 * p4.x,
          a22: p4.y - p1.y + a23 * p4.y,
          a23: a23,
          a31: p1.x,
          a32: p1.y,
          a33: 1,
        )
      end
    end

    private def times(a : PerspectiveTransform, b : PerspectiveTransform)
      PerspectiveTransform.new(
        a11: a.a11 * b.a11 + a.a21 * b.a12 + a.a31 * b.a13,
        a12: a.a12 * b.a11 + a.a22 * b.a12 + a.a32 * b.a13,
        a13: a.a13 * b.a11 + a.a23 * b.a12 + a.a33 * b.a13,
        a21: a.a11 * b.a21 + a.a21 * b.a22 + a.a31 * b.a23,
        a22: a.a12 * b.a21 + a.a22 * b.a22 + a.a32 * b.a23,
        a23: a.a13 * b.a21 + a.a23 * b.a22 + a.a33 * b.a23,
        a31: a.a11 * b.a31 + a.a21 * b.a32 + a.a31 * b.a33,
        a32: a.a12 * b.a31 + a.a22 * b.a32 + a.a32 * b.a33,
        a33: a.a13 * b.a31 + a.a23 * b.a32 + a.a33 * b.a33,
      )
    end

    struct PerspectiveTransform
      getter a11 : Float64
      getter a21 : Float64
      getter a31 : Float64
      getter a12 : Float64
      getter a22 : Float64
      getter a32 : Float64
      getter a13 : Float64
      getter a23 : Float64
      getter a33 : Float64

      def initialize(@a11, @a21, @a31, @a12, @a22, @a32, @a13, @a23, @a33)
      end
    end
  end
end
