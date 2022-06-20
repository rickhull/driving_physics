module DrivingPhysics
  #
  # Units: metric
  #
  # distance: meter
  # velocity: meter / sec
  # acceleration: meter / sec^2
  # volume: Liter
  # temperature: Celsius
  #

  #
  # environmental defaults
  #
  HZ = 1000
  TICK = Rational(1) / HZ
  G = 9.8               # m/s^2
  AIR_TEMP = 25         # deg c
  AIR_DENSITY = 1.29    # kg / m^3
  PETROL_DENSITY = 0.71 # kg / L   TODO: move to car.rb

  #
  # defaults for resistance forces
  #
  FRONTAL_AREA = 2.2  # m^2, based roughly on 2000s-era Chevrolet Corvette
  DRAG_COF = 0.3      # based roughly on 2000s-era Chevrolet Corvette
  DRAG = 0.4257       # air_resistance at 1 m/s given above numbers
  ROT_COF = 12.771    # if rotating resistance matches air resistance at 30 m/s
  ROT_CONST = 0.05    # N opposing drive force / torque
  ROLL_COF = 0.01     # roughly: street tires on concrete

  #
  # constants
  #
  SECS_PER_MIN = 60
  MINS_PER_HOUR = 60
  SECS_PER_HOUR = SECS_PER_MIN * MINS_PER_HOUR

  # HH::MM::SS.mmm
  def self.elapsed_display(elapsed_ms)
    elapsed_s, ms = elapsed_ms.divmod 1000

    h = elapsed_s / SECS_PER_HOUR
    elapsed_s -= h * SECS_PER_HOUR
    m, s = elapsed_s.divmod SECS_PER_MIN

    [[h, m, s].map { |i| i.to_s.rjust(2, '0') }.join(':'),
     ms.to_s.rjust(3, '0')].join('.')
  end

  def self.kph(meters_per_sec)
    meters_per_sec.to_f * SECS_PER_HOUR / 1000
  end

  # acceleration; F=ma
  # force can be a scalar or a Vector
  def self.acc(force, mass)
    force / mass.to_f
  end

  # init and rate can be scalar or Vector but must match
  # this provides the general form for determining velocity and position
  def self.accum(init, rate, dt: TICK)
    init + rate * dt
  end

  class << self
    alias_method(:vel, :accum)
    alias_method(:pos, :accum)
    alias_method(:omega, :accum)
    alias_method(:theta, :accum)
  end
end

module DrivingPhysics
  class Environment
    attr_reader :hz, :tick
    attr_accessor :g, :air_temp, :air_density, :petrol_density

    def initialize
      self.hz = HZ
      @g = G
      @air_temp = AIR_TEMP
      @air_density = AIR_DENSITY
      @petrol_density = PETROL_DENSITY
    end

    def hz=(int)
      @hz = int
      @tick = Rational(1) / @hz
    end

    def to_s
      [format("Tick: %d Hz", @hz),
       format("G: %.2f m/s^2", @g),
       format("Air: %.1f C %.2f kg/m^3", @air_temp, @air_density),
       format("Petrol: %.2f kg/L", @petrol_density),
      ].join(" | ")
    end
  end
end

