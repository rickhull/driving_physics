require 'driving_physics/cli'

module DrivingPhysics
  # we will have a control loop
  # SP    - setpoint, this is the desired position
  # PV(t) - process variable, this is the sensed position, varying over time
  #  e(t  - error, SP - PV
  # CV(t) (or MV) - manipulated (or control) variable: the controller output

  # for example, where to set the throttle to maintain 1000 RPM
  # SP - 1000 RPM
  # PV - current RPM
  # CV - throttle position

  class PIDC
    HZ = 30
    TICK = Rational(1) / HZ

    attr_accessor :kp, :ki, :kd, :dt, :setpoint, :integral_range, :output_range
    attr_reader :measure, :error, :last_error, :sum_error

    def initialize(setpoint, dt = TICK)
      @setpoint, @dt = setpoint, dt

      # gain / multipliers for PID; tunables
      @kp, @ki, @kd = 0.9, 0.05, 0.05

      # tracking error over time for integral and derivative
      @error, @sum_error = 0.0, 0.0

      # these require an initial measurement
      @measure, @last_error, @error_sign = nil, nil, nil

      # optional clamps for integral term and output
      @integral_range = (-Float::INFINITY..Float::INFINITY)
      @output_range = (-Float::INFINITY..Float::INFINITY)

      yield self if block_given?
    end

    def to_s
      ary = [format("Setpoint: #{@setpoint.abs < 0.1 ? '%.3f' : '%.1f'}  ",
                    @setpoint) +
             format("Error: %.1f  Last: %.1f  Sum: %.1f",
                    @error, @last_error, @sum_error),
             format("Gain: %.1f  %.1f  %.2f", @kp, @ki, @kd),
             format(" PID: %.2f  %.2f  %.2f",
                    self.proportion, self.integral, self.derivative),
            ]
      ary[0] << '  ' + format("Measure: %.3f", @measure) if @measure
      ary.join("\n")
    end

    def measure=(val)
      @measure = val
      @last_error = @error
      @error = (@setpoint - @measure) / @setpoint.to_f
      if @error * @last_error > 0
        @sum_error += @error
      else
        # sign change!
        @sum_error = @error
      end
    end

    def update(measure)
      self.measure = measure
      self.output
    end

    def proportion
      @kp * @error
    end

    def integral
      (@ki * @sum_error).clamp(@integral_range)
    end

    def derivative
      return 0 if @last_error.nil?
      @kd * (@error - @last_error) / @dt
    end

    def output
      (self.proportion + self.integral + self.derivative).clamp(@output_range)
    end
  end
end
