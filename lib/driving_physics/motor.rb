require 'driving_physics/disk'

module DrivingPhysics
  class Motor
    class Stall < RuntimeError; end
    class OverRev < RuntimeError; end
    class SanityCheck < RuntimeError; end

    TORQUES = [  0,   50,  130,  200,  250,  320,  320,  320,  260,    0]
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]

    attr_reader :env
    attr_accessor :torques, :rpms, :fixed_mass,
                  :spinner, :starter_torque, :idle_rpm

    def initialize(env)
      @env = env

      @torques = TORQUES
      @rpms = RPMS
      @fixed_mass = 125

      # represent all rotating mass as one big flywheel
      @spinner = Disk.new(@env) { |fly|
        fly.radius =  0.25 # m
        fly.mass   = 75    # kg
        fly.base_friction  = 5/1000r
        fly.omega_friction = 2/10_000r
      }
      @starter_torque = 500  # Nm
      @idle_rpm       = 1000 # RPM
    end

    def to_s
      ary = ["Torque:"]
      @rpms.each_with_index { |r, i|
        ary << format("%s Nm %s RPM",
                      @torques[i].round(1).to_s.rjust(4, ' '),
                      r.to_s.rjust(5, ' '))
      }
      ary << format("Mass: %.1f kg  Fixed: %d kg", self.mass, @fixed_mass)
      ary << format("Rotating: %s", @spinner)
      ary.join("\n")
    end

    def mass
      @spinner.mass + @fixed_mass
    end

    # given torque, determine crank alpha after inertia and friction
    def alpha(torque: nil, omega: 0)
      torque = @starter_torque if torque.nil?
      @spinner.alpha(torque + @spinner.rotating_friction(omega))
    end

    # How much torque is required to accelerate spinner up to alpha,
    # overcoming both inertia and friction
    # Presumably we have more input torque available, but this will be
    # used to do more work than just spinning up the motor
    #
    def resistance_torque(alpha, omega)
      # reverse sign on inertial_torque as it is not modeled as a resistance
      -1 * @spinner.inertial_torque(alpha) +
        @spinner.rotating_friction(omega)
    end

    # interpolate based on torque curve points
    def torque(rpm)
      raise(Stall, "RPM #{rpm}") if rpm < @rpms.first
      raise(OverRev, "RPM #{rpm}") if rpm > @rpms.last

      last_rpm = 99999
      last_tq = -1

      # ew; there must be a better way
      @rpms.each_with_index { |r, i|
        tq = @torques[i]
        if last_rpm <= rpm and rpm <= r
          proportion = Rational(rpm - last_rpm) / (r - last_rpm)
          return last_tq + (tq - last_tq) * proportion
        end
        last_rpm = r
        last_tq = tq
      }
      raise(SanityCheck, "RPM #{rpm}")
    end

    def net_torque(rpm, alpha: 0)
      torque(rpm) + resistance_torque(alpha, DrivingPhysics.omega(rpm))
    end
  end
end
