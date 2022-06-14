require 'driving_physics/motor'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)

puts motor

# spin up to 5000 RPM

alpha = motor.starter_alpha
omega = 0.0
theta = 0.0

duration = 20

status = :cold

(duration * env.hz + 1).times { |i|
  case status
  when :cold
    alpha = motor.starter_alpha(omega)
  when :running
    alpha = motor.rotating_friction(omega)
  else
    # dunno
  end

  omega += alpha * env.tick
  theta += omega * env.tick

  rpm = DrivingPhysics.rpm(omega)
  status = :running if rpm > motor.idle_rpm

  if i < 10 or
    (i < 100 and i % 10 == 0) or
    (i < 1000 and i % 100 == 0) or (i % 1000 == 0)
    puts DrivingPhysics.elapsed_display(i)
    puts format("%d RPM  %d Nm  Friction: %.1f Nm",
                DrivingPhysics.rpm(omega),
                motor.starter_torque,
                motor.rotating_friction(omega))
    puts format("%d rad  %.1f rad/s  %.1f rad/s/s", theta, omega, alpha)
    puts
  end
}
