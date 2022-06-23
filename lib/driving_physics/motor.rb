require 'driving_physics/disk'

module DrivingPhysics
  class Motor
    class Stall < RuntimeError; end
    class OverRev < RuntimeError; end
    class SanityCheck < RuntimeError; end

    TORQUES = [  0,   70,  130,  200,  250,  320,  330,  320,  260,    0]
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]
    ENGINE_BRAKING = 0.2 # 20% of the torque at a given RPM

    attr_reader :env, :throttle
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
        fly.base_friction  = 5.0/1000
        fly.omega_friction = 2.0/10_000
      }
      @starter_torque = 500  # Nm
      @idle_rpm       = 1000 # RPM
      @throttle       = 0.0  # 0.0 - 1.0 (0% - 100%)
    end

    def to_s
      ary = [format("Throttle: %.1f%%", @throttle * 100)]
      ary << "Torque:"
      @rpms.each_with_index { |r, i|
        ary << format("%s Nm %s RPM",
                      @torques[i].round(1).to_s.rjust(4, ' '),
                      r.to_s.rjust(5, ' '))
      }
      ary << format("Mass: %.1f kg  Fixed: %d kg", self.mass, @fixed_mass)
      ary << format("Rotating: %s", @spinner)
      ary.join("\n")
    end

    def rotational_inertia
      @spinner.rotational_inertia
    end

    def mass
      @spinner.mass + @fixed_mass
    end

    def throttle=(val)
      if val < 0.0 or val > 1.0
        raise(ArgumentError, "val #{val.inspect} should be between 0 and 1")
      end
      @throttle = val
    end

    # given torque, determine crank alpha after inertia and friction
    def alpha(torque, omega: 0)
      @spinner.alpha(torque + @spinner.rotating_friction(omega))
    end

    def implied_torque(alpha)
      @spinner.implied_torque(alpha)
    end

    # interpolate based on torque curve points
    def torque(rpm)
      raise(Stall, "RPM #{rpm}") if rpm < @rpms.first
      raise(OverRev, "RPM #{rpm}") if rpm > @rpms.last

      last_rpm, last_tq, torque = 99999, -1, nil

      @rpms.each_with_index { |r, i|
        tq = @torques[i]
        if last_rpm <= rpm and rpm <= r
          proportion = Rational(rpm - last_rpm) / (r - last_rpm)
          torque = last_tq + (tq - last_tq) * proportion
          break
        end
        last_rpm, last_tq = r, tq
      }
      raise(SanityCheck, "RPM #{rpm}") if torque.nil?

      if (@throttle <= 0.05) and (rpm > @idle_rpm * 1.5)
        # engine braking: 20% of torque
        -1 * torque * ENGINE_BRAKING
      else
        torque * @throttle
      end
    end
  end
end


# TODO: starter motor
# Starter motor is power limited, not torque limited
# Consider:
# * 2.2 kW (3.75:1 gear reduction)
# * 1.8 kW  (4.4:1 gear reduction)
# On a workbench, a starter will draw 80 to 90 amps. However, during actual
# start-up of an engine, a starter will draw 250 to 350 amps.
# from https://www.motortrend.com/how-to/because-theres-more-to-a-starter-than-you-realize/

# V - Potential, voltage
# I - Current, amperage
# R - Resistance, ohms
# P - Power, wattage

# Ohm's law: I = V / R (where R is held constant)
# P = I * V
# For resistors (where R is helod constant)
#   = I^2 * R
#   = V^2 / R


# torque proportional to A
# speed proportional to V


# batteries are rated in terms of CCA - cold cranking amps

# P = I * V
# V = 12 (up to 14ish)
# I = 300
# P = 3600 or 3.6 kW


# A starter rated at e.g. 2.2 kW will use more power on initial cranking
# Sometimes up to 500 amperes are required, and some batteries will provide
# over 600 cold cranking amps


# Consider:

# V = 12
# R = resistance of battery, wiring, starter motor
# L = inductance (approx 0)
# I = current through motor
# Vc = proportional to omega

# rated power - Vc * I
# input power - V * I
# input power that is unable to be converted to output power is wasted as heat
