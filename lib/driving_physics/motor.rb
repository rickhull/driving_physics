require 'driving_physics/disk'

module DrivingPhysics
  class Motor
    class Stall < RuntimeError; end
    class OverRev < RuntimeError; end
    class SanityCheck < RuntimeError; end

    TORQUES = [  0,   20,  100,  150,  200,  250, 220,   200,  120,    0]
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]

    attr_reader :torques, :rpms, :rpm
    attr_accessor :fixed_mass, :flycrank, :starter_torque, :idle_rpm

    def initialize(env, torques: [], rpms: [])
      @env = env
      @fixed_mass = 50

      # represent all rotating mass as one big flywheel
      @flycrank = Disk.new(@env) { |fly|
        fly.mass   = 30    # kg
        fly.radius =  0.15 # m
        fly.base_friction = 5/1000r
        fly.omega_friction = 5/10_000r
      }

      @starter_torque = 10   # Nm
      @idle_rpm       = 1000 # RPM

      # validate torques and rpms
      if torques.empty? and rpms.empty?
        @torques = TORQUES
        @rpms = RPMS
      else
        raise(InputError, "torques.first should be 0") if torques.first != 0
        raise(InputError, "torques.last should be 0") if torques.last != 0
        if torques.length != rpms.length
          raise(InputError, format("mismatch: %s %s",
                                   torques.inspect,
                                   rpms.inspect))
        end
        if !torques.all? { |t| 0 <= t and t <= 999_999_999 }
          raise(InputError, torques.inspect)
        elsif !rpms.all? { |r| 0 <= r and r <= 999_999_999 }
          raise(InputError, rpms.inspect)
        end
        @torques = torques
        @rpms = rpms
      end
    end

    def to_s
      ary = ["Motor:"]
      @rpms.each_with_index { |r, i|
        ary << format("%s RPM %s Nm", r.to_s.rjust(5, ' '),
                      @torques[i].round(1).to_s.rjust(6, ' '))
      }
      ary.join("\n")
    end

    def mass
      @flycrank.mass + @fixed_mass
    end

    def starter_alpha(omega)
      @flycrank.alpha(@starter_torque + @flycrank.rotating_friction(omega))
    end

    def torque(rpm)
      raise(Stall, "RPM #{rpm}") if rpm < @rpms.first
      raise(OverRev, "RPM #{rpm}") if rpm > @rpms.last

      last_rpm = 99999
      last_tq = -1

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
  end
end
