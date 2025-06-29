require 'driving_physics'

module DrivingPhysics
  module Imperial
    FEET_PER_METER = 3.28084
    FEET_PER_MILE = 5280
    MPH = (FEET_PER_METER / FEET_PER_MILE) * SECS_PER_HOUR
    CI_PER_LITER = 61.024
    GAL_PER_LITER = 0.264172
    PS_PER_KW = 1.3596216173039

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

    # convert kilowatts to horsepower
    def self.ps(kw)
      kw * PS_PER_KW
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

    def self.liters(ci = nil, gallons: nil)
      raise(ArgumentError, "argument missing") if ci.nil? and gallons.nil?
      return ci / CI_PER_LITER if gallons.nil?
      gallons.to_f / GAL_PER_LITER
    end

    def self.gallons(liters)
      liters * GAL_PER_LITER
    end
  end
end
