require 'driving_physics/motor'
require 'driving_physics/cli'

# fun idea for a different demo: keep increasing torque until idle is
# maintained

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)
puts env
puts motor

puts "Rev it up!"
800.upto(7000) { |rpm|
  next unless rpm % 200 == 0
  tq = motor.torque(rpm).to_f
  puts format("%s RPM: %s Nm\t%s",
              rpm.to_s.rjust(4, ' '),
              tq.round(1).to_s.rjust(5, ' '),
              '#' * (tq.to_f / 10).round)
}

puts
puts "* Spin the motor up to #{motor.idle_rpm} RPM with the starter motor."
puts "* Rev it up with the throttle."
puts "* Let it die."
CLI.pause

alpha = 0.0
omega = 0.0
theta = 0.0

duration = 60

status = :ignition
rpm = 0

(duration * env.hz + 1).times { |i|
  # this is an input torque; alpha is determined after inertia and friction
  torque = case status
           when :ignition
             motor.starter_torque
           when :running
             motor.torque(rpm)
           else
             0
           end

  # Motor#alpha incorporates inertia and friction
  alpha = motor.alpha(torque, omega: omega)
  omega += alpha * env.tick
  theta += omega * env.tick

  net_torque = motor.implied_torque(alpha)

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
    (i < 1000 and i % 100 == 0) or
    (i < 10_000 and i % 500 == 0) or
    i % 5000 == 0
    puts DrivingPhysics.elapsed_display(i)
    puts format("%d RPM  %.1f Nm (%d Nm)  Friction: %.1f Nm",
                DrivingPhysics.rpm(omega),
                net_torque,
                torque,
                motor.spinner.rotating_friction(omega))
    puts format("%d rad  %.1f rad/s  %.1f rad/s/s", theta, omega, alpha)
    puts

    CLI.pause if flag
    flag = false
  end
}
