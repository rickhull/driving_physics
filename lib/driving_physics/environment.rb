require 'driving_physics'

module DrivingPhysics
  class Environment
    attr_reader :hz, :tick
    attr_accessor :g, :air_temp, :air_density, :petrol_density

    def initialize
      self.hz = HZ
      @g = G
      @air_temp = AIR_TEMP
      @air_density = AIR_DENSITY
      @petrol_density = PETROL_DENSITY
    end

    def hz=(int)
      @hz = int
      @tick = Rational(1) / @hz
    end

    def to_s
      [format("Tick: %d Hz", @hz),
       format("G: %.2f m/s^2", @g),
       format("Air: %.1f C %.2f kg/m^3", @air_temp, @air_density),
       format("Petrol: %.2f kg/L", @petrol_density),
      ].join(" | ")
    end
  end
end
