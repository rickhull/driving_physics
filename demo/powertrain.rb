require 'driving_physics/powertrain'
require 'driving_physics/imperial'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)
gearbox = Gearbox.new(env)
pt = Powertrain.new(motor, gearbox)
puts env
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
