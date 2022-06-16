require 'driving_physics/gearbox'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
gearbox = Gearbox.new(env)
puts env
puts gearbox
puts
puts "Spin up the gearbox with 15 Nm of input torque"
puts "How fast will it go?"
CLI.pause

# rotational kinematics
alpha = 0.0
omega = 0.0
theta = 0.0

torque = 15
duration = 20

(duration * env.hz + 1).times { |i|
  # just for info, not used in the simulation
  friction = gearbox.spinner.rotating_friction(omega)
  net_torque = torque + gearbox.resistance_torque(alpha, omega)

  # update rotational kinematics
  # gearbox.alpha incorporates friction and inertia
  alpha = gearbox.alpha(torque, omega: omega)
  omega += alpha * env.tick
  theta += omega * env.tick

  # periodic output
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
