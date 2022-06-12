require 'driving_physics/car'

DP = DrivingPhysics

env = DP::Environment.new
car = DP::Car.new(env)
car.add_fuel 10
duration = 120 # seconds

puts env
puts
puts car

car.controls.drive_pedal = 1.0

(duration * env.hz).times { |i|
  car.tick!
  if i % env.hz == 0
    if car.sum_forces.magnitude < 1
      car.controls.drive_pedal = 0.0
      car.controls.brake_pedal = 1.0
    end
    puts
    puts "[t = #{i / env.hz}]"
    puts car
    gets if i % (env.hz * 10) == 0
  end
}
