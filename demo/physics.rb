require 'driving_physics'

DP = DrivingPhysics

pos = 0            # m
spd = 0            # m/s
mass = 1000        # kg
drive_force = 7000 # N
duration = 100     # seconds

(duration * DP::TICKS_PER_SEC).times { |i|
  nf = drive_force - DP::Force.all_resistance(spd, mass)
  a = DP.a(nf, mass)
  spd = DP.v(spd, a)
  pos = DP.p(pos, spd)

  if i % DP::TICKS_PER_SEC == 0
    puts [i / DP::TICKS_PER_SEC,
          "#{'%.2f' % spd} m/s",
          "#{'%.2f' % pos} m"].join("\t")
  end
}
