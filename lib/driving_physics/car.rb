require 'driving_physics/tire'
require 'driving_physics/powertrain'

module DrivingPhysics
  class Car
    attr_reader :tire, :powertrain, :env
    attr_accessor :num_tires, :mass, :frontal_area, :cd

    def initialize(tire:, powertrain:)
      @num_tires = 4
      @tire = tire
      @env = @tire.env
      @powertrain = powertrain
      @mass = Rational(1000)
      @frontal_area = DrivingPhysics::FRONTAL_AREA
      @cd = DrivingPhysics::DRAG_COF

      yield self if block_given?
    end

    # force opposing speed
    def air_resistance(speed)
      -0.5 * @frontal_area * @cd * @env.air_density * speed ** 2
    end

    # force of opposite sign to omega
    def rolling_resistance(omega)
      @num_tires *
        @tire.rolling_friction(omega, normal_force: self.normal_force) /
        @tire.radius
    end

    # force of opposite sign to omega
    def rotational_resistance(omega)
      @num_tires *
        @tire.rotating_friction(omega, normal_force: self.normal_force) /
        @tire.radius
    end

    # force of opposite sign to force
    def inertial_resistance(force)
      mag = force.abs
      sign = force / mag
      force_loss = 0
      5.times {
        # use magnitude, so we are subtracting only positive numbers
        acc = DrivingPhysics.acc(mag - force_loss, self.total_mass)
        alpha = acc / @tire.radius
        # this will be a positive number
        force_loss = @num_tires * @tire.inertial_torque(alpha) /
                     @tire.radius
      }
      # oppose initial force
      -1 * sign * force_loss
    end

    def to_s
      [[format("Mass: %.1f kg", self.total_mass),
        format("Fr.A: %.2f m^2", @frontal_area),
        format("cD: %.2f", @cd),
       ].join(' | '),
       format("Powertrain: %s", @powertrain),
       format("Tires: %s", @tire),
       format("Corner mass: %.1f kg | Normal force: %.1f N",
              self.corner_mass, self.normal_force),
      ].join("\n")
    end

    def drive_force(rpm)
      @tire.force(@powertrain.axle_torque(rpm))
    end

    def tire_speed(rpm)
      @tire.tangential(@powertrain.axle_omega(rpm))
    end

    def rpm(tire_speed)
      @tire.foo
    end

    def total_mass
      @mass + @tire.mass * @num_tires
    end

    def corner_mass
      Rational(self.total_mass) / @num_tires
    end

    # per tire
    def normal_force
      self.corner_mass * @env.g
    end

    # per tire
    def tire_traction
      @tire.traction(self.normal_force)
    end

    def total_normal_force
      self.total_mass * env.g
    end
  end
end
