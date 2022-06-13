require 'driving_physics'
require 'driving_physics/environment'

module DrivingPhysics
  def self.omega(rpm)
    # (X Rev / min) * (min / 60 sec) * (2 PI rad / rev)
    # X * 2 PI rad / 60 sec
    # X * PI / 30 rad/sec
    rpm * Math::PI / 30
  end

  def self.rpm(omega)
    # (X rad / sec) * (60 sec / min) * (rev / 2 PI rad)
    # X * 60 / 2 PI rev / min
    # X * 30 / PI rev/min
    omega * 30 / Math::PI
  end

  class Motor
    class Stall < RuntimeError; end
    class OverRev < RuntimeError; end
    class SanityCheck < RuntimeError; end

    TORQUES = [  0,   20,  100,  150,  200,  250, 220,   200,  120,    0]
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]

    def initialize(env, torques: [], rpms: [])
      @env = env
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

  class Gearbox
    RATIOS = [18.0, 10.0, 7.0, 5.0, 4.0, 3.0]

    attr_reader :gear

    def initialize(*ratios)
      @ratios = ratios.empty? ? RATIOS : ratios
      @ratios.each { |r|
        raise(InputError, r.inspect) unless 0 < r and r < 99999
      }
      self.gear = 1
    end

    def to_s
      "Gearbox: #{@ratios.inspect}"
    end

    def gear=(val)
      raise("bad gear: #{val.inspect}") unless @ratios[val - 1]
      @gear = val
    end

    def ratio(gear = nil)
      self.gear = gear unless gear.nil?
      @ratios[@gear - 1]
    end

    def omega(rpm)
      DrivingPhysics.omega(rpm) / self.ratio
    end

    def rpm(omega)
      DrivingPhysics.rpm(omega) * self.ratio
    end
  end

  class Powertrain
    attr_reader :motor, :gearbox

    def initialize(motor, gearbox)
      @motor = motor
      @gearbox = gearbox
    end

    def to_s
      [@motor, @gearbox].join("\n")
    end

    def select_gear(gear)
      @gearbox.gear = gear
    end

    def output(rpm)
      [self.axle_torque(rpm), self.axle_omega(rpm)]
    end

    def axle_torque(rpm)
      @motor.torque(rpm) * @gearbox.ratio
    end

    def axle_omega(rpm)
      @gearbox.omega(rpm)
    end

    def rpm(axle_omega)
      @gearbox.rpm(axle_omega)
    end
  end
end
