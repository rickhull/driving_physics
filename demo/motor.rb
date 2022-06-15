require 'driving_physics/motor'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)

puts motor

# spin up to 5000 RPM

alpha = 0.0
omega = 0.0
theta = 0.0

duration = 20

status = :cold

(duration * env.hz + 1).times { |i|
  # spin up the motor with starter_torque,
  # then let it spin down under friction
  torque = status == :cold ? motor.starter_torque : 0

  alpha = motor.alpha(torque: torque, omega: omega)
  omega += alpha * env.tick
  theta += omega * env.tick
  omega = 0 if omega < 0.00001

  rpm = DrivingPhysics.rpm(omega)
  if rpm > motor.idle_rpm
    status = :running
    flag = true
  end

  if flag or
    (i < 10) or
    (i < 100 and i % 10 == 0) or
    (i < 1000 and i % 100 == 0) or (i % 500 == 0)
    puts DrivingPhysics.elapsed_display(i)
    puts format("%d RPM  %d Nm  Friction: %.1f Nm",
                DrivingPhysics.rpm(omega),
                torque,
                motor.spinner.rotating_friction(omega))
    puts format("%d rad  %.1f rad/s  %.1f rad/s/s", theta, omega, alpha)
    puts
    flag = false
  end
}
