
include DrivingPhysics

env = Environment.new
tire = Tire.new(env)
puts env
puts tire
puts

duration = 100 # sec
axle_torque = 500 # N*m
supported_mass = 1500 # kg

puts "Given:"
puts "* #{axle_torque} Nm axle torque"
puts "* #{supported_mass} kg supported mass"
puts "* 4 tires"
puts "* #{duration} seconds"
puts

total_mass = supported_mass + 4 * tire.mass
corner_mass = Rational(total_mass) / 4
normal_force = corner_mass * env.g

puts "Therefore:"
puts format("* %.1f kg total mass",  total_mass)
puts format("* %.1f kg per corner",  corner_mass)
puts format("* %.1f N normal force", normal_force)
puts

traction = tire.traction(normal_force)
drive_force = tire.force(axle_torque)

puts "Tires:"
puts format("* %.1f N traction", traction)
puts format("* %.1f N drive force", drive_force)

CLI.pause

acc = 0.0   # meters/s/s
speed = 0.0 # meters/s
dist = 0.0  # meters

alpha = 0.0 # radians/s/s
omega = 0.0 # radians/s
theta = 0.0 # radians

start = Timer.now
paused = 0.0
num_ticks = duration * env.hz + 1

num_ticks.times { |i|
  torque = tire.net_tractable_torque(axle_torque,
                                     mass: total_mass,
                                     omega: omega,
                                     normal_force: normal_force)
  force = tire.force(torque)

  # translational kinematics
  acc = DrivingPhysics.acc(force, total_mass)
  speed += acc * env.tick
  dist += speed * env.tick
  mph = Imperial.mph(speed)

  # rotational kinematics
  alpha = acc / tire.radius
  omega += alpha * env.tick
  theta += omega * env.tick

  if i < 10 or
    (i < 20_000 and i%1000 == 0) or
    (i % 10_000 == 0)

    puts DrivingPhysics.elapsed_display(i)
    puts format("  Tire: %.1f r  %.2f r/s  %.3f r/s^2", theta, omega, alpha)
    puts format("   Car: %.1f m  %.2f m/s  %.3f m/s^2  (%d mph)",
                dist, speed, acc, mph)
    puts format("Torque: %.1f Nm (%d N)  Loss: %.1f%%",
                torque, force, (1.0 - torque / axle_torque) * 100)
    puts
  end
}

puts Timer.summary(start, num_ticks, paused)
