require 'driving_physics/vector_force'
require 'driving_physics/environment'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new

mass = 1000           # kg
weight = mass * env.g # N
drive_force = DrivingPhysics.random_unit_vector * 7000 # N
duration = 100        # seconds
num_ticks = duration * env.hz + 1

pos = Vector[0, 0]      # m
vel = Vector[0, 0]      # m/s

flag = false
phase = :accelerate

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
      CLI.pause
      flag = false
    end
  end
}
