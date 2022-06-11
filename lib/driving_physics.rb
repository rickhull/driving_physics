module DrivingPhysics
  #
  # Units: metric
  #
  # distance: meter
  # velocity: meter / sec
  # acceleration: meter / sec^2
  # volume: Liter
  # temperature: Celsius
  #

  #
  # environmental defaults
  #
  HZ = 1000
  G = 9.8               # m/s^2
  AIR_TEMP = 25         # deg c
  AIR_DENSITY = 1.29    # kg / m^3
  PETROL_DENSITY = 0.71 # kg / L   TODO: move to car.rb

  #
  # defaults for resistance forces
  #
  FRONTAL_AREA = 2.2  # m^2, based roughly on 2000s-era Chevrolet Corvette
  DRAG_COF = 0.3      # based roughly on 2000s-era Chevrolet Corvette
  DRAG = 0.4257       # air_resistance at 1 m/s given above numbers
  ROT_COF = 12.771    # if rotating resistance matches air resistance at 30 m/s
  ROLL_COF = 0.01     # roughly: street tires on concrete

  #
  # constants
  #
  SECS_PER_MIN = 60
  MINS_PER_HOUR = 60
  SECS_PER_HOUR = SECS_PER_MIN * MINS_PER_HOUR

  def self.elapsed_display(elapsed_ms)
    elapsed_s, ms = elapsed_ms.divmod 1000

    h = elapsed_s / SECS_PER_HOUR
    elapsed_s -= h * SECS_PER_HOUR
    m, s = elapsed_s.divmod SECS_PER_MIN

    [[h, m, s].map { |i| i.to_s.rjust(2, '0') }.join(':'),
     ms.to_s.rjust(3, '0')].join('.')
  end

  def self.kph(meters_per_sec)
    meters_per_sec.to_f * SECS_PER_HOUR / 1000
  end

  # acceleration; F=ma
  # force can be a scalar or a Vector
  def self.a(force, mass)
    force / mass.to_f
  end
  alias_method(:acc, :a)

  def self.delta(a, b, dt: 1.0 / HZ)
    a + b * dt
  end

  #def self.vel(init_v, a, dt: 1.0 / HZ)
  #  delta(init_v, a, dt)
  #end


  # velocity, given acceleration and initial velocity
  # a and init_v can be scalar or Vector but must match
  def self.v(a, init_v, dt: 1.0 / HZ)
    init_v + a * dt
  end
  alias_method(:vel, :v)

  # position, given velocity and initial position
  # v and init_p can be scalar or Vector but must match
  def self.p(v, init_p, dt: 1.0 / HZ)
    init_p + v * dt
  end
  alias_method(:pos, :p)

  # these will be aliases later
  def self.omega(init_o, a, dt: 1.0 / HZ)
    delta(init_o, a, dt)
  end

  def self.theta(init_t, o, dt: 1.0 / HZ)
    delta(init_t, o, dt)
  end
end
