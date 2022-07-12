require 'driving_physics/pid_controller.rb'
require 'driving_physics/motor'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new { |e| e.hz = 100 }
motor = Motor.new(env)
puts env
puts motor
puts

CLI.pause

alpha = 0.0
omega = 0.0
theta = 0.0

duration = 3600

status = :ignition
rpm = 0

paused = 0.0
num_ticks = duration * env.hz + 1
start = Timer.now

# maintain 1000 RPM
pidc = PIDController.new(motor.idle, dt: env.tick)
pidc.output_range = (0.0..1.0)
pidc_error = 0.0

num_ticks.times { |i|
  torque = case status
           when :ignition
             motor.starter_torque
           when :running
             motor.torque(rpm)
           else
             0
           end

  alpha = motor.alpha(torque, omega: omega)
  omega += alpha * env.tick
  theta += omega * env.tick

  net_torque = motor.implied_torque(alpha)
  rpm = DrivingPhysics.rpm(omega)

  if status == :ignition
    if rpm > motor.idle
      status = :running
    end
  end

  if status == :running
    motor.throttle = pidc.update(rpm)
    pidc_error += pidc.error.abs
  end

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

  if error_pct < 0.02 or i % 10 == 0
    next if status == :ignition and i % 10 != 0
    loop {
      puts "Enter > setpoint kp ki kd  " +
           "Current: #{pidc.setpoint} #{pidc.kp} #{pidc.ki} #{pidc.kd}"
      print "> "
      str = $stdin.gets.chomp
      break if str.empty?
      parts = str.split(' ')
      next unless parts.size == 4
      begin
        setpoint, kp, ki, kd = *parts.map { |s| s.strip.to_f }
      rescue e
        puts e
        next
      end
      p [setpoint, kp, ki, kd]
      pidc.setpoint = setpoint
      pidc.kp = kp
      pidc.ki = ki
      pidc.kd = kd
      pidc_error = 0.0
      break
    }
  end
}
