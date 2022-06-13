require 'driving_physics'

module DrivingPhysics
  class Gearbox
    class Disengaged < RuntimeError; end

    RATIOS = [5r, 5/2r, 9/5r, 7/5r, 1r, 4/5r]
    REAR_END = 41/11r # 3.73

    attr_reader :gear
    attr_accessor :rear_end

    def initialize(*ratios)
      @ratios = ratios.empty? ? RATIOS : ratios
      @ratios.each { |r|
        raise(InputError, r.inspect) unless 0 < r and r < 99999
      }
      @rear_end = REAR_END
      @gear = 0 # neutral

      yield self if block_given?
    end

    def disengage!
      @gear = 0
    end

    def disengaged?
      @gear == 0
    end
    alias_method(:neutral?, :disengaged?)

    def top_gear
      @ratios.length
    end

    def upshift!
      raise(NoUpshift, "already in top gear") if @gear == self.top_gear
      @gear += 1
    end

    def downshift!
      raise(NoDownshift, "already in first gear") if @gear == 1
      @gear -= 1
    end

    def to_s
      "Gearbox: #{@ratios.inspect}"
    end

    # does not allow neutral / disengage
    def gear=(val)
      raise("bad gear: #{val.inspect}") unless @ratios[val - 1]
      @gear = val
    end

    def ratio(gear = nil)
      self.gear = gear unless gear.nil?
      return 0 if self.neutral?
      @ratios[@gear - 1] * @rear_end
    end

    def axle_omega(crank_rpm)
      raise(Disengaged, "cannot determine axle omega") if self.disengaged?
      DrivingPhysics.omega(crank_rpm) / self.ratio
    end

    def crank_rpm(axle_omega)
      raise(Disengaged, "Cannot determine crank rpm") if self.disengaged?
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

    def shift!(rpm, below: 2000, above: 6800)
      if rpm < below and @gear > 1
        self.downshift!
      elsif rpm > above and @gear < self.top_gear
        self.upshift!
      end
    end
  end
end
