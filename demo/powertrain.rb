require 'driving_physics/powertrain'
require 'driving_physics/imperial'
require 'driving_physics/cli'
require 'driving_physics/power'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)
motor.throttle = 1.0
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
  powertrain.gear = gear

  puts <<EOF

# GEAR #{gear} (#{powertrain.gearbox.ratio})
#
EOF

  800.upto(7000) { |rpm|
    next unless rpm % 200 == 0

    power, axle_torque, axle_omega = powertrain.output(rpm)
    kw = power / 1000.to_f
    mph = Imperial.mph(Disk.tangential(axle_omega, 0.32))
    ps = Imperial.ps(kw)
    puts format("%s RPM: %s Nm  %s kW  %s PS\t%s mph",
                rpm.round.to_s.rjust(4, ' '),
                axle_torque.round(1).to_s.rjust(5, ' '),
                kw.round(1).to_s.rjust(5, ' '),
                ps.round.to_s.rjust(4, ' '),
                mph.round.to_s.rjust(3, ' '))
  }
}
