module Goishi
  struct QRLocation
    getter type : AbstractQR.class
    getter top_left : Point
    getter top_right : Point
    getter bottom_left : Point
    getter bottom_right : Point
    property version : Int32
    getter color : UInt8
    getter offset : Tuple(Float64, Float64, Float64, Float64)

    def initialize(
      @type,
      @top_left, @top_right, @bottom_left, @bottom_right,
      @version, @color, @offset
    )
    end
  end
end
