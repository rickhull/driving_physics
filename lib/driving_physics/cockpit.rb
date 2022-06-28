require 'driving_physics/car'

module DrivingPhysics
  class Cockpit
    CLUTCH_MIN = 0.1
    REV_MATCH = 0.02
    REV_SLIP = 0.1
    MODE = {
      normal: 0,
      sport: 1,
      sport_plus: 2,
    }
    MODE_LABELS = MODE.invert

    def self.mode_label(idx)
      MODE_LABELS.fetch(idx)
    end

    # return [:status, recommended clutch, proportional difference]
    def self.rev_match(old_rpm, new_rpm)
      diff = new_rpm - old_rpm
      proportion = diff.to_f / old_rpm
      clutch = [1.0 - proportion.abs, CLUTCH_MIN].max
      if proportion.abs <= REV_MATCH
        [:match, 1.0, proportion]
      elsif proportion.abs <= REV_SLIP
        [:slip, clutch, proportion]
      else
        [:mismatch, clutch, proportion]
      end
    end

    def self.unit_interval!(val)
      if val < 0.0 or val > 1.0
        raise(ArgumentError, "val #{val.inspect} should be between 0 and 1")
      end
      val
    end

    def self.generate
      e = Environment.new
      t = Tire.new(e)
      m = Motor.new(e)
      g = Gearbox.new(e)
      p = Powertrain.new(motor: m, gearbox: g)
      c = Car.new(tire: t, powertrain: p)
      self.new(c)
    end

    attr_reader :car, :brake_pedal, :steering_wheel, :mode, :mode_label
    attr_accessor :min_rpm, :max_rpm

    def initialize(car)
      @car = car
      @brake_pedal = 0.0    # to 1.0
      @steering_wheel = 0.0 # -1.0 to +1.0
      @min_rpm = @car.powertrain.motor.idle_rpm + 1000
      @max_rpm = @car.powertrain.motor.redline

      @mode = 0             # normal

      yield self if block_given?
    end

    def clutch_pedal
      1.0 - @car.clutch
    end

    def clutch_pct
      self.clutch_pedal * 100
    end

    # clutch pedal has inverse relationship with the clutch itself
    # clutch pedal DISENGAGES the clutch; pedal at 0.0 means clutch at 1.0
    def clutch_pedal=(val)
      @car.clutch = 1.0 - self.class.unit_interval!(val)
    end

    def brake_pct
      self.brake_pedal * 100
    end

    # TODO: implement @car.brake or something
    def brake_pedal=(val)
      @brake_pedal = self.class.unit_interval!(val)
    end

    def throttle_pedal
      @car.throttle
    end

    def throttle_pct
      self.throttle_pedal * 100
    end

    def throttle_pedal=(val)
      @car.throttle = self.class.unit_interval!(val)
    end

    def steering_pct
      self.steering_wheel * 100
    end

    # TODO: implement @car.steering_wheel
    def steering_wheel=(val)
      self.class.unit_interval!(val.abs)
      @steering_wheel = val
    end

    def gear
      @car.gear
    end

    def gear=(val)
      @car.gear = val
    end

    def mode=(val)
      @mode = MODE_LABELS[val] ? val : MODE.fetch(val)
      @mode_label = Cockpit.mode_label(@mode)
    end

    def to_s
      [
        format("Clutch: %d%%  Brake: %d%%  Throttle: %d%%",
               self.clutch_pct, self.brake_pct, self.throttle_pct),
        format("Wheel: %d%%  Gear: %d  Mode: %s",
               self.steering_pct, self.gear, self.mode_label)
      ].join("\n")
    end

    # return :normal, :sport, :sport_plus based on pedal positions
    def pedal_mode
      if self.brake_pedal < 0.4 and self.throttle_pedal < 0.5
        MODE[:normal]
      elsif self.brake_pedal < 0.7 and self.throttle_pedal < 0.8
        MODE[:sport]
      else
        MODE[:sport_plus]
      end
    end

    def rpm_range
      if @mode < MODE[:sport_plus] and self.pedal_mode == MODE[:sport_plus]
        mode = @mode + 1
      elsif @mode == MODE[:sport_plus] and self.pedal_mode == MODE[:normal]
        mode = MODE[:sport]
      else
        mode = @mode
      end

      case mode
      when MODE[:normal]
        [@min_rpm, [@min_rpm + 3000, @max_rpm - 1000].min]
      when MODE[:sport]
        [@min_rpm + 1000, @max_rpm - 1000]
      when MODE[:sport_plus]
        [@min_rpm + 1500, @max_rpm]
      end
    end

    def choose_gear(rpm)
      min, max = *self.rpm_range
      gear = self.gear

      if rpm < min and gear > 1
        gear - 1
      elsif rpm > max and gear < @car.top_gear
        gear + 1
      else
        gear
      end
    end
  end
end
