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

    def output(rpm, crank_a: 0, crank_o: 0, axle_a: 0, axle_o: 0)
      [self.axle_torque(rpm, crank_a: crank_a, crank_o: crank_o,
                        axle_a: axle_a, axle_o: axle_o),
       self.axle_omega(rpm)]
    end

    # convert rpm to axle torque, taking motor and gearbox losses into account
    def axle_torque(rpm, crank_a: 0, crank_o: 0, axle_a: 0, axle_o: 0)
      @motor.net_torque(rpm, alpha: crank_alpha) * @gearbox.ratio +
        @gearbox.resistance_torque(axle_a, axle_o)
    end

    def axle_omega(rpm)
      @gearbox.axle_omega(rpm)
    end

    def crank_rpm(axle_omega)
      @gearbox.crank_rpm(axle_omega)
    end
  end
end
