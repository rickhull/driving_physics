require 'driving_physics/motor'
require 'driving_physics/cli'
require 'driving_physics/power'

# fun idea for a different demo: keep increasing torque until idle is
# maintained

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)
puts env
puts motor
puts

puts "Rev it up!"
[:torque, :power].each { |run|
  puts
  puts run.to_s.upcase + ':'

  800.upto(7000) { |rpm|
    next unless rpm % 200 == 0
    omega = DrivingPhysics.omega(rpm)
    torque = motor.torque(rpm)
    case run
    when :torque
      count = (torque.to_f / 10).round
      char = 'T'
      val = torque.round.to_s.rjust(5, ' ')
      fmt = "%s Nm"
    when :power
      power = DrivingPhysics.power(torque, omega)
      kw = power.to_f / 1000
      count = (kw / 5).round
      char = 'P'
      val = kw.round(1).to_s.rjust(5, ' ')
      fmt = "%s kW"
    else
      raise "unknown"
    end
    puts format("%s RPM: #{fmt}\t%s",
                rpm.to_s.rjust(4, ' '),
                val,
                char * count)
  }
}

puts
puts "Now, the simulation begins..."
puts "---"
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

  power = DrivingPhysics.power(net_torque, omega)

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
    puts format("%d RPM  %.1f Nm (%d Nm)  %.1f kW   Friction: %.1f Nm",
                DrivingPhysics.rpm(omega),
                net_torque,
                torque,
                power / 1000,
                motor.spinner.rotating_friction(omega))
    puts format("%d rad  %.1f rad/s  %.1f rad/s/s", theta, omega, alpha)
    puts

    CLI.pause if flag
    flag = false
  end
}