module DrivingPhysics

  # a Tire is a Disk with lighter density and meaningful surface friction

  class Tire < Disk
    # Note, this is not the density of solid rubber.  This density
    # yields a sensible mass for a wheel / tire combo at common radius
    # and width, assuming a uniform density
    # e.g. 25kg at 350mm R x 200mm W
    #
    DENSITY = 0.325  # kg / L

    # * the traction force opposes the axle torque / drive force
    #   thus, driving the car forward
    # * if the drive force exceeds the traction force, slippage occurs
    # * slippage reduces the available traction force further
    # * if the drive force is not reduced, the slippage increases
    #   until resistance forces equal the drive force
    def self.traction(normal_force, cof)
      normal_force * cof
    end

    attr_accessor :mu_s, :mu_k, :omega_friction, :base_friction, :roll_cof

    def initialize(env)
      @env = env
      @radius = 350/1000r # m
      @width  = 200/1000r # m
      @density = DENSITY
      @temp = @env.air_temp
      @mu_s = 11/10r # static friction
      @mu_k =  7/10r # kinetic friction
      @base_friction = 5/10_000r
      @omega_friction = 5/100_000r # scales with speed
      @roll_cof = DrivingPhysics::ROLL_COF

      yield self if block_given?
    end

    def to_s
      [[format("%d mm x %d mm (RxW)", @radius * 1000, @width * 1000),
        format("%.1f kg  %.1f C", self.mass, @temp),
        format("cF: %.1f / %.1f", @mu_s, @mu_k),
       ].join(" | "),
      ].join("\n")
    end

    def wear!(amount)
      @radius -= amount
    end

    def heat!(amount_deg_c)
      @temp += amount_deg_c
    end

    def traction(nf, static: true)
      self.class.traction(nf, static ? @mu_s : @mu_k)
    end

    # require a normal_force to be be passed in
    def rotating_friction(omega, normal_force:)
      super(omega, normal_force: normal_force)
    end

    # rolling loss in terms of axle torque
    def rolling_friction(omega, normal_force:)
      return omega if omega.zero?
      mag = omega.abs
      sign = omega / mag
      -1 * sign * (normal_force * @roll_cof) * @radius
    end

    # inertial loss in terms of axle torque when used as a drive wheel
    def inertial_loss(axle_torque, driven_mass:)
      drive_force = self.force(axle_torque)
      force_loss = 0
      # The force loss depends on the acceleration, but the acceleration
      # depends on the force loss.  Converge the value via 5 round trips.
      # This is a rough way to compute an integral and should be accurate
      # to 8+ digits.
      5.times {
        acc = DrivingPhysics.acc(drive_force - force_loss, driven_mass)
        alpha = acc / @radius
        force_loss = self.implied_torque(alpha) / @radius
      }
      force_loss * @radius
    end

    def net_torque(axle_torque, mass:, omega:, normal_force:)
      # friction forces oppose omega
      net = axle_torque +
            self.rolling_friction(omega, normal_force: normal_force) +
            self.rotating_friction(omega, normal_force: normal_force)

      # inertial loss has interdependencies; calculate last
      # it opposes net torque, not omega
      sign = net / net.abs
      net - sign * self.inertial_loss(net, driven_mass: mass)
    end

    def net_tractable_torque(axle_torque,
                             mass:, omega:, normal_force:, static: true)
      net = self.net_torque(axle_torque,
                            mass: mass,
                            omega: omega,
                            normal_force: normal_force)
      tt = self.tractable_torque(normal_force, static: static)
      net > tt ? tt : net
    end

    # this doesn't take inertial losses or internal frictional losses
    # into account.  input torque required to saturate traction will be
    # higher than what this method returns
    def tractable_torque(nf, static: true)
      traction(nf, static: static) * @radius
    end
  end
end

