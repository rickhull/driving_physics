module DrivingPhysics
  #
  # defaults
  #
  AMBIENT_TEMP = 25     # deg c
  PETROL_DENSITY = 0.71 # kg / L
  AIR_DENSITY = 1.29    # kg / m^3

  TICKS_PER_SEC = 1000
  TICK = 1 / TICKS_PER_SEC.to_f

  SECS_PER_MIN = 60
  MINS_PER_HOUR = 60
  SECS_PER_HOUR = SECS_PER_MIN * MINS_PER_HOUR

  # conversions for Imperial
  FEET_PER_METER = 3.28084
  FEET_PER_MILE = 5280
  MPH = (FEET_PER_METER / FEET_PER_MILE) * SECS_PER_HOUR
  def self.mph(mps)
    MPH * mps
  end

  def self.kph(mps)
    mps.to_f * SECS_PER_HOUR / 1000
  end

  G = 9.8               # m / sec^2

  def self.force_drag_full(drag_coefficient:,
                           frontal_area:,
                           air_density:,
                           speed:)
    0.5 * drag_coefficient * frontal_area * air_density * speed ** 2
  end

  #
  # approximations for 2000s-era Corvette
  #
  DRAG_COF = 0.3
  FRONTAL_AREA = 2.2 # m^2

  # drag constant, for easy calculation of drag force
  C_DRAG = force_drag_full(drag_coefficient: DRAG_COF,
                           frontal_area: FRONTAL_AREA,
                           air_density: AIR_DENSITY,
                           speed: 1)

  # NOTE: RR is _not_ mere "rolling resistance" which has a complicated
  # relationship to speed.  Rolling resistance can be thought of as mostly
  # constant relative to speed.  However, we are considering "rotational
  # resistance" here.  This means axles and wheel bearings, etc.  The
  # rotational resistance should be linear with speed.

  # rotational resistance constant, for easy calculation of rr force
  # approximation based on rr and drag forces roughly equal at 30 m/s

  RR_DRAG_EQUIVALENT_SPEED = 30 # m/s
  C_RR = RR_DRAG_EQUIVALENT_SPEED * C_DRAG

  # just provide speed, use sensible defaults
  def self.force_drag(speed,
                      frontal_area: FRONTAL_AREA,
                      drag_coefficient: DRAG_COF,
                      air_density: AIR_DENSITY)
    force_drag_full(drag_coefficient: drag_cof,
                    frontal_area: frontal_area,
                    air_density: air_density,
                    speed: speed)
  end

  def self.force_drag_simple(speed)
    C_DRAG * speed ** 2
  end

  def self.force_rr_simple(speed)
    C_RR * speed
  end

  # drive force minus resistance forces
  def self.net_force_simple(drive_force, speed)
    drive_force - force_rr_simple(speed) - force_drag_simple(speed)
  end

  def self.elapsed_display(elapsed_ms)
    elapsed_s, ms = elapsed_ms.divmod 1000

    h = elapsed_s / SECS_PER_HOUR
    elapsed_s -= h * SECS_PER_HOUR
    m, s = elapsed_s.divmod SECS_PER_MIN

    [[h, m, s].map { |i| i.to_s.rjust(2, '0') }.join(':'),
     ms.to_s.rjust(3, '0')].join('.')
  end

  # force can be a scalar or a Vector
  def self.a(force, mass)
    force / mass.to_f
  end

  def self.v(v, a, dt = TICK)
    v + a * dt
  end

  def self.p(p, v, dt = TICK)
    p + v * dt
  end

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
end
