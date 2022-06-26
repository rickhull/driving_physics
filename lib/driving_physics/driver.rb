require 'driving_physics'

module DrivingPhysics
  class Driver
    CLUTCH_MIN = 0.1
    MATCH = 0.02
    SLIP = 0.1
    DOWNSHIFT = -1
    UPSHIFT = 1
    MODES = [:normal, :sport, :sport_plus]

    def self.mode_label(idx)
      MODES.fetch(idx)
    end

    # return [:status, recommended clutch, proportional difference]
    def self.rev_match(old_rpm, new_rpm)
      diff = new_rpm - old_rpm
      proportion = diff.to_f / old_rpm
      clutch = [1.0 - proportion.abs, CLUTCH_MIN].max
      if proportion.abs <= MATCH
        [:match, 1.0, proportion]
      elsif proportion.abs <= SLIP
        [:slip, clutch, proportion]
      else
        [:mismatch, clutch, proportion]
      end
    end

    # return :upshift, :downshift, or :ok
    # also sort of behaves like <=>
    def self.next_gear(gear, rpm, floor: 2500, ceiling: 6500)
      if rpm < floor
        DOWNSHIFT
      elsif rpm > ceiling
        UPSHIFT
      else
        0
      end
    end

    attr_accessor :clutch_pedal, :brake_pedal, :throttle_pedal,
                  :steering_wheel, :gear, :top_gear, :min_rpm, :max_rpm, :mode

    def initialize
      # note: when clutch_pedal == 0.0, gearbox.clutch == 1.0 (fully engaged)
      @clutch_pedal = 0.0   # to 1.0
      @brake_pedal = 0.0    # to 1.0
      @throttle_pedal = 0.0    # to 1.0
      @steering_wheel = 0.0 # -1.0 to +1.0
      @gear = 0             # neutral
      @top_gear = 6
      @min_rpm = 2000
      @max_rpm = 7000

      @mode = 0             # normal

      yield self if block_given?
    end

    def to_s
      [
        format("Clutch: %d%%  Brake: %d%%  Throttle: %d%%",
               @clutch_pedal * 100, @brake_pedal * 100, @throttle_pedal * 100),
        format("Wheel: %d%%  Gear: %d  Mode: %s",
               @steering_wheel * 100, @gear, @mode)
      ].join("\n")
    end

    # return :normal, :sport, :sport_plus based on pedal positions
    def pedal_mode
      if @brake_pedal < 0.4 and @throttle_pedal < 0.5
        0 # normal
      elsif @brake_pedal < 0.7 and @throttle_pedal < 0.8
        1 # sport
      else
        2 # sport_plus
      end
    end

    def rpm_range
      if @mode < 2 and self.pedal_mode == 2
        mode = @mode + 1
      elsif @mode == 2 and self.pedal_mode == 0
        mode = 1
      else
        mode = @mode
      end

      case mode
      when 0
        [@min_rpm, [@min_rpm + 3000, @max_rpm - 1000].min]
      when 1
        [@min_rpm + 1000, @max_rpm - 1000]
      when 2
        [@min_rpm + 1500, @max_rpm]
      end
    end

    def choose_gear!(rpm)
      min, max = *self.rpm_range

      if rpm < min and @gear > 1
        @gear -= 1
      elsif rpm > max and @gear < @top_gear
        @gear += 1
      end

      @gear
    end
  end
end
