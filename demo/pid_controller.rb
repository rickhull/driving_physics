require 'device_control'
require 'driving_physics/motor'
require 'driving_physics/cli'

include DrivingPhysics

env = Environment.new { |e|
  e.hz = CLI.prompt("What frequency? (Hz)", default: 1000).to_i
}
motor = Motor.new(env)
puts env
puts motor
puts


PID = DeviceControl::PIDController
models = PID::ZN.keys.join('  ')

puts "PID models: #{models}"
pid_model = CLI.prompt("What PID model?", default: 'none')

# Ku for 1000 RPM idle has been measured at 8.0
# Tu is 1000 Hz / 2
zn = PID.tune(pid_model, 8.0, 1/500r)
puts format("kp: %.3f\tki: %.1f\tkd: %.8f", zn[:kp], zn[:ki], zn[:kd])
puts

# maintain arbitrary RPM via throttle adjustment
pidc = DeviceControl::PIDController.new(motor.idle, dt: env.tick) { |p|
  p.kp = zn[:kp]
  p.ki = zn[:ki]
  p.kd = zn[:kd]
  p.p_range = (-1.00..1.00)
  p.i_range = (-0.50..0.50)
  p.d_range = (-0.25..0.25)
  p.o_range = ( 0.00..1.00)
  p.e_range = (-1.00..1.00)
}
# track the accumulated absolute error
pidc_error = 0.0

puts pidc
puts

duration = CLI.prompt("How long to run for? (seconds)", default: 2).to_f
CLI.pause

alpha = 0.0
omega = 0.0

rpm = 0
status = :ignition

(duration * env.hz + 1).to_i.times { |i|
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

  # Update throttle position and RPM
  # Throttle position is based on PID controller
  # PID controller looks at current RPM
  # Update to the new RPM at the very end of the loop

  case status
  when :ignition
    # ok
    CLI.pause if i % 50 == 0
  when :running
    motor.throttle = pidc.update(rpm)
    pidc_error += pidc.error.abs
    error_pct = pidc.error.abs / pidc.setpoint.to_f

    # prompt every so often
    if (error_pct < 0.00001) or
      (i < 10_000 and i % 100 == 0) or
      (i % 1000 == 0)
      # ask about PID tunables; loop until an acceptable answer
      loop {
        puts
        puts format("rpm %.1f\tsetpoint %d\tkp %.3f\tki %.3f\tkd %.3f",
                    rpm, pidc.setpoint, pidc.kp, pidc.ki, pidc.kd)
        str = CLI.prompt("Enter key and value, e.g. > setpoint 3500\n")
        # empty answer is perfectly acceptable; exit the loop
        break if str.empty?

        # look for "key value" pairs
        parts = str.split(' ').map(&:strip)
        next unless parts.size == 2
        begin
          key, val = parts[0].downcase, parts[1].to_f
        rescue => e
          puts e
          next
        end

        # update RPM or PID controller and exit the loop
        if key == "rpm"
          rpm = val
          omega = DrivingPhysics.omega(rpm)
        else
          begin
            pidc.send("#{key}=", val)
          rescue => e
            puts e
            next
          end
          pidc_error = 0.0
        end
        puts
        break
      }
    end
  end
  puts
}
