require 'driving_physics'

module DrivingPhysics
  class Environment
    attr_accessor :air_temp, :air_density, :petrol_density, :g

    def initialize
      @air_temp = AMBIENT_TEMP
      @air_density = DrivingPhysics::Force::AIR_DENSITY
      @petrol_density = PETROL_DENSITY
      @g = G
    end

    def to_s
      [format("G: %.2f m/s^2", @g),
       format("Air: %.2f C  %.4f kg/m^3", @air_temp, @air_density),
       format("Petrol: %.2f kg/L", @petrol_density),
      ].join(" | ")
    end
  end
end
