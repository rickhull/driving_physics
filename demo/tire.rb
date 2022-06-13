require 'driving_physics/tire'

include DrivingPhysics

env = Environment.new
tire = Tire.new(env)

puts env
puts tire

# 1000 kg car
# 4 tires
# 250 kg per tire plus tire mass

supported_mass = 1000 # kg
total_mass = supported_mass + 4 * tire.mass
corner_mass = Rational(total_mass) / 4
normal_force = corner_mass * env.g
axle_torque = 1000 # N*m

puts [format("Corner mass: %d kg", corner_mass),
      format("Normal force: %.1f N", normal_force),
      format("Axle torque: %d Nm", axle_torque),
     ].join("\n")
puts

traction = tire.traction(normal_force)
drive_force = tire.force(axle_torque)
inertial_loss = tire.inertial_loss(axle_torque, driven_mass: supported_mass)
net_axle_torque = axle_torque - inertial_loss
net_drive_force = tire.force(net_axle_torque)
acc = DrivingPhysics.acc(net_drive_force, supported_mass) # translational
alpha = acc / tire.radius

puts [format("Traction: %.1f N", traction),
      format("Drive force: %.1f N", drive_force),
      format("Inertial loss: %.1f Nm", inertial_loss),
      format("Net Axle Torque: %.1f Nm", net_axle_torque),
      format("Net Drive Force: %.1f N", net_drive_force),
      format("Acceleration: %.1f m/s/s", acc),
      format("Alpha: %.2f r/s/s", alpha),
     ].join("\n")
puts

duration = 100 # sec

dist = 0.0  # meters
speed = 0.0 # meters/s

theta = 0.0 # radians
omega = 0.0 # radians/s

t = Time.now
num_ticks = duration * env.hz

num_ticks.times { |i|
  torque = tire.net_tractable_torque(axle_torque,
                                      mass: total_mass,
                                      omega: omega,
                                      normal_force: normal_force)
  force = tire.force(torque)

  # translational kinematics
  acc = DrivingPhysics.acc(force, supported_mass)
  speed += acc * env.tick
  dist += speed * env.tick

  # rotational kinematics
  alpha = acc / tire.radius
  omega += alpha * env.tick
  theta += omega * env.tick

  if i < 10 or
    (i < 20_000 and i%1000 == 0) or
    (i % 10_000 == 0) or
    i == duration * env.hz - 1

    puts DrivingPhysics.elapsed_display(i)
    puts format("  Tire: %.1f r  %.2f r/s  %.3f r/s^2", theta, omega, alpha)
    puts format("   Car: %.1f m  %.2f m/s  %.3f m/s^2", dist, speed, acc)
    puts format("Torque: %.1f Nm (%d N)  Loss: %.1f%%",
                torque, force, (1.0 - torque / axle_torque) * 100)
    puts
  end
}

elapsed = Time.now - t
puts format("%.2f s (%d ticks / s)", elapsed, num_ticks / elapsed)