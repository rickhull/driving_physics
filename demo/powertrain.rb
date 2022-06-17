require 'driving_physics/powertrain'
require 'driving_physics/imperial'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)
gearbox = Gearbox.new(env)
powertrain = Powertrain.new(motor, gearbox)
puts env
puts powertrain
CLI.pause

crank_alpha = 0.0
crank_omega = 0.0

axle_alpha = 0.0
axle_omega = 0.0


# Run through the gears

1.upto(6) { |gear|
  powertrain.select_gear(gear)

  puts <<EOF

# GEAR #{gear} (#{powertrain.gearbox.ratio})
#
EOF

  800.upto(7000) { |rpm|
    next unless rpm % 500 == 0

    axle_torque = powertrain.axle_torque(rpm)
    mph = Imperial.mph(Disk.tangential(powertrain.axle_omega(rpm), 0.32))
    puts format("%d RPM:  %.1f Nm  %d mph", rpm, axle_torque, mph)
  }
}
