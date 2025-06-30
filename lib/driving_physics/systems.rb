require 'driving_physics/components'

module DrivingPhysics
  class UserInputSystem
    IDLE_THROTTLE = 0.05 # should maintain IDLE_RPM, slowly climb

    def update(world, dt)
      # We only care about the single engine we created.
      # A real game would query for a "PlayerControlled" component.
      world.query(VehicleControls).each { |id|
        # apply some throttle to wake up the engine and maintain idle
        controls = world.get!(id, VehicleControls)
        # controls.throttle = IDLE_THROTTLE

        time = world.time
        if time < 0.1
          controls.gear = 0     # neutral
          controls.clutch = 1.0 # fully engaged, clutch out
        elsif time < 1.0
          # depress clutch, shift to first
          controls.clutch = 0.0
          controls.gear = 1
        elsif time < 2.0
          # release clutch
          # TODO: based on dt?
          if controls.clutch <= 1.0
            controls.clutch += 0.1
            controls.clutch = 1.0 if controls.clutch > 1.0
            controls.throttle += 0.1
            controls.throttle = 1.0 if controls.throttle > 1.0
          end
        end
      }
    end
  end

  # apply torque to the crankshaft
  class CombustionEngineSystem
    IDLE_THROTTLE = 0.05
    
    def update(world, dt)
      world.query(CombustionEngine, VehicleControls).each { |id|
        engine = world.get!(id, CombustionEngine)
        controls = world.get!(id, VehicleControls)
        if controls.throttle > 0
          # user controls engine throttle
          engine.throttle = controls.throttle
        else
          # system controls engine throttle
          if engine.above_idle?
            engine.throttle = 0
          else
            engine.throttle = IDLE_THROTTLE
          end
        end
        engine.update(dt)
      }
    end
  end
end
