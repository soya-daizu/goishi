require "./locator/*"

module Goishi
  struct LocatorSession
    include QRLocator
    include MQRLocator
    include RMQRLocator

    @data : Canvas(UInt8)?
    @finder_quads : Array(Quad)

    def initialize
      @finder_quads = [] of Quad
    end

    private def data
      raise "Data not loaded" unless @data
      @data.not_nil!
    end

    def set_data(data : Canvas(UInt8))
      @data = data
      @finder_quads.clear

      LineScanner.scan_finder_pat(data).each do |sg|
        q = RayScanner.test_finder_pattern(data, sg.center, sg.color)
        @finder_quads.push(q) if q
      end

      # Visualizer.set_data(data)
      # @finder_quads.each do |q|
      #  Visualizer.add_line(q.a, q.b, "#ff00ff")
      #  Visualizer.add_line(q.c, q.d, "#ff00ff")
      #  Visualizer.add_line(q.a, q.c, "#ff00ff")
      #  Visualizer.add_line(q.b, q.d, "#ff00ff")
      #  Visualizer.add_point(q.center, "#ff00ff")
      #  Visualizer.add_point(q.a, "#ff0000")
      #  Visualizer.add_point(q.b, "#0000ff")
      #  Visualizer.add_point(q.c, "#00ff00")
      #  Visualizer.add_point(q.d, "#ffff00")
      # end
      # Visualizer.export
    end

    # Refine the bottom right point by finding an alignment pattern around the given starting point
    protected def refine_bottom_right(est_alignment : Point, unit : Int, color : UInt8)
      from = est_alignment - 5 * unit
      to = est_alignment + 5 * unit

      alignment_quads = [] of Quad
      LineScanner.scan_alignment_pat(data, from, to, color).each do |sg|
        q = RayScanner.test_alignment_pattern(data, sg.center, sg.color)
        alignment_quads.push(q) if q
      end

      alignment_quads.sort_by! do |q|
        (est_alignment - q.center).length
      end

      alignment_quads[0]?.try(&.center)
    end
  end
end
