require 'driving_physics/car'

include DrivingPhysics

env = Environment.new
puts env

car = Car.new(wheel: Wheel.new(env), powertrain: Powertrain.new(1000)) { |c|
  c.mass = 1050.0
  c.frontal_area = 2.5
  c.cd = 0.5
}

puts car

duration = 160

dist = 0.0
speed = 0.0

theta = 0.0
omega = 0.0

t = Time.now
num_ticks = duration * env.hz

num_ticks.times { |i|
  ar = car.air_resistance(speed)
  rr = car.rolling_resistance(omega)
  rf = car.rotational_friction(omega)

  force = car.nominal_drive_force - ar - rr - rf
  ir = car.inertial_resistance(force)
  force -= ir

  acc = DrivingPhysics.acc(force, car.total_mass)
  speed += acc * env.tick
  dist += speed * env.tick

  alpha = acc / car.wheel.radius
  omega += alpha * env.tick
  theta += omega * env.tick

  if i < 10 or
    (i < 20_000 and i%1000 == 0) or
    (i % 10_000 == 0) or
    i == duration * env.hz - 1

    tq = car.powertrain.axle_torque
    loss = (1.0 - force * car.wheel.radius / tq) * 100

    puts DrivingPhysics.elapsed_display(i)
    puts format(" Wheel: %.1f r  %.2f r/s  %.3f r/s^2", theta, omega, alpha)
    puts format("   Car: %.1f m  %.2f m/s  %.3f m/s^2", dist, speed, acc)
    puts format("Torque: %.1f Nm (%d N) Drive: %.1f N  Loss: %.1f%%",
                tq, car.nominal_drive_force, force, loss)
    puts "Resistance: " + format(%w[Air Roll Spin Inertial].map { |s|
                                   "#{s} %.1f N"
                                 }.join('  '), ar, rr, rf, ir)
    puts
  end
}

elapsed = Time.now - t
puts format("%.2f s (%d ticks / s)", elapsed, num_ticks / elapsed)
