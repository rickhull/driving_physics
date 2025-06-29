module DrivingPhysics
  class FrictionModel < Data.define(:static, :kinetic, :viscous)
    def initialize(static: 2, kinetic: 1, viscous: 0.001)
      super
    end

    # applied can be linear (force) or rotational (torque)
    # vel can be linear or rotational (omega)
    # returns a signed quantity, either force or torque
    def friction(applied, vel)
      if vel.zero?
        # static friction cannnot overwhelm applied torque/force
        applied.clamp(-static, static)
      else
        # kinetic friction opposes vel direction (sign)
        (kinetic + viscous * vel.abs) * (vel <=> 0)
      end * -1
    end
  end
end
