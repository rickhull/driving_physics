require 'driving_physics/powertrain'
require 'driving_physics/imperial'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)
gearbox = Gearbox.new(env)
pt = Powertrain.new(motor, gearbox)
puts env
puts pt
CLI.pause

crank_alpha = 0.0
crank_omega = 0.0

axle_alpha = 0.0
axle_omega = 0.0


# Run through the gears

1.upto(6) { |gear|
  pt.select_gear(gear)

  puts <<EOF

# GEAR #{gear} (#{pt.gearbox.ratio})
#
EOF

  800.upto(7000) { |rpm|
    next unless rpm % 500 == 0

    # get the crank kinematics
    torque = motor.torque(rpm)
    crank_alpha = motor.alpha(torque, omega: crank_omega)
    crank_torque = motor.implied_torque(crank_alpha)

    # get the axle kinematics, minus more inertia and more friction
    axle_torque = gearbox.axle_torque(crank_torque)

    # this will be a crazy nigh number, as there is no load, just
    # rotational inertia
    axle_alpha = gearbox.alpha(axle_torque, omega: axle_omega)

    # axle speed is strictly determined by RPM
    axle_omega = gearbox.axle_omega(rpm)
    axle_torque = gearbox.implied_torque(axle_alpha)

    # mate the engine to the transmission
    crank_omega = axle_omega / gearbox.ratio

    crank_speed = Disk.tangential(crank_omega, 0.32)
    crank_mph = Imperial.mph(crank_speed)

    axle_speed = Disk.tangential(axle_omega, 0.32)
    axle_mph = Imperial.mph(axle_speed)
    puts format(  "%d RPM: %.1f Nm  %.1f Nm  %.1f Nm",
                rpm, torque, crank_torque, axle_torque)
    puts format("   Crank: %.1f rad/s/s  %.1f rad/s  %d mph",
                crank_alpha, crank_omega, crank_mph)
    puts format("    Axle: %.1f rad/s/s  %.1f rad/s  %d mph",
                axle_alpha, axle_omega, axle_mph)
    puts
  }
}
