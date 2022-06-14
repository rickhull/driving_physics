require 'driving_physics/gearbox'

include DrivingPhysics

env = Environment.new
gearbox = Gearbox.new(env)

# spin up at 6 rad/s/s

# just a target
alpha = 6.3
omega = 0.0
theta = 0.0

torque = 15

duration = 20

(duration * env.hz + 1).times { |i|
  friction = gearbox.spinner.rotating_friction(omega)
  net_torque = torque + friction
  alpha = gearbox.spinner.alpha(net_torque)
  omega += alpha * env.tick
  theta += omega * env.tick

  if i < 10 or
    (i < 100 and i % 10 == 0) or
    (i < 1000 and i % 100 == 0) or
    i % 1000 == 0
    puts DrivingPhysics.elapsed_display(i)
    puts format("RPM %d  Torque: %.3f Nm (%d Nm) Friction: %.3f Nm",
                DrivingPhysics.rpm(omega), net_torque, torque, friction)
    puts format("%.1f rad  %.1f rad/s  %.1f rad/s/s", theta, omega, alpha)
    puts
  end
}
