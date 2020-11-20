module DrivingPhysics
  AMBIENT_TEMP = 25 # deg c

  PETROL_DENSITY = 0.71 # kg / L
  G = 9.8 # m / sec^2
  FEET_PER_METER = 3.28084
  FEET_PER_MILE = 5280
  SECS_PER_MIN = 60
  MINS_PER_HOUR = 60
  SECS_PER_HOUR = SECS_PER_MIN * MINS_PER_HOUR

  # multiply m/s to get mph
  MPH = (FEET_PER_METER / FEET_PER_MILE) * SECS_PER_HOUR

  def self.mph(mps)
    MPH * mps
  end

  def self.velocity(initial: 0, acceleration:, time:)
    initial + acceleration * time
  end

  def self.elapsed_display(elapsed_ms)
    elapsed_s = elapsed_ms / 1000
    h = elapsed_s / 3600
    elapsed_s -= h * 3600
    m = elapsed_s / 60
    s = elapsed_s % 60
    ms = elapsed_ms % 1000

    [[h, m, s].map { |i| i.to_s.rjust(2, '0') }.join(':'),
     ms.to_s.rjust(3, '0')].join('.')
  end
end
