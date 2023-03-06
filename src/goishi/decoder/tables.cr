module Goishi
  struct Decoder
    macro make_version_bits
      {
        {% for ver in (7..40) %}
          {% rem = ver %}
          {% for _ in (0..11) %}
            {% rem = (rem << 1) ^ ((rem >> 11) * 0x1F25) %}
          {% end %}
          {{ ver << 12 | rem }},
        {% end %}
      }
    end

    macro make_format_bits
      {
        {% for ecl in ECC::Level.constants %}
          {% ecl_value = ECC::Level.constant(ecl) %}
          {% for mask in (0..7) %}
            {% data = 0_i32 + ecl_value << 3 | mask %}
            {% rem = data %}
            {% for _ in (0..9) %}
              {% rem = (rem << 1) ^ ((rem >> 9) * 0x537) %}
            {% end %}
            {% bits = (data << 10 | rem) ^ 0x5412 %}
            { {{bits}}, FormatInfo.new(ECC::Level::{{ecl}}, {{mask}}) },
          {% end %}
        {% end %}
      }
    end

    VERSION_BITS = make_version_bits
    FORMAT_BITS  = make_format_bits
  end
end