module DrivingPhysics
  class Motor
    class Stall < RuntimeError; end
    class OverRev < RuntimeError; end
    class SanityCheck < RuntimeError; end

    TORQUES = [  0,   70,  130,  200,  250,  320,  330,  320,  260,    0]
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]
    ENGINE_BRAKING = 0.2 # 20% of the torque at a given RPM

    attr_reader :env, :throttle
    attr_accessor :torques, :rpms, :fixed_mass,
                  :spinner, :starter_torque, :idle_rpm

    def initialize(env)
      @env = env

      @torques = TORQUES
      @rpms = RPMS
      @fixed_mass = 125

      # represent all rotating mass as one big flywheel
      @spinner = Disk.new(@env) { |fly|
        fly.radius =  0.25 # m
        fly.mass   = 75    # kg
        fly.base_friction  = 5/1000r
        fly.omega_friction = 2/10_000r
      }
      @starter_torque = 500  # Nm
      @idle_rpm       = 1000 # RPM
      @throttle       = 0.0  # 0.0 - 1.0 (0% - 100%)
    end

    def to_s
      ary = [format("Throttle: %.1f%%", @throttle * 100)]
      ary << "Torque:"
      @rpms.each_with_index { |r, i|
        ary << format("%s Nm %s RPM",
                      @torques[i].round(1).to_s.rjust(4, ' '),
                      r.to_s.rjust(5, ' '))
      }
      ary << format("Mass: %.1f kg  Fixed: %d kg", self.mass, @fixed_mass)
      ary << format("Rotating: %s", @spinner)
      ary.join("\n")
    end

    def rotational_inertia
      @spinner.rotational_inertia
    end

    def mass
      @spinner.mass + @fixed_mass
    end

    def throttle=(val)
      if val < 0.0 or val > 1.0
        raise(ArgumentError, "val #{val.inspect} should be between 0 and 1")
      end
      @throttle = val
    end

    # given torque, determine crank alpha after inertia and friction
    def alpha(torque, omega: 0)
      @spinner.alpha(torque + @spinner.rotating_friction(omega))
    end

    def implied_torque(alpha)
      @spinner.implied_torque(alpha)
    end

    # interpolate based on torque curve points
    def torque(rpm)
      raise(Stall, "RPM #{rpm}") if rpm < @rpms.first
      raise(OverRev, "RPM #{rpm}") if rpm > @rpms.last

      last_rpm, last_tq, torque = 99999, -1, nil

      @rpms.each_with_index { |r, i|
        tq = @torques[i]
        if last_rpm <= rpm and rpm <= r
          proportion = Rational(rpm - last_rpm) / (r - last_rpm)
          torque = last_tq + (tq - last_tq) * proportion
          break
        end
        last_rpm, last_tq = r, tq
      }
      raise(SanityCheck, "RPM #{rpm}") if torque.nil?

      if (@throttle <= 0.05) and (rpm > @idle_rpm * 1.5)
        # engine braking: 20% of torque
        -1 * torque * ENGINE_BRAKING
      else
        torque * @throttle
      end
    end
  end
end
module DrivingPhysics
  module CLI
    # returns user input as a string
    def self.prompt(msg = '')
      print msg + ' ' unless msg.empty?
      print '> '
      $stdin.gets.chomp
    end

    # press Enter to continue, ignore input, return elapsed time
    def self.pause(msg = '')
      t = Timer.now
      puts msg unless msg.empty?
      puts '     [ Press Enter ]'
      $stdin.gets
      Timer.since(t)
    end
  end

  module Timer
    if defined? Process::CLOCK_MONOTONIC
      def self.now
        Process.clock_gettime Process::CLOCK_MONOTONIC
      end
    else
      def self.now
        Time.now
      end
    end

    def self.since(t)
      self.now - t
    end

    def self.elapsed(&work)
      t = self.now
      return yield, self.since(t)
    end

    # HH:MM:SS.mmm
    def self.display(seconds: 0, ms: 0)
      ms += (seconds * 1000).round if seconds > 0
      DrivingPhysics.elapsed_display(ms)
    end

    def self.summary(start, num_ticks, paused = 0)
      elapsed = self.since(start) - paused
      format("%.3f s (%d ticks/s)", elapsed, num_ticks.to_f / elapsed)
    end
  end
end

