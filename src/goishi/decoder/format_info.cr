module Goishi
  struct Decoder
    enum ECC::Level : UInt8
      Low      = 0b01
      Medium   = 0b00
      Quartile = 0b11
      High     = 0b10
    end

    struct FormatInfo
      getter ec_level : ECC::Level
      getter mask : UInt8

      def initialize(@ec_level, @mask)
      end
    end
  end
end
