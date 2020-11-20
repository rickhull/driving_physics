require 'driving_physics'
require 'driving_physics/tire'

module DrivingPhysics
  # treat instances of this class as immutable
  class Car
    attr_accessor :mass, :min_turn_radius, :drive_force, :brake_force, :tire

    def initialize
      @mass = 1000          # kg, without fuel or driver
      @min_turn_radius = 10 # meters
      @drive_force = 7000   # N - 1000kg car at 0.7g acceleration
      @brake_force = 40_000 # N - 2000kg car at 2g braking
      @tire = Tire.new
      @fuel_capacity = 40   # L

      yield self if block.given?
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
      def initialize
        @fuel = 0.0   # L
        @speed = 0.0  # m/s
        @lat_g = 0.0  # g
        @lon_g = 0.0  # g
        @wheelspeed = 0.0 # m/s (sliding when it differs from @speed)
        @brake_temp = DrivingPhysics::AMBIENT_TEMP
        @pad_depth = 10 # mm
      end

      def slide_speed
        Math.abs(@speed - @wheelspeed)
      end
    end
  end
end