module DrivingPhysics
  # radius is always in meters
  # force in N
  # torque in Nm

  # Rotational complements to acc/vel/pos
  # alpha - angular acceleration (radians / s / s)
  # omega - angular velocity (radians / s)
  # theta - radians

  # convert radians to revolutions; works for alpha/omega/theta
  def self.revs(rads)
    rads / (2 * Math::PI)
  end

  # convert revs to rads; works for alpha/omega/theta
  def self.rads(revs)
    revs * 2 * Math::PI
  end

  # convert rpm to omega (rads / s)
  def self.omega(rpm)
    self.rads(rpm / 60.0)
  end

  # convert omega to RPM (revs per minute)
  def self.rpm(omega)
    self.revs(omega) * 60
  end

  class Disk
    DENSITY = 1.0 # kg / L

    # torque = force * distance
    def self.force(axle_torque, radius)
      axle_torque / radius.to_f
    end

    # in m^3
    def self.volume(radius, width)
      Math::PI * radius ** 2 * width
    end

    # in L
    def self.volume_l(radius, width)
      volume(radius, width) * 1000
    end

    def self.density(mass, volume_l)
      mass.to_f / volume_l
    end

    def self.mass(radius, width, density)
      volume_l(radius, width) * density
    end

    # I = 1/2 (m)(r^2) for a disk
    def self.rotational_inertia(radius, mass)
      mass * radius**2 / 2.0
    end
    class << self
      alias_method(:moment_of_inertia, :rotational_inertia)
    end

    # angular acceleration
    def self.alpha(torque, inertia)
      torque / inertia
    end

    # convert alpha/omega/theta to acc/vel/pos
    def self.tangential(rotational, radius)
      rotational * radius
    end

    # convert acc/vel/pos to alpha/omega/theta
    def self.rotational(tangential, radius)
      tangential.to_f / radius
    end

    # vectors only
    def self.torque_vector(force, radius)
      if !force.is_a?(Vector) or force.size != 2
        raise(ArgumentError, "force must be a 2D vector")
      end
      if !radius.is_a?(Vector) or radius.size != 2
        raise(ArgumentError, "radius must be a 2D vector")
      end
      force = Vector[force[0], force[1], 0]
      radius = Vector[radius[0], radius[1], 0]
      force.cross(radius)
    end

    # vectors only
    def self.force_vector(torque, radius)
      if !torque.is_a?(Vector) or torque.size != 3
        raise(ArgumentError, "torque must be a 3D vector")
      end
      if !radius.is_a?(Vector) or radius.size != 2
        raise(ArgumentError, "radius must be a 2D vector")
      end
      radius = Vector[radius[0], radius[1], 0]
      radius.cross(torque) / radius.dot(radius)
    end

    attr_reader :env
    attr_accessor :radius, :width, :density, :base_friction, :omega_friction

    def initialize(env)
      @env = env
      @radius  = 350/1000r # m
      @width   = 200/1000r # m
      @density = DENSITY
      @base_friction  = 5/100_000r  # constant resistance to rotation
      @omega_friction = 5/100_000r  # scales with omega
      yield self if block_given?
    end

    def to_s
      [[format("%d mm x %d mm (RxW)", @radius * 1000, @width * 1000),
        format("%.1f kg  %.2f kg/L", self.mass, @density),
       ].join(" | "),
      ].join("\n")
    end

    def normal_force
      @normal_force ||= self.mass * @env.g
      @normal_force
    end

    def alpha(torque, omega: 0, normal_force: nil)
      (torque - self.rotating_friction(omega, normal_force: normal_force)) /
        self.rotational_inertia
    end

    def implied_torque(alpha)
      alpha * self.rotational_inertia
    end

    def mass
      self.class.mass(@radius, @width, @density)
    end

    def mass=(val)
      @density = self.class.density(val, self.volume_l)
      @normal_force = nil # force update
    end

    # in m^3
    def volume
      self.class.volume(@radius, @width)
    end

    # in L
    def volume_l
      self.class.volume_l(@radius, @width)
    end

    def rotational_inertia
      self.class.rotational_inertia(@radius, self.mass)
    end
    alias_method(:moment_of_inertia, :rotational_inertia)

    def force(axle_torque)
      self.class.force(axle_torque, @radius)
    end

    def tangential(rotational)
      self.class.tangential(rotational, @radius)
    end

    # modeled as a tiny but increasing torque opposing omega
    # also scales with normal force
    # maybe not physically faithful but close enough
    def rotating_friction(omega, normal_force: nil)
      return omega if omega.zero?
      normal_force = self.normal_force if normal_force.nil?
      mag = omega.abs
      sign = omega / mag
      -1 * sign * normal_force * (@base_friction + mag * @omega_friction)
    end
  end
end

