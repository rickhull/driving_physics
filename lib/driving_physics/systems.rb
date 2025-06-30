require 'driving_physics/components'

module DrivingPhysics
  class UserInputSystem
    IDLE_THROTTLE = 0.05 # should maintain IDLE_RPM, slowly climb

    def update(world, dt)
      # We only care about the single engine we created.
      # A real game would query for a "PlayerControlled" component.
      world.query(CombustionEngine, VehicleControls).each { |id|
        engine = world.get!(id, CombustionEngine)
        controls = world.get!(id, VehicleControls)
        controls.throttle = IDLE_THROTTLE
      }
    end
  end

  # apply torque to the crankshaft
  class CombustionEngineSystem
    def update(world, dt)
      world.query(CombustionEngine, VehicleControls).each { |id|
        engine = world.get!(id, CombustionEngine)
        controls = world.get!(id, VehicleControls)
        engine.update(controls.throttle, dt)
      }
    end
  end
end
