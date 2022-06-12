require 'driving_physics/wheel'
require 'driving_physics/scalar_force'

module DrivingPhysics
  attr_reader :axle_torque

  class Powertrain
    def initialize(axle_torque)
      @axle_torque = axle_torque
    end
  end

  class Car
    attr_reader :wheel, :powertrain, :env
    attr_accessor :mass, :frontal_area, :cd, :num_wheels

    def initialize(wheel:, powertrain:)
      @num_wheels = 4
      @wheel = wheel
      @env = @wheel.env
      @powertrain = powertrain
      @mass = Rational(1000)
      @frontal_area = DrivingPhysics::FRONTAL_AREA
      @cd = DrivingPhysics::DRAG_COF

      yield self if block_given?
    end

    def to_s
      [[format("Mass: %.1f kg", self.total_mass),
        format("Axle Torque: %.1f Nm", @powertrain.axle_torque),
        format("Fr.A: %.2f m^2", @frontal_area),
        format("cD: %.2f", @cd),
       ].join(' | '),
       format("Wheels: %s", @wheel),
       format("Corner mass: %.1f kg | Normal force: %.1f N",
              self.corner_mass, self.normal_force),
      ].join("\n")
    end

    def total_mass
      @mass + @wheel.mass * @num_wheels
    end

    def corner_mass
      Rational(self.total_mass) / @num_wheels
    end

    # per wheel
    def normal_force
      self.corner_mass * @env.g
    end

    # per wheel
    def wheel_traction
      @wheel.traction(self.normal_force)
    end

    def total_normal_force
      self.total_mass * env.g
    end
  end
end
