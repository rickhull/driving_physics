require 'driving_physics/world'
require 'driving_physics/systems'

# let's build an engine

include DrivingPhysics
world = World.new

engine_id = world.create_entity
world.add(engine_id, CombustionEngine.new)
world.add(engine_id, VehicleControls.new)

# add systems; order matters
world.systems = [UserInputSystem.new,
                 CombustionEngineSystem.new]

# start the simulation
accumulator = Rational(0)
deadline = 1/10r # 0.1 seconds

while world.time < 10.0
  # how much wall time has elapsed?
  frame_time = world.sync

  # update the accumulator, with a safety cap
  accumulator += (frame_time < deadline ? frame_time : deadline)

  # drain the accumulator by running fixed-size physics steps
  while accumulator >= world.dt
    # run physics ticks
    world.update
    accumulator -= world.dt
  end

  # fake render
  sleep world.dt * (1 + rand(4))

  # actual render: print status report
  engine = world.get!(engine_id, CombustionEngine)
  controls = world.get!(engine_id, VehicleControls)
  
  puts format("Time: %.2f | Throttle: %.3f | " +
              "Torque: %.1f Nm | Net: %.1f Nm | RPM: %i",
              world.time,
              controls.throttle,
              engine.torque(controls.throttle),
              engine.net_torque(controls.throttle),
              engine.rpm)
end
