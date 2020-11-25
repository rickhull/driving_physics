require 'driving_physics'

module DrivingPhysics
  class Environment
    attr_accessor :air_temp, :air_density, :petrol_density, :g
    attr_reader :tick, :ticks_per_sec

    def initialize
      @air_temp = AMBIENT_TEMP
      @air_density = DrivingPhysics::Force::AIR_DENSITY
      @petrol_density = PETROL_DENSITY
      @g = G
      self.ticks_per_sec = TICKS_PER_SEC
    end

    def ticks_per_sec=(tps)
      @ticks_per_sec = tps
      @tick = 1.to_f / @ticks_per_sec
    end

    def to_s
      [format("Tick: %d Hz", @ticks_per_sec),
       format("G: %.2f m/s^2", @g),
       format("Air: %.1f C %.2f kg/m^3", @air_temp, @air_density),
       format("Petrol: %.2f kg/L", @petrol_density),
      ].join(" | ")
    end
  end
end
