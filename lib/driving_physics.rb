module DrivingPhysics
  #
  # defaults
  #
  AMBIENT_TEMP = 25     # deg c
  PETROL_DENSITY = 0.71 # kg / L

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

  # we're going to model 3 resistance forces
  # 1. air resistance (goes up with the square of velocity)
  # 2. rotational resistance (internal friction, linear with velocity)
  # 3. rolling resistance (linear with mass)

  # Note: here we only consider speed; we're in a 1D world for now

  module Force
    G = 9.8               # m / sec^2
    AIR_DENSITY = 1.29    # kg / m^3

    #
    # approximations for 2000s-era Corvette
    #
    DRAG_COF = 0.3
    FRONTAL_AREA = 2.2    # m^2

    def self.air_resistance(speed,
                            frontal_area: FRONTAL_AREA,
                            drag_coefficient: DRAG_COF,
                            air_density: AIR_DENSITY)
      0.5 * frontal_area * drag_coefficient * air_density * speed ** 2
    end

    # we approximate rotational resistance from observations that
    # rotational resistance is roughly equivalent to air resistance
    # at highway speeds (30 m/s)
    ROTATIONAL_RESISTANCE = air_resistance(1) * 30

    def self.rotational_resistance(speed)
      ROTATIONAL_RESISTANCE * speed
    end

    # coefficient of rolling friction
    # this is an approximate value for street tires on concrete
    CRF = 0.01

    def self.rolling_resistance(mass, crf: CRF)
      mass * G * crf
    end

    # the braking stuff is made up but should work
    # 50 N of pedal force generates 50 kN of braking force for
    # 1000kg at 100 m/s
    BRAKE_COF = 0.005

    def self.braking(clamping_force,
                     motivating_force:,
                     speed:, mass:,
                     brake_coefficient: BRAKE_COF)
      bf = clamping_force * mass * G * brake_coefficient
      if speed > 0.0
        bf
      else
        [bf, motivating_force].min
      end
    end

    def self.all_resistance(speed, mass,
                            crf: CRF,
                            frontal_area: FRONTAL_AREA,
                            drag_coefficient: DRAG_COF,
                            air_density: AIR_DENSITY)
      air_resistance(speed,
                     frontal_area: frontal_area,
                     drag_coefficient: drag_coefficient,
                     air_density: air_density) +
        rotational_resistance(speed) +
        rolling_resistance(mass, crf: crf)
    end
  end
end
