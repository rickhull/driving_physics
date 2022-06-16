require 'driving_physics/disk'

module DrivingPhysics
  class Gearbox
    class Disengaged < RuntimeError; end

    RATIOS = [5r, 5/2r, 9/5r, 7/5r, 1r, 4/5r]
    REAR_END = 41/11r # 3.73

    attr_accessor :gear, :ratios, :rear_end, :spinner, :fixed_mass

    def initialize(env)
      @ratios = RATIOS
      @rear_end = REAR_END
      @gear = 0 # neutral

      # represent all rotating mass
      @spinner = Disk.new(env) { |m|
        m.mass = 15
        m.radius = 0.15
        m.base_friction = 5/1000r
        m.omega_friction = 5/10_000r
      }
      @fixed_mass = 30 # kg

      yield self if block_given?
    end

    # given torque, determine crank alpha after inertia and friction
    def alpha(torque, omega: 0)
      @spinner.alpha(torque + @spinner.rotating_friction(omega))
    end


    def resistance_torque(alpha, omega)
      -1 * @spinner.inertial_torque(alpha) +
        @spinner.rotating_friction(omega)
    end

    def mass
      @fixed_mass + @spinner.mass
    end

    def top_gear
      @ratios.length
    end

    def to_s
      [format("Ratios: %s", @ratios.inspect),
       format(" Final: %s  Mass: %.1f kg  Rotating: %.1f kg",
              @rear_end.inspect, self.mass, @spinner.mass),
      ].join("\n")
    end

    def ratio(gear = nil)
      gear ||= @gear
      return 0 if gear == 0
      @ratios.fetch(gear - 1) * @rear_end
    end

    def axle_omega(crank_rpm)
      raise(Disengaged, "Cannot determine axle omega") if @gear == 0
      DrivingPhysics.omega(crank_rpm) / self.ratio
    end

    def crank_rpm(axle_omega)
      raise(Disengaged, "Cannot determine crank rpm") if @gear == 0
      DrivingPhysics.rpm(axle_omega) * self.ratio
    end

    def match_rpms(old_rpm, new_rpm)
      diff = new_rpm - old_rpm
      proportion = diff.to_f / old_rpm
      if proportion.abs < 0.01
        [:ok, proportion]
      elsif proportion.abs < 0.1
        [:slip, proportion]
      elsif @gear == 1 and new_rpm < old_rpm and old_rpm <= 1500
        [:get_rolling, proportion]
      else
        [:mismatch, proportion]
      end
    end

    def next_gear(rpm, floor: 2500, ceiling: 6400)
      if rpm < floor and @gear > 1
        @gear - 1
      elsif rpm > ceiling and @gear < self.top_gear
        @gear + 1
      else
        @gear
      end
    end
  end
end
