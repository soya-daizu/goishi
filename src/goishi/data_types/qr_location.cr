module Goishi
  struct QRLocation
    getter top_left : Point
    getter top_right : Point
    getter bottom_left : Point
    getter bottom_right : Point
    getter bottom_right_type : BottomRightType
    getter unit : Int32
    getter version : Int32

    def initialize(
      @top_left, @top_right,
      @bottom_left, @bottom_right,
      @unit, @version, @bottom_right_type
    )
    end

    enum BottomRightType : UInt8
      Intersection
      AlignmentPattern
    end
  end
end
