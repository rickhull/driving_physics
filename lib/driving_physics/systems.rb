require 'driving_physics/components'

module DrivingPhysics
  class UserInputSystem
    RPM_LOWER_BOUND = 500
    
    def update(world, dt)
      # We only care about the single engine we created.
      # A real game would query for a "PlayerControlled" component.
      world.query(CombustionEngine, VehicleControls).each { |id|
        engine = world.get!(id, CombustionEngine)
        controls = world.get!(id, VehicleControls)

        if engine.rpm.zero?
          # start it
          if controls.ignition
            controls.gear = Gearbox::NEUTRAL
            controls.clutch = 1.0
            controls.throttle = 0.0   # engine managment takes over from user
            controls.ignition = false
          end
        end
        
        # apply some throttle to wake up the engine and maintain idle
        time = world.time
        if time < 0.1
          if !controls.ignition
            controls.ignition = true
            controls.gear = 0
            controls.clutch = 1.0
            controls.throttle = 0.0
          end
        elsif time < 0.3
          # depress clutch, shift to first
          controls.clutch = 0.0
          controls.gear = 1
        else
          # release clutch, increase throttle
          # TODO: based on dt?
          if controls.clutch < 1.0
            # releasing clutch, increasing throttle
            controls.clutch += 0.1 if controls.clutch < 1.0
            controls.clutch = controls.clutch.clamp(0.0, 1.0)
            if controls.throttle < 1.0 and engine.rpm < 1000
              controls.throttle += 0.001
              controls.throttle = 1.0 if controls.throttle > 1.0
            end
          else
            # steady state, clutch is out
            controls.throttle -= 0.01 if engine.rpm > 1000
            controls.throttle += 0.01 if engine.rpm < 1000
            controls.throttle = controls.throttle.clamp(0.0, 1.0)
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
