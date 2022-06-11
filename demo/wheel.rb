require 'driving_physics/wheel'

# drive force = (axle torque - inertia - friction) limited by traction

include DrivingPhysics

e = Environment.new
w = Wheel.new(e, mass: 25.0)

puts e
puts w

# 1000 kg car
# 4 tires
# 250 kg per tire plus tire mass

supported_mass = 1000 # kg
total_mass = supported_mass + 4 * w.mass
corner_mass = Rational(total_mass) / 4
normal_force = corner_mass * e.g
axle_torque = 1000 # N*m

puts [format("Corner mass: %d kg", corner_mass),
      format("Normal force: %.1f N", normal_force),
      format("Axle torque: %d Nm", axle_torque),
     ].join("\n")
puts

traction = w.traction(normal_force)
drive_force = w.force(axle_torque)
inertial_loss = w.inertial_loss(axle_torque, supported_mass)
net_axle_torque = axle_torque - inertial_loss
net_drive_force = w.force(net_axle_torque)
acc = DrivingPhysics.acc(net_drive_force, supported_mass)
alpha = acc / w.radius_m

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

(duration * e.hz).times { |i|
  # translational kinematics
  speed += acc * e.tick
  dist += speed * e.tick

  # rotational kinematics
  omega += alpha * e.tick
  theta += omega * e.tick

  if i < 10 or
    (i < 10_000 and i%1000 == 0) or
    (i % 10_000 == 0)
    puts DrivingPhysics.elapsed_display(i)
    puts format("%.1f r   %.2f r/s   %.3f r/s^2", theta, omega, alpha)
    puts format("%.1f m   %.2f m/s   %.3f m/s^2", dist, speed, acc)
    puts "Press [enter]"
    gets
  end
}
