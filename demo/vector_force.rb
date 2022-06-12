require 'driving_physics/vector_force'

DP = DrivingPhysics

p = Vector[0, 0]      # m
v = Vector[0, 0]      # m/s
mass = 1000           # kg
weight = mass * DP::G # N
duration = 100        # seconds
drive_force = DP.random_unit_vector * 7000 # N
tick = 1.0 / DP::HZ

(duration * DP::HZ).times { |i|
  nf = drive_force + DP::VectorForce.all_resistance(v, dir: v, nf_mag: weight)

  a = DP.acc(nf, mass)
  v = DP.vel(v, a, dt: tick)
  p = DP.pos(p, v, dt: tick)

  if i % DP::HZ == 0
    puts [i / DP::HZ,
          format("%.2f m/s", v.magnitude),
          format("%.2f m", p.magnitude),
         ].join("\t")
  end
}
