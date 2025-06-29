module DrivingPhysics
  # A high-performance, high-precision linear interpolation method.
  # xs must be sorted, with ys dependent on xs (same size).
  # Return interpolated y for any given x.
  def self.interpolate(x, xs:, ys:)
    # Guard Clauses: handle errors and out-of-range values first
    raise("Xs and Ys must have the same size") unless xs.size == ys.size
    return ys.first if x <= xs.first
    return ys.last  if x >= xs.last

    # Binary Search: find the upper bound of the segment containing x
    upper_idx = xs.bsearch_index { |xi| xi > x }

    # Upper Bound: if no xs > x, x must be the last item
    return ys.last if upper_idx.nil?

    # Lower Bound: one below, maybe zero but non-negative
    lower_idx = upper_idx - 1

    # Match Lower Bound: quick return
    return ys[lower_idx] if xs[lower_idx] == x

    # Interpolate!
    last_x, last_y = xs[lower_idx], ys[lower_idx]
    next_x, next_y = xs[upper_idx], ys[upper_idx]
    last_y + (next_y - last_y) * Rational(x - last_x) / (next_x - last_x)
  end

  class TorqueCurve
    # at 500 RPM, 0 torque.  1000 RPM = 70 Nm. 7000, redline.  7100, cutoff
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]
    TORQUES = [  0,   70,  130,  200,  250,  320,  330,  320,  260,    0]

    def self.validate_rpms!(rpms)
      raise("rpms should be positive") if rpms.any? { |r| r < 0 }
      rpms.each.with_index { |r, i|
        if i > 0 and r <= rpms[i-1]
          raise("rpms #{rpms.inspect} should increase")
        end
      }
      rpms
    end

    def self.validate_torques!(torques)
      raise("first torque should be zero") unless torques.first == 0
      raise("last torque should be zero") unless torques.last == 0
      raise("torques should be positive") if torques.any? { |t| t < 0 }
      torques
    end

    def initialize(rpms: RPMS, torques: TORQUES)
      if rpms.size != torques.size
        raise("RPMs size #{rpms.size}; Torques size #{torques.size}")
      end
      @rpms = self.class.validate_rpms! rpms
      @torques = self.class.validate_torques! torques
      peak_torque = 0
      idx = 0
      @torques.each.with_index { |t, i|
        if t > peak_torque
          peak_torque = t
          idx = i
        end
      }
      @peak = idx
    end

    def peak
      [@rpms[@peak], @torques[@peak]]
    end

    def to_s
      @rpms.map.with_index { |r, i|
        format("%s RPM %s Nm",
               r.to_s.rjust(5, ' '),
               @torques[i].round(1).to_s.rjust(4, ' '))
      }.join("\n")
    end

    { min: 0,
      idle: 1,
      redline: -2,
      max: -1,
    }.each { |name, idx|
      define_method(name) do @rpms[idx] end
    }

    # interpolate based on torque curve points
    def torque(rpm)
      DrivingPhysics.interpolate(rpm, xs: @rpms, ys: @torques)
    end
  end
end
