require "./locator/*"

module Goishi
  struct LocatorSession
    include QRLocator
    include MQRLocator

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
        q = RayScanner.test_finder_scangroup(data, sg)
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
  end
end