module DrivingPhysics
  # Technically speaking, the gear ratio goes up with speed and down with
  # torque.  But in the automotive world, it's customary to invert the
  # relationship, where a bigger number means more torque and less speed.
  # We'll store the truth, where the default final drive would be
  # conventionally known as 3.73, but 1/3.73 will be stored.

  # The gear ratio (above 1) multiplies speed and divides torque
  # 5000 RPM is around 375 MPH with a standard wheel/tire
  # 3.73 final drive reduces that to around 100 mph in e.g. 5th gear (1.0)
  # Likewise, 1st gear is a _smaller_ gear ratio than 3rd
  class Gearbox
    class Disengaged < RuntimeError; end

    RATIOS = [1/5r, 2/5r, 5/9r, 5/7r, 1r, 5/4r]
    FINAL_DRIVE = 11/41r # 1/3.73

    attr_accessor :gear, :ratios, :final_drive, :spinner, :fixed_mass

    def initialize(env)
      @ratios = RATIOS
      @final_drive = FINAL_DRIVE
      @gear = 0 # neutral

      # represent all rotating mass
      @spinner = Disk.new(env) { |m|
        m.radius = 0.15
        m.base_friction = 5/1000r
        m.omega_friction = 15/100_000r
        m.mass = 15
      }
      @fixed_mass = 30 # kg

      yield self if block_given?
    end

    # given torque, apply friction, determine alpha
    def alpha(torque, omega: 0)
      @spinner.alpha(torque + @spinner.rotating_friction(omega))
    end

    def rotating_friction(omega)
      @spinner.rotating_friction(omega)
    end

    def implied_torque(alpha)
      @spinner.implied_torque(alpha)
    end

    def mass
      @fixed_mass + @spinner.mass
    end

    def top_gear
      @ratios.length
    end

    def to_s
      [format("Ratios: %s", @ratios.inspect),
       format(" Final: %s  Mass: %.1f kg  Rotating: %.1f kg",
              @final_drive.inspect, self.mass, @spinner.mass),
      ].join("\n")
    end

    def ratio(gear = nil)
      gear ||= @gear
      raise(Disengaged, "Cannot determine gear ratio") if @gear == 0
      @ratios.fetch(gear - 1) * @final_drive
    end

    def axle_torque(crank_torque)
      crank_torque / self.ratio
    end

    def axle_omega(crank_rpm)
      DrivingPhysics.omega(crank_rpm) * self.ratio
    end

    def crank_rpm(axle_omega)
      DrivingPhysics.rpm(axle_omega) / self.ratio
    end

    def match_rpms(old_rpm, new_rpm)
      diff = new_rpm - old_rpm
      proportion = diff.to_f / old_rpm
      if proportion.abs < 0.01
        [:ok, proportion]
      elsif proportion.abs < 0.1
        [:slip, proportion]
      elsif @gear == 1 and new_rpm < old_rpm and old_rpm <= 1500
        [:get_rolling, proportion]
      else
        [:mismatch, proportion]
      end
    end

    def next_gear(rpm, floor: 2500, ceiling: 6400)
      if rpm < floor and @gear > 1
        @gear - 1
      elsif rpm > ceiling and @gear < self.top_gear
        @gear + 1
      else
        @gear
      end
    end
  end
end

module DrivingPhysics
  module Imperial
    FEET_PER_METER = 3.28084
    FEET_PER_MILE = 5280
    MPH = (FEET_PER_METER / FEET_PER_MILE) * SECS_PER_HOUR
    CI_PER_LITER = 61.024
    GAL_PER_LITER = 0.264172
    PS_PER_KW = 1.3596216173039

    def self.feet(meters)
      meters * FEET_PER_METER
    end

    def self.meters(feet)
      feet / FEET_PER_METER
    end

    def self.miles(meters = nil, km: nil)
      raise(ArgumentError, "argument missing") if meters.nil? and km.nil?
      meters ||= km * 1000
      meters * FEET_PER_METER / FEET_PER_MILE
    end

    def self.mph(mps = nil, kph: nil)
      raise(ArgumentError, "argument missing") if mps.nil? and kph.nil?
      mps ||= kph.to_f * 1000 / SECS_PER_HOUR
      MPH * mps
    end

    def self.mps(mph)
      mph / MPH
    end

    def self.kph(mph)
      DP::kph(mps(mph))
    end

    # convert kilowatts to horsepower
    def self.ps(kw)
      kw * PS_PER_KW
    end

    def self.deg_c(deg_f)
      (deg_f - 32).to_f * 5 / 9
    end

    def self.deg_f(deg_c)
      deg_c.to_f * 9 / 5 + 32
    end

    def self.cubic_inches(liters)
      liters * CI_PER_LITER
    end

    def self.liters(ci = nil, gallons: nil)
      raise(ArgumentError, "argument missing") if ci.nil? and gallons.nil?
      return ci / CI_PER_LITER if gallons.nil?
      gallons.to_f / GAL_PER_LITER
    end

    def self.gallons(liters)
      liters * GAL_PER_LITER
    end
  end
