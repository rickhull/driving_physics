require 'driving_physics'

DP = DrivingPhysics

pos = 0
spd = 0
mass = 1000
drive_force = 7000
duration = 100 # seconds

(duration * DP::TICKS_PER_SEC).times { |i|
  nf = DP.net_force_simple(drive_force, spd)
  a = DP.a(nf, mass)
  spd = DP.v(spd, a)
  pos = DP.p(pos, spd)

  if i % DP::TICKS_PER_SEC == 0
    puts [i / DP::TICKS_PER_SEC,
          "#{'%.2f' % spd} m/s",
          "#{'%.2f' % pos} m"].join("\t")
  end
}
