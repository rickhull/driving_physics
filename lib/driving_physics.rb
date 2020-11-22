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
  # defaults
  #
  AMBIENT_TEMP = 25     # deg c
  PETROL_DENSITY = 0.71 # kg / L   TODO: move to car.rb
  TICKS_PER_SEC = 1000
  TICK = 1 / TICKS_PER_SEC.to_f
  G = 9.8               # m/s^2

  #
  # constants
  #
  SECS_PER_MIN = 60
  MINS_PER_HOUR = 60
  SECS_PER_HOUR = SECS_PER_MIN * MINS_PER_HOUR

  module Imperial
    FEET_PER_METER = 3.28084
    FEET_PER_MILE = 5280
    MPH = (FEET_PER_METER / FEET_PER_MILE) * SECS_PER_HOUR
    CI_PER_LITER = 61.024

    def self.feet(meters)
      meters * FEET_PER_METER
    end

    def self.meters(feet)
      feet / FEET_PER_METER
    end

    def self.miles(meters = nil, km: nil)
      raise(ArgumentError, "argument missing") if meters.nil? and km.nil?
      meters ||= km * 1000
      meters * FEET_PER_METER / FEET_PER_MILE
    end

    def self.mph(mps = nil, kph: nil)
      raise(ArgumentError, "argument missing") if mps.nil? and kph.nil?
      mps ||= kph.to_f * 1000 / SECS_PER_HOUR
      MPH * mps
    end

    def self.mps(mph)
      mph / MPH
    end

    def self.kph(mph)
      DP::kph(mps(mph))
    end

    def self.deg_c(deg_f)
      (deg_f - 32).to_f * 5 / 9
    end

    def self.deg_f(deg_c)
      deg_c.to_f * 9 / 5 + 32
    end

    def self.cubic_inches(liters)
      liters * CI_PER_LITER
    end

    def self.liters(ci)
      ci / CI_PER_LITER
    end
  end

  def self.kph(mps)
    mps.to_f * SECS_PER_HOUR / 1000
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

  def self.elapsed_display(elapsed_ms)
    elapsed_s, ms = elapsed_ms.divmod 1000

    h = elapsed_s / SECS_PER_HOUR
    elapsed_s -= h * SECS_PER_HOUR
    m, s = elapsed_s.divmod SECS_PER_MIN

    [[h, m, s].map { |i| i.to_s.rjust(2, '0') }.join(':'),
     ms.to_s.rjust(3, '0')].join('.')
  end

  module Force

    #
    # Resistance Forces
    #
    # 1. air resistance aka drag aka turbulent drag
    #    depends on v^2
    # 2. "rotatational" resistance, e.g. bearings / axles / lubricating fluids
    #    aka viscous drag; linear with v
    # 3. rolling resistance, e.g. tire and surface deformation
    #    constant with v, depends on normal force and tire/surface properties
    # 4. braking resistance, supplied by operator, constant with v
    #    depends purely on operator choice and physical limits
    #    as such, it is not modeled here
    #

    # Note: here we only consider speed; we're in a 1D world for now

    AIR_DENSITY = 1.29    # kg / m^3

    #
    # approximations for 2000s-era Corvette
    #
    DRAG_COF = 0.3
    FRONTAL_AREA = 2.2    # m^2

    # coefficient of rolling friction
    # this is an approximate value for street tires on concrete
    ROLL_COF = 0.01

    def self.air_resistance(speed,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY)
      0.5 * frontal_area * drag_cof * air_density * speed ** 2
    end

    # we approximate rotational resistance from observations that
    # rotational resistance is roughly equivalent to air resistance
    # at highway speeds (30 m/s)
    ROT_COF = air_resistance(1) * 30

    def self.rotational_resistance(speed, rot_cof: ROT_COF)
      speed * rot_cof
    end

    # normal force is not always mass * G, e.g. aero downforce
    def self.rolling_resistance(normal_force, roll_cof: ROLL_COF)
      normal_force * roll_cof
    end

    #
    # convenience methods
    #

    def self.speed_resistance(speed,
                              frontal_area: FRONTAL_AREA,
                              drag_cof: DRAG_COF,
                              air_density: AIR_DENSITY,
                              rot_cof: ROT_COF)
      air_resistance(speed,
                     frontal_area: frontal_area,
                     drag_cof: drag_cof,
                     air_density: air_density) +
        rotational_resistance(speed, rot_cof: rot_cof)
    end

    def self.all_resistance(speed,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY,
                            rot_cof: ROT_COF,
                            nf_mag:,
                            roll_cof: ROLL_COF)
      speed_resistance(speed,
                       frontal_area: frontal_area,
                       drag_cof: drag_cof,
                       air_density: air_density,
                       rot_cof: rot_cof) +
        rolling_resistance(nf_mag, roll_cof: roll_cof)
    end
  end
end
