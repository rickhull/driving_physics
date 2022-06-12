require 'driving_physics/car'

include DrivingPhysics

env = Environment.new
puts env

car = Car.new(wheel: Wheel.new(env), powertrain: Powertrain.new(1000)) { |c|
  c.mass = 1050.0
  c.frontal_area = 2.5
  c.cd = 0.5
}

puts car