end

module DrivingPhysics
  class Car
    attr_reader :tire, :powertrain, :env
    attr_accessor :num_tires, :body_mass, :frontal_area, :cd

    def initialize(tire:, powertrain:)
      @num_tires = 4
      @tire = tire
      @env = @tire.env
      @powertrain = powertrain
      @body_mass = 1000.0
      @frontal_area = DrivingPhysics::FRONTAL_AREA
      @cd = DrivingPhysics::DRAG_COF

      yield self if block_given?
    end

    def throttle
      @powertrain.motor.throttle
    end

    def throttle=(val)
      @powertrain.motor.throttle = val
    end

    def gear
      @powertrain.gearbox.gear
    end

    def gear=(val)
      @powertrain.gearbox.gear = val
    end

    def top_gear
      @powertrain.gearbox.top_gear
    end

    # force opposing speed
    def air_force(speed)
      -0.5 * @frontal_area * @cd * @env.air_density * speed ** 2
    end

    # force of opposite sign to omega
    def tire_rolling_force(omega)
      @num_tires *
        @tire.rolling_friction(omega, normal_force: self.normal_force) /
        @tire.radius
    end

    # force of opposite sign to omega
    def tire_rotational_force(omega)
      @num_tires *
        @tire.rotating_friction(omega, normal_force: self.normal_force) /
        @tire.radius
    end

    # force of opposite sign to force
    def tire_inertial_force(force)
      mag = force.abs
      sign = force / mag
      force_loss = 0
      5.times {
        # use magnitude, so we are subtracting only positive numbers
        acc = DrivingPhysics.acc(mag - force_loss, self.total_mass)
        alpha = acc / @tire.radius
        # this will be a positive number
        force_loss = @num_tires * @tire.implied_torque(alpha) /
                     @tire.radius
      }
      # oppose initial force
      -1 * sign * force_loss
    end

    def to_s
      [[format("Mass: %.1f kg", self.total_mass),
        format("Fr.A: %.2f m^2", @frontal_area),
        format("cD: %.2f", @cd),
       ].join(' | '),
       format("POWERTRAIN:\n%s", @powertrain),
       format("Tires: %s", @tire),
       format("Corner mass: %.1f kg | Normal force: %.1f N",
              self.corner_mass, self.normal_force),
      ].join("\n")
    end

    def drive_force(rpm)
      @tire.force(@powertrain.axle_torque(rpm))
    end

    def tire_speed(rpm)
      @tire.tangential(@powertrain.axle_omega(rpm))
    end

    def motor_rpm(tire_speed)
      @powertrain.gearbox.crank_rpm(tire_speed / @tire_radius)
    end

    def total_mass
      @body_mass + @powertrain.mass + @tire.mass * @num_tires
    end

    def corner_mass
      Rational(self.total_mass) / @num_tires
    end

    # per tire
    def normal_force
      self.corner_mass * @env.g
    end

    # per tire
    def tire_traction
      @tire.traction(self.normal_force)
    end

    def total_normal_force
      self.total_mass * env.g
    end
  end
end

