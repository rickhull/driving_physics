require 'driving_physics/tire'
require 'driving_physics'

include DrivingPhysics

t = Tire.new

# drive time
mins = 45

drive_map = {
  acc: {
    label: "ACCELERATING",
    g: 0.4,
    fuel: 0.0002, # kg consumed / tick
    small_slide: 1, # m/s of wheelspin
    big_slide: 10,
    seconds: 5,
    next_sector: :brake,
  },
  brake: {
    label: "BRAKING",
    g: 1.0,
    fuel: 0.00001,
    small_slide: 0.5,
    big_slide: 2,
    seconds: 2,
    next_sector: :corner,
  },
  corner: {
    label: "CORNERING",
    g: 0.9,
    fuel: 0.0001,
    small_slide: 0.5,
    big_slide: 5,
    seconds: 3,
    next_sector: :acc,
  },
}

slide_speed = 0
sliding = false
mass = 900.0
ambient_temp = 25

drive_time = 0   # how many ticks elapsed in the current sector
sector_map = drive_map[:acc]
puts "ACCELERATING"
puts "---"

# 100 ticks / sec
(mins * 60 * 100).times { |i|
  drive_time += 1

  if drive_time >= sector_map[:seconds] * 100
    sector_map = drive_map[sector_map[:next_sector]]
    drive_time = 0
    puts
    puts sector_map[:label]
    puts '---'
  end


  if sliding
    # 5% chance to end the slide
    if Random.rand(100) >= 95
      puts "CAUGHT THE SLIDE!"
      sliding = false
      slide_speed = 0
    end
  else
    # 1% chance to start a small slide
    # 0.1% chance to start a big slide
    if Random.rand(100) >= 99
      puts "SMALL SLIDE!"
      sliding = true
      slide_speed = sector_map[:small_slide]
    elsif Random.rand(1000) >= 999
      puts "BIG SLIDE!"
      sliding = true
      slide_speed = sector_map[:big_slide]
    end
  end

  # fuel consumption
  # 5L of fuel should last 5 minutes
  # ~3.5 kg of fuel consumption
  # 1.2e-4 kg / tick
  mass -= sector_map[:fuel]

  begin
    t.condition.tick!(ambient_temp: ambient_temp, g: sector_map[:g],
                      slide_speed: slide_speed,
                      mass: mass, tire_mass: 12, critical_temp: 100)

    puts t.condition.temp_c if i % 10 == 0
    if i % 600 == 0
      puts
      puts "Mass: #{'%.2f' % mass} kg"
      if t.condition.tread_mm > 0
        puts "Tread remaining: #{'%.3f' % t.condition.tread_mm}"
      else
        puts "Cords remaining: #{'%.3f' % t.condition.cords_mm}"
      end
      puts DrivingPhysics.elapsed_display(i * 10)
      puts "[Enter] to continue"
      gets
    end
  rescue Tire::Condition::DestructionError => e
    puts e.message
    break
  end
}
