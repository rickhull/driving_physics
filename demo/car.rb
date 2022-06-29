require 'driving_physics/car'
require 'driving_physics/cockpit'
require 'driving_physics/imperial'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
puts env

tire = Tire.new(env)
motor = Motor.new(env)
gearbox = Gearbox.new(env)
powertrain = Powertrain.new(motor: motor, gearbox: gearbox)
car = Car.new(tire: tire, powertrain: powertrain) { |c|
  c.body_mass = 850.0
  c.frontal_area = 2.5
  c.cd = 0.5
}
puts car

cockpit = Cockpit.new(car)
puts cockpit
CLI.pause

duration = 120

acc = 0.0
speed = 0.0
dist = 0.0

tire_alpha = 0.0
tire_omega = 0.0
tire_theta = 0.0

crank_alpha = 0.0
crank_omega = 0.0

start = Timer.now
paused = 0.0
num_ticks = duration * env.hz + 1

rev_match = :ok
phase = :ignition
gearbox.clutch = 0.0 # clutch in to fire up motor
flag = false

rpm, crank_torque = 0, 0
axle_torque, drive_force, net_force = 0, 0, 0
ar, rr, rf, ir = 0, 0, 0, 0

puts <<EOF

#
# IGNITION
#

EOF

num_ticks.times { |i|
  if phase == :ignition
    crank_alpha = motor.alpha(motor.starter_torque, omega: crank_omega)
    crank_omega += crank_alpha * env.tick

    rpm = DrivingPhysics.rpm(crank_omega)

    if rpm > motor.idle_rpm
      flag = true
      cockpit.gear = 1
      cockpit.throttle_pedal = 1.0
      phase = :running

      puts <<EOF

#
# RUNNING
#

EOF
    end
  elsif phase == :running or phase == :off_throttle
    ar = car.air_force(speed)
    rr = car.tire_rolling_force(tire_omega)
    rf = car.tire_rotational_force(tire_omega)

    # note, this fails if we're in neutral
    drive_force = car.drive_force(rpm, axle_omega: tire_omega)
    net_force = drive_force + ar + rr + rf

    ir = car.tire_inertial_force(net_force)
    net_force += ir

    acc = DrivingPhysics.acc(net_force, car.total_mass)
    speed += acc * env.tick
    dist += speed * env.tick

    tire_alpha = acc / car.tire.radius
    tire_omega += tire_alpha * env.tick
    tire_theta += tire_omega * env.tick

    crank_alpha = tire_alpha / car.powertrain.gearbox.ratio
    crank_omega += crank_alpha * env.tick

    # tire_omega determines new rpm
    new_rpm = gearbox.crank_rpm(tire_omega, crank_rpm: rpm)
    new_rev_match, clutch, proportion = Cockpit.rev_match(rpm, new_rpm)

    if new_rev_match != rev_match
      flag = true
      puts format("Rev Match: [%s] %d RPM is %.1f%% from %d RPM",
                  new_rev_match, new_rpm, proportion * 100, rpm)
      # puts format("Recommend clutch to %.1f%%", clutch * 100)
      rev_match = new_rev_match
    end

    clutch_diff = clutch - gearbox.clutch
    if clutch_diff.abs > 0.1
      flag = true
      puts format("Clutch: %.1f%%  Recommended Clutch: %.1f%%",
                  gearbox.clutch * 100, clutch * 100)
    end
    # the clutch pedal will reflect this change
    gearbox.clutch += clutch_diff * 0.5

    # update the motor RPM based on new clutch
    new_rpm = gearbox.crank_rpm(tire_omega, crank_rpm: rpm)
    rpm = new_rpm if new_rpm > motor.idle_rpm

    new_gear = cockpit.choose_gear(rpm)
    if new_gear != cockpit.gear
      flag = true
      puts "Gear Change: #{new_gear}"
      cockpit.gear = new_gear
    end

    # cut throttle after 60 s
    if i > 60 * env.hz and car.throttle == 1.0
      flag = true
      phase = :off_throttle
      cockpit.throttle_pedal = 0
    end

    # maintain idle when revs drop
    if cockpit.throttle_pedal == 0 and rpm < motor.idle_rpm
      phase = :idling
      car.gear = 0
    end

    print "===\n\n" if flag

  elsif phase == :idling
    # fake; exit
    rpm = motor.idle_rpm
    break
  end

  if flag or (i < 5000 and i % 100 == 0) or (i % 1000 == 0)
    puts Timer.display(ms: i)
    puts format("  Phase: %s", phase)
    puts format("   Tire: %.3f r/s/s  %.2f r/s  %.1f r",
                tire_alpha, tire_omega, tire_theta)
    puts format("    Car: %.3f m/s/s  %.2f m/s  %.1f m  (%.1f MPH)",
                acc, speed, dist, Imperial.mph(speed))
    if phase == :ignition
      puts format("  Motor: %d RPM  Starter: %d Nm  Friction: %.1f Nm",
                  rpm, motor.starter_torque, motor.friction(crank_omega))
    else
      crank_torque = car.powertrain.motor.torque(rpm)
      puts format("  Motor: %d RPM  %.1f Nm  Friction: %.1f Nm",
                  rpm, crank_torque, motor.friction(crank_omega))
    end
    puts format("Gearbox: %s", gearbox.inputs)
    if phase != :ignition
      axle_torque = car.powertrain.axle_torque(rpm, axle_omega: tire_omega)
      puts format("   Axle: %.1f Nm (%d N)  Net Force: %.1f N",
                  axle_torque, drive_force, net_force)
    end
    puts        " Resist: " + format(%w[Air Roll Spin Inertial].map { |s|
                                       "#{s}: %.1f N"
                                     }.join('  '), ar, rr, rf, ir)
    puts        cockpit
    puts
    paused += CLI.pause if flag
    flag = false
  end
}

puts Timer.summary(start, num_ticks, paused)
