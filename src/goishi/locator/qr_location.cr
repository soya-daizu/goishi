module Goishi
  struct QRLocation
    getter top_left : Point
    getter top_right : Point
    getter bottom_left : Point
    getter bottom_right : Point
    getter bottom_right_type : BottomRightType
    getter unit : Int32
    property version : Int32
    getter color : UInt8

    def initialize(
      @top_left, @top_right,
      @bottom_left, @bottom_right,
      @unit, @version, @color,
      @bottom_right_type
    )
    end

    enum BottomRightType : UInt8
      Intersection
      AlignmentPattern
    end
  end
end
