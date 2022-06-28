require 'driving_physics/motor'
require 'driving_physics/gearbox'

module DrivingPhysics
  # Powertrain right now is pretty simple.  It combines the motor with the
  # gearbox.  It is focused on operations that require or involve both
  # components. It does not pass through operations to the motor or gearbox.
  # Instead, it provides direct access to each component.
  #
  class Powertrain
    attr_reader :motor, :gearbox

    def initialize(motor:, gearbox:)
      @motor = motor
      @gearbox = gearbox
    end

    def mass
      @motor.mass + @gearbox.mass
    end

    def to_s
      ["\t[MOTOR]", @motor, "\t[GEARBOX]", @gearbox].join("\n")
    end

    # returns [power, torque, omega]
    def output(rpm)
      t, o = self.axle_torque(rpm), self.axle_omega(rpm)
      [t * o, t, o]
    end

    def axle_torque(rpm, axle_omega: nil)
      @gearbox.output_torque(@motor.output_torque(rpm), rpm,
                             axle_omega: axle_omega)
    end

    def axle_omega(rpm, axle_omega: nil)
      @gearbox.axle_omega(rpm, axle_omega: axle_omega)
    end

    def crank_rpm(axle_omega, crank_rpm: nil)
      @gearbox.crank_rpm(axle_omega, crank_rpm: crank_rpm)
    end
  end
end
