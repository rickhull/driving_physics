require 'driving_physics/disk'

module DrivingPhysics
  # Technically speaking, the gear ratio goes up with speed and down with
  # torque.  But in the automotive world, it's customary to invert the
  # relationship, where a bigger number means more torque and less speed.
  # We'll store the truth, where the default final drive would be
  # conventionally known as 3.73, but 1/3.73 will be stored.

  # The gear ratio (above 1) multiplies speed and divides torque
  # 5000 RPM is around 375 MPH with a standard wheel/tire
  # 3.73 final drive reduces that to around 100 mph in e.g. 5th gear (1.0)
  # Likewise, 1st gear is a _smaller_ gear ratio than 3rd
  class Gearbox
    class Disengaged < RuntimeError; end

    RATIOS = [1/5r, 2/5r, 5/9r, 5/7r, 1r, 5/4r]
    FINAL_DRIVE = 11/41r # 1/3.73

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

    def rotating_friction(omega)
      @spinner.rotating_friction(omega)
    end

    def implied_torque(alpha)
      @spinner.implied_torque(alpha)
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
      DrivingPhysics.omega(crank_rpm) * self.ratio
    end

    def crank_rpm(axle_omega)
      raise(Disengaged, "Cannot determine crank rpm") if @gear == 0
      DrivingPhysics.rpm(axle_omega) / self.ratio
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
