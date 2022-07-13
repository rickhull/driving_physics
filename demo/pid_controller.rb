require 'driving_physics/pid_controller.rb'
require 'driving_physics/motor'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new { |e|
  e.hz = CLI.prompt("What frequency?", default: 100).to_i
}
motor = Motor.new(env)
puts env
puts motor
puts

# maintain arbitrary RPM
pidc = PIDController.new(motor.idle, dt: env.tick) { |p|
  p.output_range = (0.0..1.0) # throttle
  p.kp = 0.75
  p.ki = 0.05
  p.kd = 0.0075
}
pidc_error = 0.0

puts pidc
puts

CLI.pause

alpha = 0.0
omega = 0.0
theta = 0.0

duration = 3600
rpm = 0
status = :ignition

(duration * env.hz + 1).times { |i|
  case status
  when :ignition
    status = :running if rpm > motor.idle
    torque = motor.starter_torque
  when :running
    motor.throttle = pidc.update(rpm)
    pidc_error += pidc.error.abs
    torque = motor.torque(rpm)
  end

  alpha = motor.alpha(torque, omega: omega)
  omega += alpha * env.tick
  theta += omega * env.tick

  net_torque = motor.implied_torque(alpha)
  rpm = DrivingPhysics.rpm(omega)

  puts Timer.display(seconds: i.to_f / env.hz)
  puts format("Throttle: %.1f%%", motor.throttle * 100)
  puts format("%d RPM  %.1f Nm (%.1f Nm)  Friction: %.1f Nm",
              DrivingPhysics.rpm(omega),
              net_torque,
              torque,
              motor.spinner.rotating_friction(omega))
  puts pidc
  puts "Absolute error %.3f" % pidc_error
  puts

  error_pct = pidc.error.abs / pidc.setpoint.to_f

  # prompt every so often
  if error_pct < 0.02 or i % 10 == 0
    next if status == :ignition and i % 10 != 0
    loop {
      puts
      str = CLI.prompt("Enter key and value, e.g. > setpoint 3500\n")
      break if str.empty?
      parts = str.split(' ')
      next unless parts.size == 2
      begin
        key, val = *parts.map { |s| s.strip.to_f }
      rescue e
        puts e
        next
      end
      p [key, val]
      pidc.send("#{key}=", val)
      pidc_error = 0.0
      break
    }
  end
}
