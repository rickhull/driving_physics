require 'driving_physics/disk'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
disk = Disk.new(env)

puts env
puts disk
puts

axle_torque = 50
alpha = disk.alpha(axle_torque)
drive_force = disk.force(axle_torque)

puts [format("Axle torque: %.1f Nm", axle_torque),
      format("      Alpha: %.1f rad/s/s", alpha),
      format("Drive force: %.1f N", drive_force),
     ].join("\n")
puts

puts "* Spin up the disk with #{axle_torque} Nm of torque"
puts "* Cut the power at some point"
puts "* Observe"
CLI.pause

duration = 750 # sec

dist = 0.0  # meters
speed = 0.0 # meters/s

theta = 0.0 # radians
omega = 0.0 # radians/s

paused = 0.0 # seconds
num_ticks = duration * env.hz + 1
flag = false # to display current stats
start = Timer.now

num_ticks.times { |i|
  # shut off the powah!
  if i == 18_950
    flag = true
    puts '#'
    puts '# CUT POWER'
    puts '#'
    puts
    axle_torque = 0
  end

  rotating_friction = disk.rotating_friction(omega)
  net_torque = axle_torque + rotating_friction
  net_force = disk.force(net_torque)

  # rotational kinematics
  alpha = disk.alpha(net_torque)
  omega += alpha * env.tick
  omega = 0.0 if omega.abs < 0.0001
  theta += omega * env.tick

  if flag or i < 10 or
    (i < 20_000 and i%1000 == 0) or
    (i % 10_000 == 0) or
    i == duration * env.hz - 1

    puts Timer.display(ms: i)
    puts format(" Torque: %.1f Nm (%d Nm)  Friction: %.1f Nm",
                net_torque, axle_torque, rotating_friction)
    puts format("Radians: %.1f r  %.2f r/s  %.3f r/s^2", theta, omega, alpha)
    puts format("   Revs: %d revs  %d revs/s  %d rpm",
                DrivingPhysics.revs(theta),
                DrivingPhysics.revs(omega),
                DrivingPhysics.rpm(omega))
    puts
    if flag
      paused += CLI.pause
      flag = false
    end
  end
}

puts Timer.summary(start, num_ticks, paused)
