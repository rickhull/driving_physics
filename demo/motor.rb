require 'driving_physics/motor'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)

# fun idea for a different demo: keep increasing torque until idle is
# maintained

puts motor
puts
puts "Spin the motor up to #{motor.idle_rpm} RPM with the starter motor."
puts "Then rev it up with the throttle."
puts "Then let it die."
CLI.pause

alpha = 0.0
omega = 0.0
theta = 0.0

duration = 20

status = :ignition
rpm = 0

(duration * env.hz + 1).times { |i|
  # spin up the motor with starter_torque,
  # then let it spin down under friction
  torque = case status
           when :ignition
             motor.starter_torque
           when :running
             motor.torque(rpm)
           else
             0
           end

  alpha = motor.alpha(torque: torque, omega: omega)
  omega += alpha * env.tick
  theta += omega * env.tick

  # prevent silly oscillations due to tiny floating point errors
  omega = 0 if omega < 0.00001
  rpm = DrivingPhysics.rpm(omega)

  if rpm > motor.idle_rpm and status == :ignition
    status = :running
    flag = true
  end

  if rpm > 7000 and status == :running
    status = :off
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
