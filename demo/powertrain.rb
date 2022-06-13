require 'driving_physics/powertrain'
require 'driving_physics/imperial'

include DrivingPhysics

motor = Motor.new(Environment.new)
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

pt = Powertrain.new(motor, Gearbox.new)
puts pt

# Run through the gears
1.upto(6) { |gear|
  pt.select_gear(gear)

  puts <<EOF

# GEAR #{gear} (#{pt.gearbox.ratio})
#
EOF

  800.upto(7000) { |rpm|
    next unless rpm % 500 == 0
    torque, omega = pt.output(rpm)
    speed = Disk.tangential(omega, 0.35)
    mph = Imperial.mph(speed)
    puts format("%d RPM:  %d Nm\t%.1f rad/s\t%.1f m/s (%d mph)",
                rpm, torque, omega, speed, mph)
  }
}
