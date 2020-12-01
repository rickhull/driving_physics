require 'driving_physics/environment'
require 'driving_physics/vector_force'
require 'driving_physics/tire'

module DrivingPhysics
  # treat instances of this class as immutable
  class Car
    attr_accessor :mass, :min_turn_radius,
                  :max_drive_force, :max_brake_clamp, :max_brake_force,
                  :fuel_capacity, :brake_pad_depth, :driver_mass,
                  :frontal_area, :cd, :fuel_consumption,
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
      @fuel_consumption = 0.02  # L/s at full throttle

      @frontal_area = DrivingPhysics::FRONTAL_AREA # m^2
      @cd = DrivingPhysics::DRAG_COF

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
       [format("Op: %d N", drive_force - brake_force),
        format("Drive: %d N", drive_force),
        format("Brake: %d N", brake_force),
       ].join(' | '),
       [format("Net: %.1f N", sum_forces.magnitude),
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

      @condition.consume_fuel(@fuel_consumption *
                              @controls.drive_pedal *
                              @environment.tick)
    end

    def drive_force
      @condition.fuel > 0.0 ? (@max_drive_force * @controls.drive_pedal) : 0.0
    end

    def drive_force_vector
      @condition.dir * drive_force
    end

    def brake_force
      @max_brake_force * @controls.brake_pedal
    end

    def brake_force_vector
      -1 * @condition.movement_dir * brake_force
    end

    def fuel_mass
      @condition.fuel * @environment.petrol_density
    end

    def total_mass
      @mass + fuel_mass + @driver_mass
    end

    def weight
      total_mass * @environment.g
    end

    def add_fuel(liters)
      sum = @condition.fuel + liters
      overflow = sum > @fuel_capacity ? sum - @fuel_capacity : 0
      @condition.add_fuel(liters - overflow)
      overflow
    end

    def air_resistance
      # use default air density for now
      VectorForce.air_resistance(@condition.vel,
                                 frontal_area: @frontal_area,
                                 drag_cof: @cd)
    end

    def rotational_resistance
      # uses default ROT_COF
      VectorForce.rotational_resistance(@condition.vel)
    end

    def rolling_resistance
      # TODO: downforce
      VectorForce.rolling_resistance(weight,
                                     dir: @condition.movement_dir,
                                     roll_cof: @tires.roll_cof)
    end

    def applied_force
      drive_force_vector + brake_force_vector
    end

    def natural_force
      air_resistance + rotational_resistance + rolling_resistance
    end

    def sum_forces
      applied_force + natural_force
    end

    class Controls
      attr_reader :drive_pedal, :brake_pedal, :steering_wheel

      def initialize
        @drive_pedal = 0.0     # up to 1.0
        @brake_pedal = 0.0     # up to 1.0
        @steering_wheel = 0.0  # -1.0 to 1.0
      end

      def drive_pedal=(flt)
        @drive_pedal = flt.clamp(0.0, 1.0)
      end

      def brake_pedal=(flt)
        @brake_pedal = flt.clamp(0.0, 1.0)
      end

      def steering_wheel=(flt)
        @steering_wheel = steering_wheel.clamp(-1.0, 1.0)
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

      def initialize(dir: DrivingPhysics.random_unit_vector,
                     brake_temp: AIR_TEMP,
                     brake_pad_depth: )
        @dir = dir  # maybe rename to @heading ?
        @pos = Vector[0, 0]
        @vel = Vector[0, 0]
        @acc = Vector[0, 0]
        @fuel = 0.0   # L
        @lat_g = 0.0  # g
        @lon_g = 0.0  # g
        @wheelspeed = 0.0 # m/s (sliding when it differs from @speed)
        @brake_temp = brake_temp
        @brake_pad_depth = brake_pad_depth   # mm
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

      # left is negative, right is positive
      def lat_dir
        DrivingPhysics.rot_90(@dir, clockwise: true)
      end

      # note, we might be moving backwards, so not always @dir
      # and we can't normalize a zero vector if we're not moving
      def movement_dir
        (speed == 0.0) ? @dir : @vel.normalize
      end

      def tick!(force:, mass:, tire:, env:)
        # take the longitudinal component of the force, relative to vel dir
        vel_dir = @vel.zero? ? @dir : @vel.normalize
        lon_force = force.dot(vel_dir)
        @wheelspeed = nil

        if lon_force < 0.0
          is_stopping = true
          if @vel.zero?
            @acc = Vector[0,0]
            @wheelspeed = 0.0
            @lon_g = 0.0

            # TODO: update any other physical vars
            return
          end
        else
          is_stopping = false
        end

        # now detect sliding
        nominal_acc = DrivingPhysics.a(force, mass)
        init_v = @vel

        if nominal_acc.magnitude > tire.max_g * env.g
          nominal_v = DrivingPhysics.v(nominal_acc, @vel, dt: env.tick)

          # check for reversal of velocity; could be wheelspin while
          # moving backwards, so can't just look at is_stopping
          if nominal_v.dot(@vel) < 0 and is_stopping
            @wheelspeed = 0.0
          else
            @wheelspeed = nominal_v.magnitude
          end
          @acc = nominal_acc.normalize * tire.max_g * env.g
        else
          @acc = nominal_acc
        end

        @vel = DrivingPhysics.v(@acc, @vel, dt: env.tick)
        @wheelspeed ||= @vel.magnitude

        # finally, detect velocity reversal when stopping
        if is_stopping and @vel.dot(init_v) < 0
          puts "crossed zero; stopping!"
          @vel = Vector[0, 0]
          @wheelspeed = 0.0
          @lon_g = 0.0
        end

        @lon_g = @acc.dot(@dir) / env.g
        @pos = DrivingPhysics.p(@vel, @pos, dt: env.tick)
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
        DrivingPhysics.compass_dir(@dir)
      end
    end
  end
end
