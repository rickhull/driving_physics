require 'driving_physics/world'
require 'driving_physics/components'
require 'driving_physics/systems'
require 'driving_physics/disk'
require 'driving_physics/torque_curve'

# let's build an engine

include DrivingPhysics

# create world and reusable components / definitions
world = World.new

# create a crankshaft entity
crank_id = world.create_entity
world.add(crank_id, Disk.new(mass: 20, radius: 0.05, extent: 0.2))
world.add(crank_id, RotationState.new(0.0, 0.0))

# create a flywheel entity
fly_id = world.create_entity
world.add(fly_id, Disk.new(mass: 12, radius: 0.165, extent: 0.03))
world.add(fly_id, RotationState.new(0.0, 0.0))

# create the engine entity
engine = world.create_entity

# give it combustion power
tc = TorqueCurve.new
world.add(engine, CombustionPower.new(torque_curve: tc))
world.add(engine, CombustionState.new(rpm: 0, throttle: 0))

# give it a starter motor
world.add(engine, ElectricPower.new(torque: 25))
world.add(engine, ElectricState.new(throttle: 0))

# attach the crankshaft and flywheel to the engine
composition = EngineComposition.new(crankshaft: crank_id, flywheel: fly_id)
world.add(engine, composition)

# add systems; order matters
world.systems = [UserInputSystem.new,
                 StarterSystem.new,
                 CombustionSystem.new,
                 FrictionSystem.new,
                 IntegrationSystem.new]

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
  starter = world.get(engine, ElectricState)
  motor = world.get(engine, CombustionState)

  if starter.throttle > 0
    torque = world.get(engine, ElectricPower).torque * starter.throttle
  elsif motor.throttle > 0
    torque =
      world.get(engine, CombustionPower).torque_curve.torque(motor.rpm) *
      motor.throttle
  else
    torque = 0
  end

  puts format("Time: %.2f | Starter: %s | Throttle: %.3f | " +
              "Torque: %.3f Nm | RPM: %i",
              world.time,
              starter.throttle > 0 ? 'on' : 'off',
              motor.throttle,
              torque,
              motor.rpm)
end
