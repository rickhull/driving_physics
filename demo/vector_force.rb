require 'driving_physics/vector_force'
require 'driving_physics/environment'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
puts env

mass = 1000           # kg
weight = mass * env.g # N
drive_force = DrivingPhysics.random_unit_vector * 7000 # N
duration = 100        # seconds

puts format("Force: %d N  Dir: %s",
            drive_force.magnitude,
            DrivingPhysics.compass_dir(drive_force.normalize))
puts format("Mass: %d kg for %d seconds", mass, duration)
CLI.pause

acc = Vector[0, 0] # m/s/s
vel = Vector[0, 0] # m/s
pos = Vector[0, 0] # m

num_ticks = duration * env.hz + 1

flag = false
phase = :accelerate
paused = 0.0
start = Timer.now

num_ticks.times { |i|
  net_force = drive_force +
              VectorForce.all_resistance(vel, dir: vel, nf_mag: weight)

  acc = DrivingPhysics.acc(net_force, mass)
  vel += acc * env.tick
  pos += vel * env.tick

  if phase == :accelerate and vel.magnitude > 100
    flag = true
    phase = :coast
    drive_force = Vector[0, 0]
  end

  if flag or (i % 1000 == 0)
    puts format("%d  %.3f m/s/s  %.2f m/s  %.1f m",
                i.to_f / env.hz, acc.magnitude, vel.magnitude, pos.magnitude)
    if flag
      paused = CLI.pause
      flag = false
    end
  end
}

puts Timer.summary(start, num_ticks, paused)
