require 'driving_physics/tire'

module DrivingPhysics
  # treat instances of this class as immutable
  class Car
    attr_accessor :mass, :min_turn_radius, :tire, :power

    def initialize
      @mass = 1000 # kg, without fuel or driver
      @min_turn_radius = 10 # meters
      @tire = Tire.new
      @max_power = 250 # kW, generates less acceleration for higher velocities
      # braking?

      yield self if block.given?
    end
  end
end
