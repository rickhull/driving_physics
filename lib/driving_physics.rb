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
  TICK = Rational(1) / HZ
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
  ROT_CONST = 0.05    # N opposing drive force / torque
  ROLL_COF = 0.01     # roughly: street tires on concrete

  #
  # constants
  #
  SECS_PER_MIN = 60
  MINS_PER_HOUR = 60
  SECS_PER_HOUR = SECS_PER_MIN * MINS_PER_HOUR

  # HH::MM::SS.mmm
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
  def self.acc(force, mass)
    force / mass.to_f
  end

  # init and rate can be scalar or Vector but must match
  # this provides the general form for determining velocity and position
  def self.accum(init, rate, dt: TICK)
    init + rate * dt
  end

  class << self
    alias_method(:vel, :accum)
    alias_method(:pos, :accum)
    alias_method(:omega, :accum)
    alias_method(:theta, :accum)
  end
end
