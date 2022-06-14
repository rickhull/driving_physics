require 'driving_physics/disk'

module DrivingPhysics
  class Gearbox
    class Disengaged < RuntimeError; end

    RATIOS = [5r, 5/2r, 9/5r, 7/5r, 1r, 4/5r]
    REAR_END = 41/11r # 3.73

    attr_accessor :gear, :ratios, :rear_end, :rotating_mass, :fixed_mass

    def initialize(env)
      @ratios = RATIOS
      @rear_end = REAR_END
      @gear = 0 # neutral

      @rotating_mass = Disk.new(env) { |m|
        m.mass = 20
      }
      @fixed_mass = 30 # kg

      yield self if block_given?
    end

    def top_gear
      @ratios.length
    end

    def to_s
      "Gearbox: #{@ratios.inspect}"
    end

    def ratio(gear = nil)
      gear ||= @gear
      return 0 if gear == 0
      @ratios.fetch(gear - 1) * @rear_end
    end

    def axle_omega(crank_rpm)
      raise(Disengaged, "Cannot determine axle omega") if @gear == 0
      DrivingPhysics.omega(crank_rpm) / self.ratio
    end

    def crank_rpm(axle_omega)
      raise(Disengaged, "Cannot determine crank rpm") if @gear == 0
      DrivingPhysics.rpm(axle_omega) * self.ratio
    end

    def match_rpms(old_rpm, new_rpm)
      diff = new_rpm - old_rpm
      proportion = diff.to_f / old_rpm
      if proportion.abs < 0.01
        [:ok, proportion]
      elsif proportion.abs < 0.1
        [:slip, proportion]
      elsif @gear == 1 and new_rpm < old_rpm and old_rpm <= 1500
        [:get_rolling, proportion]
      else
        [:mismatch, proportion]
      end
    end

    def next_gear(rpm, floor: 2000, ceiling: 6800)
      if rpm < floor and @gear > 1
        @gear + 1
      elsif rpm > ceiling and @gear < self.top_gear
        @gear - 1
      else
        @gear
      end
    end
  end
end
