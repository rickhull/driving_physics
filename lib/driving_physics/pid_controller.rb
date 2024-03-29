module DrivingPhysics
  # we will have a control loop
  # SP    - setpoint, this is the desired position
  # PV(t) - process variable, this is the sensed position, varying over time
  #  e(t) - error, SP - PV
  # CV(t) - control variable: the controller output

  # for example, where to set the throttle to maintain 1000 RPM
  # SP - 1000 RPM
  # PV - current RPM
  # CV - throttle position

  class PIDController
    HZ = 1000
    TICK = Rational(1) / HZ

    # Ziegler-Nichols method for tuning PID gain knobs
    ZN = {
      #            Kp     Ti     Td     Ki     Kd
      #     Var:   Ku     Tu     Tu    Ku/Tu  Ku*Tu
      'P'  =>   [0.500],
      'PI' =>   [0.450, 0.800,   nil, 0.540],
      'PD' =>   [0.800,   nil, 0.125,   nil, 0.100],
      'PID' =>  [0.600, 0.500, 0.125, 1.200, 0.075],
      'PIR' =>  [0.700, 0.400, 0.150, 1.750, 0.105],
      # less overshoot than standard PID below
      'some' => [0.333, 0.500, 0.333, 0.666, 0.111],
      'none' => [0.200, 0.500, 0.333, 0.400, 0.066],
    }

    # ultimate gain, oscillation
    def self.tune(type, ku, tu)
      record = ZN[type.downcase] || ZN[type.upcase] || ZN.fetch(type)
      kp, ti, td, ki, kd = *record
      kp *= ku if kp
      ti *= tu if ti
      td *= tu if td
      ki *= (ku / tu) if ki
      kd *= (ku * tu) if kd
      { kp: kp, ti: ti, td: td, ki: ki, kd: kd }
    end

    attr_accessor :kp, :ki, :kd, :dt, :setpoint,
                  :p_range, :i_range, :d_range, :o_range
    attr_reader :measure, :error, :last_error, :sum_error

    def initialize(setpoint, dt: TICK)
      @setpoint, @dt, @measure = setpoint, dt, 0.0

      # track error over time for integral and derivative
      @error, @last_error, @sum_error = 0.0, 0.0, 0.0

      # gain / multipliers for PID; tunables
      @kp, @ki, @kd = 1.0, 1.0, 1.0

      # optional clamps for PID terms and output
      @p_range = (-Float::INFINITY..Float::INFINITY)
      @i_range = (-Float::INFINITY..Float::INFINITY)
      @d_range = (-Float::INFINITY..Float::INFINITY)
      @o_range = (-Float::INFINITY..Float::INFINITY)

      yield self if block_given?
    end

    def update(measure)
      self.measure = measure
      self.output
    end

    def measure=(val)
      @measure = val
      @last_error = @error
      @error = @setpoint - @measure
      if @error * @last_error <= 0  # zero crossing; reset the accumulated error
        @sum_error = @error
      else
        @sum_error += @error
      end
    end

    def output
      (self.proportion +
       self.integral +
       self.derivative).clamp(@o_range.begin, @o_range.end)
    end

    def proportion
      (@kp * @error).clamp(@p_range.begin, @p_range.end)
    end

    def integral
      (@ki * @sum_error * @dt).clamp(@i_range.begin, @i_range.end)
    end

    def derivative
      (@kd * (@error - @last_error) / @dt).clamp(@d_range.begin, @d_range.end)
    end

    def to_s
      [format("Setpoint: %.3f  Measure: %.3f",
              @setpoint, @measure),
       format("Error: %+.3f\tLast: %+.3f\tSum: %+.3f",
              @error, @last_error, @sum_error),
       format(" Gain:\t%.3f\t%.3f\t%.3f",
              @kp, @ki, @kd),
       format("  PID:\t%+.3f\t%+.3f\t%+.3f\t= %.5f",
              self.proportion, self.integral, self.derivative, self.output),
      ].join("\n")
    end
  end
end
