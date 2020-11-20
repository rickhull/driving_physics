require 'driving_physics/vector'

DP = DrivingPhysics
V = DrivingPhysics::Vector

p = Vector[0, 0]
v = Vector[0, 0]
mass = 1000
drive_force = V.random_unit_vector * 7000
duration = 100 # seconds

(duration * DP::TICKS_PER_SEC).times { |i|
  nf = drive_force +
       V::Force.all_resistance(drive_force,
                               velocity: v,
                               mass: mass)
  a = DP.a(nf, mass)
  v = DP.v(v, a)
  p = DP.p(p, v)

  if i % DP::TICKS_PER_SEC == 0
    puts [i / DP::TICKS_PER_SEC,
          "#{'%.2f' % v.magnitude} m/s",
          "#{'%.2f' % p.magnitude} m"].join("\t")
  end
}
