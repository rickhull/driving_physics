require 'device_control'
require 'driving_physics/motor'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new { |e|
  e.hz = CLI.prompt("What frequency?", default: 1000).to_i
}
motor = Motor.new(env)
puts env
puts motor
puts

# maintain arbitrary RPM via throttle adjustment
pidc = DeviceControl::PIDController.new(motor.idle, dt: env.tick) { |p|
  p.kp = 3.0
  p.ki = 0.0
  p.kd = 0.0
  p.p_range = (-1.00..1.00)
  p.i_range = (-0.50..0.50)
  p.d_range = (-0.25..0.25)
  p.o_range = ( 0.00..1.00)
}
# track the accumulated absolute error
pidc_error = 0.0

puts pidc
puts

throttle_step = CLI.prompt("What throttle step?", default: 0.1).to_f
smoother = DeviceControl::Smoother.new(max_step: throttle_step)

alpha = 0.0
omega = 0.0

duration = 3600
rpm = 0
status = :ignition

(duration * env.hz + 1).times { |i|
  puts Timer.display(seconds: i.to_f / env.hz)

  # GIVEN:
  # * rpm
  # DETERMINE:
  # * torque
  # * new rpm

  case status
  when :ignition
    torque = motor.starter_torque
    puts "IGNITION: Starter torque %d Nm  %d RPM" % [torque, rpm]
    status = :running if rpm > motor.idle
  when :running
    torque = motor.torque(rpm)
    puts format("RUNNING: %.1f Nm @ %d RPM  Throttle: %s",
                torque, rpm.round, motor.throttle_pct(3))
    puts pidc
    puts "Absolute error %.3f" % pidc_error
  end

  # update kinematics
  alpha = motor.alpha(torque, omega: omega)
  omega += alpha * env.tick
  rpm = DrivingPhysics.rpm(omega)

  puts format("Net Torque: %+.4f Nm   Friction: %+.4f Nm",
              motor.implied_torque(alpha),
              motor.friction(omega))

  # Finally, update throttle position and RPM
  # Throttle position is based on PID controller
  # PID controller looks at current RPM
  # Update to the new RPM at the very end of the loop

  case status
  when :ignition
    # ok
  when :running
    motor.throttle = smoother.update(pidc.update(rpm))
    pidc_error += pidc.error.abs
    error_pct = pidc.error.abs / pidc.setpoint.to_f

    # prompt every so often
    if (error_pct < 0.005 or
        (i < 100 and i % 10 == 0) or
        (i < 1_000 and i % 100 == 0) or
        (i < 10_000 and i % 100 == 0) or
        (i % 1000 == 0)
      # ask about PID tunables; loop until an acceptable answer
      loop {
        puts
        puts format("rpm %.1f\tsetpoint %d\tkp %s\tki %s\tkd %s",
                    rpm, pidc.setpoint, pidc.kp, pidc.ki, pidc.kd)
        str = CLI.prompt("Enter key and value, e.g. > setpoint 3500\n")
        # empty answer is perfectly acceptable; exit the loop
        break if str.empty?

        # look for "key value" pairs
        parts = str.split(' ').map(&:strip)
        next unless parts.size == 2
        begin
          key, val = parts[0].downcase, parts[1].to_f
        rescue e
          puts e
          next
        end

        # update RPM or PID controller and exit the loop
        if key == "rpm"
          rpm = val
          omega = DrivingPhysics.omega(rpm)
        else
          pidc.send("#{key}=", val)
          pidc_error = 0.0
        end
        puts
        break
      }
    end
  end
  puts
}