module DrivingPhysics
  # Powertrain right now is pretty simple.  It combines the motor with the
  # gearbox.  It is focused on operations that require or involve both
  # components. It does not pass through operations to the motor or gearbox.
  # Instead, it provides direct access to each component.
  #
  class Powertrain
    attr_reader :motor, :gearbox

    def initialize(motor, gearbox)
      @motor = motor
      @gearbox = gearbox
    end

    def mass
      @motor.mass + @gearbox.mass
    end

    def to_s
      ["\t[MOTOR]", @motor, "\t[GEARBOX]", @gearbox].join("\n")
    end

    # returns [power, torque, omega]
    def output(rpm)
      t, o = self.axle_torque(rpm), self.axle_omega(rpm)
      [t * o, t, o]
    end

    def axle_torque(rpm)
      crank_alpha = @motor.alpha(@motor.torque(rpm),
                                 omega: DrivingPhysics.omega(rpm))
      crank_torque = @motor.implied_torque(crank_alpha)

      axle_alpha = @gearbox.alpha(@gearbox.axle_torque(crank_torque),
                                  omega: @gearbox.axle_omega(rpm))
      @gearbox.implied_torque(axle_alpha)
    end

    def axle_omega(rpm)
      @gearbox.axle_omega(rpm)
    end

    def crank_rpm(axle_omega)
      @gearbox.crank_rpm(axle_omega)
    end
  end
end

module DrivingPhysics
  module ScalarForce
    #
    # Resistance Forces
    #
    # 1. air resistance aka drag aka turbulent drag
    #    depends on v^2
    # 2. "rotatational" resistance, e.g. bearings / axles / lubricating fluids
    #    aka viscous drag; linear with v
    # 3. rolling resistance, e.g. tire and surface deformation
    #    constant with v, depends on normal force and tire/surface properties
    # 4. braking resistance, supplied by operator, constant with v
    #    depends purely on operator choice and physical limits
    #    as such, it is not modeled here
    #
    # Note: here we only consider speed; we're in a 1D world for now
    #

    # opposes the direction of speed
    def self.air_resistance(speed,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY)
      -1 * 0.5 * frontal_area * drag_cof * air_density * speed ** 2
    end

    # opposes the direction of speed
    def self.rotational_resistance(speed, rot_cof: ROT_COF)
      -1 * speed * rot_cof
    end

    # opposes the direction of speed
    # normal force is not always mass * G, e.g. aero downforce
    def self.rolling_resistance(normal_force, roll_cof: ROLL_COF)
      -1 * normal_force * roll_cof
    end

    #
    # convenience methods
    #

    def self.speed_resistance(speed,
                              frontal_area: FRONTAL_AREA,
                              drag_cof: DRAG_COF,
                              air_density: AIR_DENSITY,
                              rot_cof: ROT_COF)
      air_resistance(speed,
                     frontal_area: frontal_area,
                     drag_cof: drag_cof,
                     air_density: air_density) +
        rotational_resistance(speed, rot_cof: rot_cof)
    end

    def self.all_resistance(speed,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY,
                            rot_cof: ROT_COF,
                            nf_mag:,
                            roll_cof: ROLL_COF)
      speed_resistance(speed,
                       frontal_area: frontal_area,
                       drag_cof: drag_cof,
                       air_density: air_density,
                       rot_cof: rot_cof) +
        rolling_resistance(nf_mag, roll_cof: roll_cof)
    end
  end
end

# Work is Force * Distance   (Torque * Theta)
# W = F * s  (W = T * Th)
# W = T * Theta

# Power is Work / time
# P = W / dt
# P = T * Th / dt
# P = T * Omega

module DrivingPhysics
  def self.work(force, displacement)
    force * displacement
  end

  def self.power(force, speed)
    force * speed
  end
end

