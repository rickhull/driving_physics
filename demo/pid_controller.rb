require 'driving_physics/motor'
require 'driving_physics/cli'
require 'driving_physics/power'
require 'driving_physics/pid_controller.rb'

include DrivingPhysics

env = Environment.new
motor = Motor.new(env)
puts env
puts motor
puts

puts "* Spin the motor up to #{motor.idle} RPM with the starter motor."
puts "* Rev it up with the throttle."
puts "* Let it die."
CLI.pause

alpha = 0.0
omega = 0.0
theta = 0.0

duration = 60

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
           when :running, :off_throttle, :idling
             motor.torque(rpm)
           else
             0
           end

  alpha = motor.alpha(torque, omega: omega)
  omega += alpha * env.tick
  theta += omega * env.tick

  net_torque = motor.implied_torque(alpha)
  rpm = DrivingPhysics.rpm(omega)
  power = DrivingPhysics.power(net_torque, omega)

  if status == :ignition
    if rpm > motor.idle
      status = :running
      flag = true
      pidc.setpoint = motor.redline
    end
  end

  if status == :running
    if rpm < pidc.setpoint
      motor.throttle = pidc.update(rpm)
    else
      status = :off_throttle
      motor.throttle = 0.0
      flag = true
      pidc.setpoint = motor.idle
    end
  end

  if status == :off_throttle
    if rpm <= 1001
      status = :idling
      flag = true
    end
  end

  if status == :idling
    pidc_error += (rpm - pidc.setpoint).abs
    motor.throttle = pidc.update(rpm)
  end

  if flag or
    (i < 10) or
    (i < 100 and i % 10 == 0) or
    (i < 1000 and i % 100 == 0) or
    (i < 10_000 and i % 500 == 0) or
    (i % 5000 == 0) or
    (status == :idling and i % 100 == 0)
    puts Timer.display(ms: i)
    puts format("Throttle: %.1f%%", motor.throttle * 100)
    puts format("%d RPM  %.1f Nm (%d Nm)  %.1f kW   Friction: %.1f Nm",
                DrivingPhysics.rpm(omega),
                net_torque,
                torque,
                power / 1000,
                motor.spinner.rotating_friction(omega))

    if [:idling, :running].include?(status)
      puts pidc
      puts "Total error %.3f" % pidc_error if status == :idling
    end
    puts

    paused += CLI.pause if flag
    flag = false
  end
}

puts Timer.summary(start, num_ticks, paused)
