require 'driving_physics/car'
require 'driving_physics/imperial'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new
puts env

tire = Tire.new(env)
motor = Motor.new(env)
gearbox = Gearbox.new(env)
powertrain = Powertrain.new(motor, gearbox)
car = Car.new(tire: tire, powertrain: powertrain) { |c|
  c.body_mass = 850.0
  c.frontal_area = 2.5
  c.cd = 0.5
}
puts car
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
crank_theta = 0.0

start = Timer.now
paused = 0.0
num_ticks = duration * env.hz + 1

clutch = :ok
phase = :ignition
flag = false
rpm = 0
puts <<EOF

#
# IGNITION
#

EOF

num_ticks.times { |i|
  if phase == :ignition
    # ignition phase
    crank_alpha = motor.alpha(motor.starter_torque, omega: crank_omega)
    crank_omega += crank_alpha * env.tick
    crank_theta += crank_omega * env.tick

    rpm = DrivingPhysics.rpm(crank_omega)

    if i % 100 == 0 or rpm > motor.idle_rpm
      puts Timer.display(i)
      puts format("%d rad  %d rad/s  %d rad/s/s",
                  crank_theta, crank_omega, crank_alpha)
      puts format("%d RPM  %d Nm starter torque", rpm, motor.starter_torque)
      puts
    end

    if rpm > motor.idle_rpm
      car.gear = 1
      car.throttle = 1.0
      phase = :running

      puts <<EOF

#
# RUNNING
#

EOF
    end
  elsif phase == :running
    # track crank_alpha/omega/theta

    # cut throttle after 60 s
    car.throttle = 0 if i > 60 * env.hz and car.throttle == 1.0

    ar = car.air_force(speed)
    rr = car.tire_rolling_force(tire_omega)
    rf = car.tire_rotational_force(tire_omega)

    # note, this fails if we're in neutral
    force = car.drive_force(rpm) + ar + rr + rf

    ir = car.tire_inertial_force(force)
    force += ir

    acc = DrivingPhysics.acc(force, car.total_mass)
    speed += acc * env.tick
    dist += speed * env.tick

    tire_alpha = acc / car.tire.radius
    tire_omega += tire_alpha * env.tick
    tire_theta += tire_omega * env.tick

    crank_alpha = tire_alpha / car.powertrain.gearbox.ratio
    crank_omega += crank_alpha * env.tick
    crank_theta += crank_omega * env.tick

    axle_torque = car.powertrain.axle_torque(rpm)
    crank_torque = car.powertrain.motor.torque(rpm)

    if flag or (i < 5000 and i % 100 == 0) or (i % 1000 == 0)
      puts Timer.display(i)
      puts format("  Tire: %.1f r/s/s  %.2f r/s  %.3f r",
                  tire_alpha, tire_omega, tire_theta)
      puts format("   Car: %.1f m/s/s  %.2f m/s  %.3f m  (%.1f MPH)",
                  acc, speed, dist, Imperial.mph(speed))
      puts format(" Motor: %d RPM  %.1f Nm", rpm, crank_torque)
      puts format("  Axle: %.1f Nm (%d N)  Net Force: %.1f N",
                  axle_torque, car.drive_force(rpm), force)
      puts        "Resist: " + format(%w[Air Roll Spin Inertial].map { |s|
                                        "#{s}: %.1f N"
                                      }.join('  '), ar, rr, rf, ir)
      puts
      flag = false
    end

    # tire_omega determines new rpm
    new_rpm = car.powertrain.crank_rpm(tire_omega)
    new_clutch, proportion = car.powertrain.gearbox.match_rpms(rpm, new_rpm)

    if new_clutch != clutch
      flag = true
      puts format("Clutch: [%s] %d RPM is %.1f%% from %d RPM",
                  new_clutch, new_rpm, proportion * 100, rpm)
      clutch = new_clutch
      paused += CLI.pause
    end

    case new_clutch
    when :ok
      rpm = new_rpm
    when :mismatch
      flag = true
      puts '#'
      puts '# LURCH!'
      puts '#'
      puts
      rpm = new_rpm
    end
    next_gear = car.powertrain.gearbox.next_gear(rpm)
    if next_gear != gearbox.gear
      flag = true
      puts "Gear Change: #{next_gear}"
      car.gear = next_gear
      paused += CLI.pause
    end

    # maintain idle when revs drop
    if car.throttle == 0 and rpm < motor.idle_rpm
      phase = :idling
      car.gear = 0
      paused += CLI.pause
    end


  elsif phase == :idling
    # fake
    rpm = motor.idle_rpm
    break
  end
}

puts Timer.summary(start, num_ticks, paused)
