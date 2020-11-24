require 'driving_physics/car'

include DrivingPhysics

env = Environment.new
car = Car.new(env)
car.add_fuel 10
duration = 150 # seconds

puts "ENV - #{env}"
puts
puts car

car.controls.drive_pedal = 1.0

(duration * env.ticks_per_sec).times { |i|
  car.tick!
  if i % env.ticks_per_sec == 0
    if car.sum_forces.magnitude < 0.05
      car.controls.drive_pedal = 0.0
      car.controls.brake_pedal = 1.0
    end
    puts
    puts "t = #{i / env.ticks_per_sec}"
    puts car
    gets
  end
}
