require 'driving_physics/wheel'

include DrivingPhysics

e = Environment.new
w = Wheel.new(e, mass: 25.0)

puts e
puts w


# 1000 kg car
# 4 tires
# 250 kg per tire plus tire mass

supported_mass = 1000 # kg
corner_mass = supported_mass.to_f / 4
normal_force = (corner_mass + w.mass) * e.g
axle_torque = 1000 # N*m

puts [format("Corner mass: %d kg", corner_mass),
      format("Normal force: %.1f N", normal_force),
      format("Axle torque: %d Nm", axle_torque),
     ].join("\n")

puts

puts [format("Traction: %.1f N", w.traction(normal_force)),
      format("Drive force: %.1f N", w.force(axle_torque)),
      format("Max torque: %.1f Nm", w.max_torque(normal_force)),
     ].join("\n")

duration = 100 # sec

theta = 0.0
omega = 0.0
alpha = 0.0

dist = 0.0
speed = 0.0
acc = 0.0

(duration * e.hz).times { |i|
  alpha = Wheel.alpha(axle_torque, w.inertia)
  omega += alpha * e.tick
  theta += omega * e.tick

  w.omega = omega
  speed = w.surface_v
  dist += speed * e.tick
  acc = 2 * w.radius

  if i < 10 or
    (i < 10_000 and i%1000 == 0) or
    (i % 10_000 == 0)
    puts DrivingPhysics.elapsed_display(i)
    puts format("%.3f r %.3f r/s %.3f r/s^2", theta, omega, alpha)
    puts format("%.3f m %.3f m/2 %.3f m/s^2", dist, speed, acc)
    puts "Press [enter]"
    gets
  end
}
