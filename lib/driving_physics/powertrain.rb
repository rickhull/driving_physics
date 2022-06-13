require 'driving_physics/motor'
require 'driving_physics/gearbox'

module DrivingPhysics
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
      @gearbox.axle_omega(rpm)
    end

    def crank_rpm(axle_omega)
      @gearbox.crank_rpm(axle_omega)
    end
  end
end
