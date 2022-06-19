require 'driving_physics/scalar_force'
require 'driving_physics/environment'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
puts env

mass = 1000           # kg
weight = mass * env.g # N
drive_force = 7000    # N
duration = 100        # seconds

puts format("Force: %d N  Mass: %d kg for %d seconds",
            drive_force, mass, duration)
CLI.pause

spd = 0.0 # m/s
pos = 0.0 # m
num_ticks = duration * env.hz + 1

flag = false
phase = :accelerate
paused = 0.0
start = Timer.now

num_ticks.times { |i|
  # TODO: make the resistance force negative
  net_force = drive_force + ScalarForce.all_resistance(spd, nf_mag: weight)

  acc = DrivingPhysics.acc(net_force, mass)
  spd += acc * env.tick
  pos += spd * env.tick

  if phase == :accelerate and spd.magnitude > 100
    flag = true
    phase = :coast
    drive_force = 0
  end

  if flag or (i % 1000 == 0)
    puts format("%d  %.3f m/s/s  %.2f m/s  %.1f m",
                i.to_f / env.hz, acc, spd, pos)
    if flag
      paused += CLI.pause
      flag = false
    end
  end
}

puts Timer.summary(start, num_ticks, paused)
