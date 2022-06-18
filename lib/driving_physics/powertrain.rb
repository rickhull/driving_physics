require 'driving_physics/motor'
require 'driving_physics/gearbox'

module DrivingPhysics
  # Powertrain right now is pretty simple.  It combines the motor with
  # the gearbox.

  class Powertrain
    attr_reader :motor, :gearbox

    def initialize(motor, gearbox)
      @motor = motor
      @gearbox = gearbox
    end

    def to_s
      ["\t[MOTOR]", @motor, "\t[GEARBOX]", @gearbox].join("\n")
    end

    def select_gear(gear)
      @gearbox.gear = gear
    end

    # power, torque, omega
    def output(rpm)
      t, o = self.axle_torque(rpm), self.axle_omega(rpm)
      [t * o, t, o]
    end

    def axle_torque(rpm)
      crank_alpha = @motor.alpha(@motor.torque(rpm),
                                 omega: DrivingPhysics.omega(rpm))
      crank_torque = @motor.implied_torque(crank_alpha)

      axle_alpha = @gearbox.alpha(@gearbox.axle_torque(crank_torque),
                                  omega: @gearbox.axle_omega(rpm))
      @gearbox.implied_torque(axle_alpha)
    end

    def axle_omega(rpm)
      @gearbox.axle_omega(rpm)
    end

    def crank_rpm(axle_omega)
      @gearbox.crank_rpm(axle_omega)
    end
  end
end
