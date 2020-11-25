require 'driving_physics/scalar_force'

DP = DrivingPhysics

pos = 0               # m
spd = 0               # m/s
mass = 1000           # kg
weight = mass * DP::G # N
drive_force = 7000    # N
duration = 100        # seconds
tick = 1.0 / DP::HZ

(duration * DP::HZ).times { |i|
  nf = drive_force - DP::ScalarForce.all_resistance(spd, nf_mag: weight)

  a = DP.a(nf, mass)
  spd = DP.v(a, spd, dt: tick)
  pos = DP.p(spd, pos, dt: tick)

  if i % DP::HZ == 0
    puts [i / DP::HZ,
          format("%.2f m/s", spd),
          format("%.2f m", pos),
         ].join("\t")
  end
}
