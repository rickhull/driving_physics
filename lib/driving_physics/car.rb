require 'driving_physics/vector'
require 'driving_physics/tire'

module DrivingPhysics
  F = DrivingPhysics::Vector::Force

  # treat instances of this class as immutable
  class Car
    attr_accessor :mass, :min_turn_radius,
                  :max_drive_force, :max_brake_clamp, :max_brake_force,
                  :fuel_capacity, :frontal_area, :cd,
                  :tires, :controls, :condition

    def initialize
      @mass = 1000              # kg, without fuel or driver
      @min_turn_radius = 10     # meters
      @max_drive_force = 7000   # N - 1000kg car at 0.7g acceleration
      @max_brake_clamp = 100    # N
      @max_brake_force = 40_000 # N - 2000kg car at 2g braking
      @fuel_capacity = 40       # L
      @frontal_area = Force::FRONTAL_AREA # m^2
      @cd = Force::DRAG_COF

      @tires = Tire.new
      @controls = Controls.new
      @condition = Condition.new

      # consider downforce
      # probably area * angle
      # goes up with square of velocity

      yield self if block_given?
    end

    def drive_force
      @condition.dir * @max_drive_force * @controls.drive_pedal
    end

    def brake_force
      @condition.dir * @max_brake_force * @controls.brake_pedal
    end

    def total_mass
      @mass + @condition.mass
    end

    def weight
      total_mass * DrivingPhysics::G
    end

    def air_resistance
      # use default air density for now
      F.air_resistance(@condition.vel,
                       frontal_area: @frontal_area,
                       drag_cof: @cd)
    end

    def rotational_resistance
      # use default ROT_COF
      F.rotational_resistance(@condition.vel)
    end

    def rolling_resistance
      # TODO: downforce
      F.rolling_resistance(weight, roll_cof: @tires.roll_cof)
    end

    class Controls
      attr_accessor :drive_pedal, :brake_pedal, :steering_wheel

      def initialize
        @drive_pedal = 0.0     # up to 1.0
        @brake_pedal = 0.0     # up to 1.0
        @steering_wheel = 0.0  # -1.0 to 1.0
      end
    end

    class Condition
      attr_reader :dir, :pos, :vel, :acc, :fuel,
                  :lat_g, :lon_g, :wheelspeed, :brake_temp, :pad_depth,
                  :driver_mass

      def initialize(unit_vector = Vector.random_unit_vector)
        @dir = unit_vector
        @pos = ::Vector[0, 0]
        @vel = ::Vector[0, 0]
        @acc = ::Vector[0, 0]
        @fuel = 0.0   # L
        @lat_g = 0.0  # g
        @lon_g = 0.0  # g
        @wheelspeed = 0.0 # m/s (sliding when it differs from @speed)
        @brake_temp = DrivingPhysics::AMBIENT_TEMP
        @pad_depth = 10   # mm
        @driver_mass = 75 # kg
      end

      def mass
        @fuel * DrivingPhysics::PETROL_DENSITY + @driver_mass
      end

      def speed
        @vel.magnitude
      end

      def slide_speed
        (speed - @wheelspeed).abs
      end
    end
  end
end
