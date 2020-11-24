require 'driving_physics/vector'
require 'driving_physics/tire'
require 'driving_physics/environment'

module DrivingPhysics
  F = DrivingPhysics::Vector::Force

  # treat instances of this class as immutable
  class Car
    attr_accessor :mass, :min_turn_radius,
                  :max_drive_force, :max_brake_clamp, :max_brake_force,
                  :fuel_capacity, :brake_pad_depth, :driver_mass,
                  :frontal_area, :cd,
                  :tires, :controls, :condition

    def initialize(environment)
      @environment = environment
      @mass             = 1000  # kg, without fuel or driver
      @min_turn_radius = 10     # meters
      @max_drive_force = 7000   # N - 1000kg car at 0.7g acceleration
      @max_brake_clamp = 100    # N
      @max_brake_force = 40_000 # N - 2000kg car at 2g braking
      @fuel_capacity   = 40     # L
      @brake_pad_depth = 10     # mm
      @driver_mass     = 75     # kg

      @frontal_area = Force::FRONTAL_AREA # m^2
      @cd = Force::DRAG_COF

      @tires = Tire.new
      @controls = Controls.new
      @condition = Condition.new(brake_temp: @environment.air_temp,
                                 brake_pad_depth: @brake_pad_depth)

      # consider downforce
      # probably area * angle
      # goes up with square of velocity

      yield self if block_given?
    end

    def to_s
      [[format("Mass: %.1f kg", total_mass),
        format("Power: %.1f kN", @max_drive_force.to_f / 1000),
        format("Brakes: %.1f kN", @max_brake_force.to_f / 1000),
        format("Fr.A: %.2f m^2", @frontal_area),
        format("cD: %.2f", @cd),
       ].join(' | '),
       [format("Net: %.1f N", sum_forces.magnitude),
        format("Drive: %d N", drive_force),
        format("Brake: %d N", brake_force),
        format("Air: %.1f N", air_resistance.magnitude),
        format("Rot: %.1f N", rotational_resistance.magnitude),
        format("Roll: %.1f N", rolling_resistance.magnitude),
       ].join(' | '),
        @controls, @condition, @tires,
      ].join("\n")
    end

    def tick!
      @condition.tick!(force: sum_forces,
                       mass: total_mass,
                       tire: @tires,
                       env: @environment)
      # TODO: base on tick and @fuel_consumption and @control.drive_pedal
      @condition.consume_fuel 0.0001
    end

    def drive_force
      @condition.fuel > 0.0 ? (@max_drive_force * @controls.drive_pedal) : 0.0
    end

    def drive_force_v
      @condition.dir * drive_force
    end

    def brake_force
      @max_brake_force * @controls.brake_pedal
    end

    def brake_force_v
      @condition.dir * brake_force
    end

    def fuel_mass
      @condition.fuel * @environment.petrol_density
    end

    def total_mass
      @mass + fuel_mass + @driver_mass
    end

    def weight
      total_mass * DrivingPhysics::G
    end

    def add_fuel(liters)
      sum = @condition.fuel + liters
      overflow = sum > @fuel_capacity ? sum - @fuel_capacity : 0
      @condition.add_fuel(liters - overflow)
      overflow
    end

    def air_resistance
      # use default air density for now
      F.air_resistance(@condition.vel,
                       frontal_area: @frontal_area,
                       drag_cof: @cd)
    end

    def rotational_resistance
      # uses default ROT_COF
      F.rotational_resistance(@condition.vel)
    end

    def rolling_resistance
      # TODO: downforce
      F.rolling_resistance(weight,
                           dir: @condition.vel != 0.0 ? @condition.vel : @dir,
                           roll_cof: @tires.roll_cof)
    end

    def sum_forces
      if @condition.vel == 0.0
        # resistance forces (incl. braking) can only oppose up to
        # any motivating force
        return Vector.zero(2) if drive_force <= brake_force
        net = drive_force - brake_force
        rr = rolling_resistance
        rrm = rr.magnitude
        net <= rrm ? Vector.zero(2) : (@condition.dir * net + rr)
      else
        # all resistance forces are fully summed, opposing velocity
        drive_force_v + brake_force_v +
          air_resistance + rotational_resistance + rolling_resistance
      end
    end

    class Controls
      attr_accessor :drive_pedal, :brake_pedal, :steering_wheel

      def initialize
        @drive_pedal = 0.0     # up to 1.0
        @brake_pedal = 0.0     # up to 1.0
        @steering_wheel = 0.0  # -1.0 to 1.0
      end

      def to_s
        [format("Throttle: %d%%", @drive_pedal * 100),
         format("Brake: %d%%", @brake_pedal * 100),
         format("Steering: %d%%", @steering_wheel * 100),
        ].join(" | ")
      end
    end

    class Condition
      attr_reader :dir, :pos, :vel, :acc, :fuel, :lat_g, :lon_g,
                  :wheelspeed, :brake_temp, :brake_pad_depth

      def initialize(dir: Vector.random_unit_vector,
                     brake_temp: DrivingPhysics::AMBIENT_TEMP,
                     brake_pad_depth: )
        @dir = dir
        @pos = ::Vector[0, 0]
        @vel = ::Vector[0, 0]
        @acc = ::Vector[0, 0]
        @fuel = 0.0   # L
        @lat_g = 0.0  # g
        @lon_g = 0.0  # g
        @wheelspeed = 0.0 # m/s (sliding when it differs from @speed)
        @brake_temp = brake_temp
        @brake_pad_depth = brake_pad_depth   # mm
      end

      def tick!(force:, mass:, tire:, env:)
        acc = DrivingPhysics.a(force, mass)
        if acc.magnitude > tire.max_g * env.g
          # sliding!
          # TODO: compute @wheelspeed and update tire with slide speed
          @acc = acc.normalize * tire.max_g  # e.g. traction control / ABS
          @wheelspeed = DrivingPhysics.v(@vel, acc, dt: env.tick).magnitude
          @vel = DrivingPhysics.v(@vel, @acc, dt: env.tick)
        else
          @acc = acc
          @vel = DrivingPhysics.v(@vel, @acc, dt: env.tick)
          @wheelspeed = @vel.magnitude
        end
        @pos = DrivingPhysics.p(@pos, @vel, dt: env.tick)
      end

      def add_fuel(liters)
        @fuel += liters
      end

      def consume_fuel(liters)
        @fuel -= liters
      end

      def speed
        @vel.magnitude
      end

      def slide_speed
        (speed - @wheelspeed).abs
      end

      def compass
        DrivingPhysics::Vector.compass_dir(@dir)
      end

      def to_s
        [[compass,
          format('P(%d, %d)', @pos[0], @pos[1]),
          format('V(%.1f, %.1f)', @vel[0], @vel[1]),
          format('A(%.2f, %.2f)', @acc[0], @acc[1]),
         ].join(' | '),
         [format('%.1f m/s', speed),
          format('LatG: %.2f', lat_g),
          format('LonG: %.2f', lon_g),
          format('Whl: %.1f m/s', @wheelspeed),
          format('Slide: %.1f m/s', slide_speed),
         ].join(' | '),
         [format('Brakes: %.1f C %.1f mm', @brake_temp, @brake_pad_depth),
          format('Fuel: %.2f L', @fuel),
         ].join(' | ')
        ].join("\n")
      end
    end
  end
end
