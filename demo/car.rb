require 'driving_physics/car'

include DrivingPhysics

env = Environment.new
puts env

tire = Tire.new(env)
motor = Motor.new(env)
pt = Powertrain.new(motor, Gearbox.new)

car = Car.new(tire: tire, powertrain: pt) { |c|
  c.mass = 1050.0
  c.frontal_area = 2.5
  c.cd = 0.5
}

puts car

rpm = 0 # off

duration = 60

speed = 0.0
dist = 0.0

tire_omega = 0.0
tire_theta = 0.0

crank_omega = 0.0
crank_theta = 0.0

t = Time.now
num_ticks = duration * env.hz

clutch = :ok
phase = :ignition
puts <<EOF

#
# IGNITION
#

EOF

num_ticks.times { |i|
  if phase == :ignition
    # ignition phase
    crank_alpha = motor.starter_alpha(crank_omega)
    crank_omega += crank_alpha * env.tick
    crank_theta += crank_omega * env.tick

    rpm = DrivingPhysics.rpm(crank_omega)

    if i % 100 == 0 or rpm > motor.idle_rpm
      puts DrivingPhysics.elapsed_display(i)
      puts format("%d rad  %d rad/s  %d rad/s/s",
                  crank_theta, crank_omega, crank_alpha)
      puts "RPM: #{rpm.round}"
      puts
    end

    if rpm > motor.idle_rpm
      pt.select_gear(1)
      phase = :running

      puts <<EOF

#
# RUNNING
#

EOF
    end
  elsif phase == :running
    ar = car.air_resistance(speed)
    rr = car.rolling_resistance(tire_omega)
    rf = car.rotational_resistance(tire_omega)

    force = car.drive_force(rpm) + ar + rr + rf
    ir = car.inertial_resistance(force)
    force += ir

    acc = DrivingPhysics.acc(force, car.total_mass)
    speed += acc * env.tick
    dist += speed * env.tick

    tire_alpha = acc / car.tire.radius
    tire_omega += tire_alpha * env.tick
    tire_theta += tire_omega * env.tick

    tq = car.powertrain.axle_torque(rpm)

    if i % 100 == 0
      puts DrivingPhysics.elapsed_display(i)
      puts format("  Tire: %.1f r  %.2f r/s  %.3f r/s^2",
                  tire_theta, tire_omega, tire_alpha)
      puts format("   Car: %.1f m  %.2f m/s  %.3f m/s^2", dist, speed, acc)
      puts format("   RPM: %d  %.1f Nm (%d N)  Drive: %d N",
                  rpm, tq, car.drive_force(rpm), force)
      puts "Resistance: " + format(%w[Air Roll Spin Inertial].map { |s|
                                     "#{s} %.1f N"
                                   }.join('  '), ar, rr, rf, ir)
      puts
    end

    # tire_omega determines new rpm
    new_rpm = car.powertrain.crank_rpm(tire_omega)
    new_clutch, proportion = car.powertrain.gearbox.match_rpms(rpm, new_rpm)

    if new_clutch != clutch
      p [new_clutch, proportion, new_rpm]
      clutch = new_clutch
      gets
    end

    rpm = new_rpm if clutch == :ok
    car.powertrain.gearbox.shift!(rpm)
  end
}

elapsed = Time.now - t
puts format("%.2f s (%d ticks / s)", elapsed, num_ticks / elapsed)