module DrivingPhysics
  # compatibility for Vector#zero? in Ruby 2.4.x
  unless Vector.method_defined?(:zero?)
    module VectorZeroBackport
      refine Vector do
        def zero?
          all?(&:zero?)
        end
      end
    end
    using VectorZeroBackport
  end

  # e.g. given 5, yields a uniformly random number from -5 to +5
  def self.random_centered_zero(magnitude)
    m = [magnitude.abs, 1].max
    Random.rand(m * 2 + 1) - m
  end

  def self.random_unit_vector(dimensions = 2, resolution: 9)
    begin
      v = Vector.elements(Array.new(dimensions) {
                            random_centered_zero(resolution)
                          })
    end while v.zero?
    v.normalize
  end

  def self.rot_90(vec, clockwise: true)
    raise(Vector::ZeroVectorError) if vec.zero?
    raise(ArgumentError, "vec should be size 2") unless vec.size == 2
    clockwise ? Vector[vec[1], -1 * vec[0]] : Vector[-1 * vec[1], vec[0]]
  end

  # +,0 E
  # 0,+ N
  # .9,.1 ENE
  # .1,.9 NNE
  #
  def self.compass_dir(unit_vector)
    horz = case
           when unit_vector[0] < -0.001 then 'W'
           when unit_vector[0] > 0.001 then 'E'
           else ''
           end

    vert = case
           when unit_vector[1] < -0.001 then 'S'
           when unit_vector[1] > 0.001 then 'N'
           else ''
           end

    dir = [vert, horz].join
    if dir.length == 2
      # detect and include bias
      if (unit_vector[0].abs - unit_vector[1].abs).abs > 0.2
        bias = unit_vector[0].abs > unit_vector[1].abs ? horz : vert
        dir = [bias, dir].join
      end
    end
    dir
  end

  module VectorForce
    #
    # Resistance Forces
    #
    # 1. air resistance aka drag aka turbulent drag
    #    depends on v^2
    # 2. "rotatational" resistance, e.g. bearings / axles / lubricating fluids
    #    aka viscous drag; linear with v
    # 3. rolling resistance, e.g. tire and surface deformation
    #    constant with v, depends on normal force and tire/surface properties
    # 4. braking resistance, supplied by operator, constant with v
    #    depends purely on operator choice and physical limits
    #    as such, it is not modeled here
    #

    # velocity is a vector; return value is a force vector
    def self.air_resistance(velocity,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY)
      return velocity if velocity.zero?
      -1 * 0.5 * frontal_area * drag_cof * air_density *
       velocity * velocity.magnitude
    end

    # return a force opposing velocity, representing friction / hysteresis
    def self.rotational_resistance(velocity,
                                   rot_const: ROT_CONST,
                                   rot_cof: ROT_COF)
      return velocity if velocity.zero?
      -1 * velocity * rot_cof + -1 * velocity.normalize * rot_const
    end

    # return a torque opposing omega, representing friction / hysteresis
    def self.omega_resistance(omega,
                              rot_const: ROT_TQ_CONST,
                              rot_cof: ROT_TQ_COF)
      return 0 if omega == 0.0
      omega * ROT_TQ_COF + ROT_TQ_CONST
    end

    # dir is drive_force vector or velocity vector; will be normalized
    # normal_force is a magnitude, not a vector
    #
    def self.rolling_resistance(nf_mag, dir:, roll_cof: ROLL_COF)
      return dir if dir.zero? # don't try to normalize a zero vector
      nf_mag = nf_mag.magnitude if nf_mag.is_a? Vector
      -1 * dir.normalize * roll_cof * nf_mag
    end

    #
    # convenience methods
    #

    def self.velocity_resistance(velocity,
                                 frontal_area: FRONTAL_AREA,
                                 drag_cof: DRAG_COF,
                                 air_density: AIR_DENSITY,
                                 rot_cof: ROT_COF)
      air_resistance(velocity,
                     frontal_area: frontal_area,
                     drag_cof: drag_cof,
                     air_density: air_density) +
        rotational_resistance(velocity, rot_cof: rot_cof)
    end

    def self.all_resistance(velocity,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY,
                            rot_cof: ROT_COF,
                            dir:,
                            nf_mag:,
                            roll_cof: ROLL_COF)
      velocity_resistance(velocity,
                          frontal_area: frontal_area,
                          drag_cof: drag_cof,
                          air_density: air_density,
                          rot_cof: rot_cof) +
        rolling_resistance(nf_mag, dir: dir, roll_cof: roll_cof)
    end
  end
end
