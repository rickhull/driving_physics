
module DrivingPhysics
  # Powertrain right now is pretty simple.  It combines the motor with the
  # gearbox.  It is focused on operations that require or involve both
  # components. It does not pass through operations to the motor or gearbox.
  # Instead, it provides direct access to each component.
  #
  class Powertrain
    attr_reader :motor, :gearbox

    def initialize(motor, gearbox)
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
