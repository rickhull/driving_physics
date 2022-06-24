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
    class ClutchDisengage < Disengaged; end

    RATIOS = [1/5r, 2/5r, 5/9r, 5/7r, 1r, 5/4r]
    FINAL_DRIVE = 11/41r # 1/3.73
    CLUTCH_MIN = 0.25

    attr_accessor :gear, :clutch, :ratios, :final_drive, :spinner, :fixed_mass

    def initialize(env)
      @ratios = RATIOS
      @final_drive = FINAL_DRIVE
      @gear = 0     # neutral
      @clutch = 1.0 # fully engaged (clutch pedal out)

      # represent all rotating mass
      @spinner = Disk.new(env) { |m|
        m.radius = 0.15
        m.base_friction = 5.0/1000
        m.omega_friction = 15.0/100_000
        m.mass = 15
      }
      @fixed_mass = 30 # kg

      yield self if block_given?
    end

    # given torque, apply friction, determine alpha
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
      [self.inputs,
       format("Ratios: %s", @ratios.inspect),
       format(" Final: %s  Mass: %.1f kg  Rotating: %.1f kg",
              @final_drive.inspect, self.mass, @spinner.mass),
      ].join("\n")
    end

    def inputs
      format("Gear: %d  Clutch: %.1f%%", @gear, @clutch * 100)
    end

    def ratio(gear = nil)
      gear ||= @gear
      raise(Disengaged, "Cannot determine gear ratio") if @gear == 0
      @ratios.fetch(gear - 1) * @final_drive
    end

    def axle_torque(crank_torque)
      crank_torque * @clutch / self.ratio
    end

    def output_torque(crank_torque, crank_rpm, axle_omega: nil)
      axle_alpha = self.alpha(self.axle_torque(crank_torque),
                              omega: self.axle_omega(crank_rpm,
                                                     axle_omega: axle_omega))
      self.implied_torque(axle_alpha)
    end

    # take into account the old axle_omega and @clutch
    # warn on > 10% mismatch on omegas
    def axle_omega(crank_rpm, axle_omega: nil)
      new_axle_omega = DrivingPhysics.omega(crank_rpm) * self.ratio
      if axle_omega.nil?
        raise(ClutchDisengage, "cannot determine axle omega") if @clutch != 1.0
        return new_axle_omega
      end
      diff = new_axle_omega - axle_omega
      diff_pct = diff.to_f.abs / axle_omega

      @clutch = diff_pct > 0.1 ? [1.0 - diff_pct, CLUTCH_MIN].max : 1.0

      axle_omega + diff * @clutch
    end

    # take into account the old crank_rpm and @clutch
    # warn on > 30% RPM mismatch
    # crank will tolerate mismatch more than axle
    def crank_rpm(axle_omega, crank_rpm: nil)
      new_crank_rpm = DrivingPhysics.rpm(axle_omega) / self.ratio
      if crank_rpm.nil?
        raise(ClutchDisengage, "cannot determine crank rpm") if @clutch != 1.0
        return new_crank_rpm
      end
      crank_rpm + (new_crank_rpm - crank_rpm) * @clutch
    end

    def match_rpms(old_rpm, new_rpm)
      diff = new_rpm - old_rpm
      proportion = diff.to_f / old_rpm
      if proportion.abs < 0.01
        [:ok, proportion]
      elsif proportion.abs < 0.1
        @clutch = 0.9
        [:slip, proportion]
      elsif @gear == 1 and new_rpm < old_rpm and old_rpm <= 1500
        [:get_rolling, proportion]
      else
        @clutch = 1.0 - proportion.abs
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
