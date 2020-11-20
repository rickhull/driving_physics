# tractive force
# Ftrac = u * Engineforce (u is unit vector in direction of travel)

# drag force
# Fdrag = -Cdrag * v * |v| (drag constant, velocity vector, v magnitude)
# |v| aka speed

# speed = sqrt(v.x*v.x + v.y*v.y)
# Fdrag.x = -Cdrag * v.x * speed
# Fdrag.y = -Cdrag * v.y * speed

# rolling resistance
# Frr = -Crr * v

# at low speed, rr dominates drag; even at 30 m/s; drag dominates after
# this implies Crr = 30 * Cdrag

# longitudinal forces:
# Flong = Ftrac + Fdrag + Frr

# acceleration is determined by F=ma; so a = F / m
# velocity is determined by integrating acceleration over time
# use the Euler method:
# v = v + dt * a   (new velocity = old velocity + time_tick * current acc)

# position is determined by integrating velocity over time
# p = p + dt * v

# let's simulate a top speed

# mass = 1000 kg
# Feng = 7000 N
# Cdrag = 0.4257
# Crr = 12.8

C_DRAG = 0.4257
C_RR = 12.8
TICK = 0.001 # seconds; tick represents 1 ms

def force_drag(v)
  -1 * C_DRAG * v * v
end

def force_rr(v)
  -1 * C_RR * v
end

def force_trac(force_engine)
  force_engine
end

def force_long(force_trac, force_drag, force_rr)
  force_trac + force_drag + force_rr
end

def net_force(force_engine, v)
  force_engine + force_drag(v) + force_rr(v)
end

def acceleration(net_force, mass)
  net_force.to_f / mass
end

def velocity(v_init, acc)
  v_init + acc * TICK
end

def position(p_init, v)
  p_init + v * TICK
end

pos = 0
spd = 0
mass = 1000
feng = 7000

59999.times { |i|
  nf = net_force(7000, spd)
  a = acceleration(nf, mass)
  spd = velocity(spd, a)
  pos = position(pos, spd)

  if i%1000 == 0
    puts [i / 1000, "#{'%.2f' % spd} m/s", "#{'%.2f' % pos} m"].join("\t")
  end
}
