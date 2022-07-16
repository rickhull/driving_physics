#
# Units: metric
#
# distance: meter
# velocity: meter / sec
# acceleration: meter / sec^2
# volume: Liter
# temperature: Celsius
#
module DrivingPhysics
  # runtime check; this returns false by default
  # Vector is not currently/easily available in mruby
  def self.has_vector?
    Vector rescue false
  end

  # environmental defaults
  HZ = 1000
  TICK = Rational(1) / HZ
  G = 9.8               # m/s^2
  AIR_TEMP = 25         # deg c
  AIR_DENSITY = 1.29    # kg / m^3
  PETROL_DENSITY = 0.71 # kg / L

  # defaults for resistance forces
  FRONTAL_AREA =  2.2    # m^2, based roughly on 2000s-era Chevrolet Corvette
  DRAG_COF     =  0.3    # based roughly on 2000s-era Chevrolet Corvette
  DRAG         =  0.4257 # air_resistance at 1 m/s given above numbers
  ROT_COF      = 12.771  # if rot matches air at 30 m/s
  ROT_CONST    =  0.05   # N opposing drive force / torque
  ROLL_COF     =  0.01   # roughly: street tires on concrete

  # constants
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

  def self.unit_interval!(val)
    if val < 0.0 or val > 1.0
      raise(ArgumentError, "val #{val.inspect} should be between 0 and 1")
    end
    val
  end
end

module DrivingPhysics
  module CLI
    # returns user input as a string
    def self.prompt(msg = '', default: nil)
      print "#{msg} " unless msg.empty?
      print "(#{default}) " unless default.nil?
      print '> '
      input = $stdin.gets.chomp
      input.empty? ? default.to_s : input
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

      yield self if block_given?
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
  module Timer
    # don't use `defined?` with mruby
    if (Process::CLOCK_MONOTONIC rescue false)
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
#require 'driving_physics/vector_force'

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

    attr_reader :env
    attr_accessor :radius, :width, :density, :base_friction, :omega_friction

    def initialize(env)
      @env = env
      @radius  = 0.35
      @width   = 0.2
      @density = DENSITY
      @base_friction  = 5.0/100_000  # constant resistance to rotation
      @omega_friction = 5.0/100_000  # scales with omega
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

    # E = (1/2) (I) (omega^2)
    def energy(omega)
      0.5 * self.rotational_inertia * omega ** 2
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
      @radius = 0.35
      @width  = 0.2
      @density = DENSITY
      @temp = @env.air_temp
      @mu_s = 1.1 # static friction
      @mu_k = 0.7 # kinetic friction
      @base_friction = 5.0/10_000
      @omega_friction = 5.0/100_000
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
  def self.interpolate(x, xs:, ys:)
    raise("Xs size #{xs.size}; Ys size #{ys.size}") unless xs.size == ys.size
    raise("#{x} out of range") if x < xs.first or x > xs.last
    xs.each.with_index { |xi, i|
      return ys[i] if x == xi
      if i > 0
        last_x, last_y = xs[i-1], ys[i-1]
        raise("xs out of order (#{xi} <= #{last_x})") unless xi > last_x
        if x <= xi
          proportion = Rational(x - last_x) / (xi - last_x)
          return last_y + (ys[i] - last_y) * proportion
        end
      end
    }
    raise("couldn't find #{x} in #{xs.inspect}") # sanity check
  end

  class TorqueCurve
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]
    TORQUES = [  0,   70,  130,  200,  250,  320,  330,  320,  260,    0]
    RPM_IDX = {
      min: 0,
      idle: 1,
      redline: -2,
      max: -1,
    }

    def self.validate_rpms!(rpms)
      raise("rpms should be positive") if rpms.any? { |r| r < 0 }
      rpms.each.with_index { |r, i|
        if i > 0 and r <= rpms[i-1]
          raise("rpms #{rpms.inspect} should increase")
        end
      }
      rpms
    end

    def self.validate_torques!(torques)
      raise("first torque should be zero") unless torques.first == 0
      raise("last torque should be zero") unless torques.last == 0
      raise("torques should be positive") if torques.any? { |t| t < 0 }
      torques
    end

    def initialize(rpms: RPMS, torques: TORQUES)
      if rpms.size != torques.size
        raise("RPMs size #{rpms.size}; Torques size #{torques.size}")
      end
      @rpms = self.class.validate_rpms! rpms
      @torques = self.class.validate_torques! torques
      peak_torque = 0
      idx = 0
      @torques.each.with_index { |t, i|
        if t > peak_torque
          peak_torque = t
          idx = i
        end
      }
      @peak = idx
    end

    def peak
      [@rpms[@peak], @torques[@peak]]
    end

    def to_s
      @rpms.map.with_index { |r, i|
        format("%s RPM %s Nm",
               r.to_s.rjust(5, ' '),
               @torques[i].round(1).to_s.rjust(4, ' '))
      }.join("\n")
    end

    RPM_IDX.each { |name, idx| define_method(name) do @rpms[idx] end }

    # interpolate based on torque curve points
    def torque(rpm)
      DrivingPhysics.interpolate(rpm, xs: @rpms, ys: @torques)
    end
  end

  # represent all rotating mass as one big flywheel
  class Motor
    class Stall < RuntimeError; end
    class OverRev < RuntimeError; end

    CLOSED_THROTTLE = 0.01 # threshold for engine braking
    ENGINE_BRAKING = 0.2   # 20% of the torque at a given RPM

    attr_reader :env, :torque_curve, :throttle
    attr_accessor :fixed_mass, :spinner, :starter_torque

    # Originally, torque_curve was a kwarg; but mruby currently has a bug
    # where block_given? returns true in the presence of an unset default
    # kwarg, or something like that.
    # https://github.com/mruby/mruby/issues/5741
    #
    def initialize(env, torque_curve = nil)
      @env          = env
      @torque_curve = torque_curve.nil? ? TorqueCurve.new : torque_curve
      @throttle     = 0.0  # 0.0 - 1.0 (0% - 100%)

      @fixed_mass = 125
      @spinner = Disk.new(@env) { |fly|
        fly.radius =  0.25 # m
        fly.mass   = 75    # kg
        fly.base_friction  = 1.0 /   1_000
        fly.omega_friction = 5.0 / 100_000
      }
      @starter_torque = 500  # Nm

      yield self if block_given?
    end

    def redline
      @torque_curve.redline
    end

    def idle
      @torque_curve.idle
    end

    def to_s
      peak_rpm, peak_tq = *@torque_curve.peak
      [format("Peak Torque: %d Nm @ %d RPM  Redline: %d",
              peak_tq, peak_rpm, @torque_curve.redline),
       format("   Throttle: %s  Mass: %.1f kg  (%d kg fixed)",
              self.throttle_pct, self.mass, @fixed_mass),
       format("   Rotating: %s", @spinner),
      ].join("\n")
    end

    def inertia
      @spinner.rotational_inertia
    end

    def energy(omega)
      @spinner.energy(omega)
    end

    def friction(omega, normal_force: nil)
      @spinner.rotating_friction(omega, normal_force: normal_force)
    end

    def mass
      @spinner.mass + @fixed_mass
    end

    def rotating_mass
      @spinner.mass
    end

    def throttle=(val)
      @throttle = DrivingPhysics.unit_interval! val
    end

    def throttle_pct(places = 1)
      format("%.#{places}f%%", @throttle * 100)
    end

    # given torque, determine crank alpha considering inertia and friction
    def alpha(torque, omega: 0)
      @spinner.alpha(torque + @spinner.rotating_friction(omega))
    end

    def implied_torque(alpha)
      @spinner.implied_torque(alpha)
    end

    def output_torque(rpm)
      self.implied_torque(self.alpha(self.torque(rpm),
                                     omega: DrivingPhysics.omega(rpm)))
    end

    # this is our "input torque" and it depends on @throttle
    # here is where engine braking is implemented
    def torque(rpm)
      raise(Stall, "RPM #{rpm}") if rpm < @torque_curve.min
      raise(OverRev, "RPM #{rpm}") if rpm > @torque_curve.max

      # interpolate based on torque curve points
      torque = @torque_curve.torque(rpm)

      if (@throttle <= CLOSED_THROTTLE) and (rpm > @torque_curve.idle * 1.5)
        # engine braking: 20% of torque
        -1 * torque * ENGINE_BRAKING
      else
        torque * @throttle
      end
    end
  end
end


# TODO: starter motor
# Starter motor is power limited, not torque limited
# Consider:
# * 2.2 kW (3.75:1 gear reduction)
# * 1.8 kW  (4.4:1 gear reduction)
# On a workbench, a starter will draw 80 to 90 amps. However, during actual
# start-up of an engine, a starter will draw 250 to 350 amps.
# from https://www.motortrend.com/how-to/because-theres-more-to-a-starter-than-you-realize/

# V - Potential, voltage
# I - Current, amperage
# R - Resistance, ohms
# P - Power, wattage

# Ohm's law: I = V / R (where R is held constant)
# P = I * V
# For resistors (where R is helod constant)
#   = I^2 * R
#   = V^2 / R


# torque proportional to A
# speed proportional to V


# batteries are rated in terms of CCA - cold cranking amps

# P = I * V
# V = 12 (up to 14ish)
# I = 300
# P = 3600 or 3.6 kW


# A starter rated at e.g. 2.2 kW will use more power on initial cranking
# Sometimes up to 500 amperes are required, and some batteries will provide
# over 600 cold cranking amps


# Consider:

# V = 12
# R = resistance of battery, wiring, starter motor
# L = inductance (approx 0)
# I = current through motor
# Vc = proportional to omega

# rated power - Vc * I
# input power - V * I
# input power that is unable to be converted to output power is wasted as heat

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
    class ClutchDisengage < Disengaged; end

    RATIOS = [1/5r, 2/5r, 5/9r, 5/7r, 1r, 5/4r]
    FINAL_DRIVE = 11/41r # 1/3.73
    REVERSE = -1
    REVERSE_RATIO = -1/10r

    attr_accessor :ratios, :final_drive, :spinner, :fixed_mass
    attr_reader :gear, :clutch

    def self.gear_interval!(gear, min: REVERSE, max:)
      if gear < min or gear > max
        raise(ArgumentError, format("gear %s should be between %d and %d",
                                    gear.inspect, min, max))
      end
      raise(ArgumentError, "gear should be an integer") if !gear.is_a? Integer
      gear
    end

    def initialize(env)
      @ratios = RATIOS
      @final_drive = FINAL_DRIVE
      @gear = 0     # neutral
      @clutch = 1.0 # fully engaged (clutch pedal out)

      # represent all rotating mass
      @spinner = Disk.new(env) { |m|
        m.radius = 0.15
        m.base_friction = 5.0/1000
        m.omega_friction = 15.0/100_000
        m.mass = 15
      }
      @fixed_mass = 30 # kg

      yield self if block_given?
    end

    def clutch=(val)
      @clutch = DrivingPhysics.unit_interval! val
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

    def gear=(val)
      @gear = self.class.gear_interval!(val, max: self.top_gear)
    end

    def top_gear
      @ratios.length
    end

    def to_s
      [self.inputs,
       format("Ratios: %s", @ratios.inspect),
       format(" Final: %s  Mass: %.1f kg  Rotating: %.1f kg",
              @final_drive.inspect, self.mass, @spinner.mass),
      ].join("\n")
    end

    def inputs
      format("Gear: %d  Clutch: %.1f%%", @gear, @clutch * 100)
    end

    def ratio(gear = nil)
      gear ||= @gear
      case gear
      when REVERSE
        REVERSE_RATIO * @final_drive
      when 0
        raise(Disengaged, "Cannot determine gear ratio")
      else
        @ratios.fetch(gear - 1) * @final_drive
      end
    end

    def axle_torque(crank_torque)
      crank_torque * @clutch / self.ratio
    end

    def output_torque(crank_torque, crank_rpm, axle_omega: nil)
      axle_alpha = self.alpha(self.axle_torque(crank_torque),
                              omega: self.axle_omega(crank_rpm,
                                                     axle_omega: axle_omega))
      self.implied_torque(axle_alpha)
    end

    # take into account the old axle_omega and @clutch
    def axle_omega(crank_rpm, axle_omega: nil)
      new_axle_omega = DrivingPhysics.omega(crank_rpm) * self.ratio
      if axle_omega.nil?
        raise(ClutchDisengage, "cannot determine axle omega") if @clutch != 1.0
        return new_axle_omega
      end
      diff = new_axle_omega - axle_omega
      axle_omega + diff * @clutch
    end

    # take into account the old crank_rpm and @clutch
    # crank will tolerate mismatch more than axle
    def crank_rpm(axle_omega, crank_rpm: nil)
      new_crank_rpm = DrivingPhysics.rpm(axle_omega) / self.ratio
      if crank_rpm.nil?
        raise(ClutchDisengage, "cannot determine crank rpm") if @clutch != 1.0
        return new_crank_rpm
      end
      crank_rpm + (new_crank_rpm - crank_rpm) * @clutch
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

    def initialize(motor:, gearbox:)
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

    def axle_torque(rpm, axle_omega: nil)
      @gearbox.output_torque(@motor.output_torque(rpm), rpm,
                             axle_omega: axle_omega)
    end

    def axle_omega(rpm, axle_omega: nil)
      @gearbox.axle_omega(rpm, axle_omega: axle_omega)
    end

    def crank_rpm(axle_omega, crank_rpm: nil)
      @gearbox.crank_rpm(axle_omega, crank_rpm: crank_rpm)
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

    def clutch
      @powertrain.gearbox.clutch
    end

    def clutch=(val)
      @powertrain.gearbox.clutch = val
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

    # force opposing speed; depends on speed**2 but use speed and speed.abs
    def air_force(speed)
      -0.5 * @frontal_area * @cd * @env.air_density * speed * speed.abs
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
      return 0.0 if mag < 0.001
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

    def drive_force(rpm, axle_omega: nil)
      @tire.force @powertrain.axle_torque(rpm, axle_omega: axle_omega)
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
      self.total_mass / @num_tires
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
  # we will have a control loop
  # SP    - setpoint, this is the desired position
  # PV(t) - process variable, this is the sensed position, varying over time
  #  e(t) - error, SP - PV
  # CV(t) - control variable: the controller output

  # for example, where to set the throttle to maintain 1000 RPM
  # SP - 1000 RPM
  # PV - current RPM
  # CV - throttle position

  class PIDController
    HZ = 1000
    TICK = Rational(1) / HZ

    # Ziegler-Nichols method for tuning PID gain knobs
    ZN = {
      #            Kp     Ti     Td     Ki     Kd
      #     Var:   Ku     Tu     Tu    Ku/Tu  Ku*Tu
      'P'  =>   [0.500],
      'PI' =>   [0.450, 0.800,   nil, 0.540],
      'PD' =>   [0.800,   nil, 0.125,   nil, 0.100],
      'PID' =>  [0.600, 0.500, 0.125, 1.200, 0.075],
      'PIR' =>  [0.700, 0.400, 0.150, 1.750, 0.105],
      # less overshoot than standard PID below
      'some' => [0.333, 0.500, 0.333, 0.666, 0.111],
      'none' => [0.200, 0.500, 0.333, 0.400, 0.066],
    }

    # ultimate gain, oscillation
    def self.tune(type, ku, tu)
      record = ZN[type.downcase] || ZN[type.upcase] || ZN.fetch(type)
      kp, ti, td, ki, kd = *record
      kp *= ku if kp
      ti *= tu if ti
      td *= tu if td
      ki *= (ku / tu) if ki
      kd *= (ku * tu) if kd
      { kp: kp, ti: ti, td: td, ki: ki, kd: kd }
    end

    attr_accessor :kp, :ki, :kd, :dt, :setpoint,
                  :p_range, :i_range, :d_range, :o_range
    attr_reader :measure, :error, :last_error, :sum_error

    def initialize(setpoint, dt: TICK)
      @setpoint, @dt, @measure = setpoint, dt, 0.0

      # track error over time for integral and derivative
      @error, @last_error, @sum_error = 0.0, 0.0, 0.0

      # gain / multipliers for PID; tunables
      @kp, @ki, @kd = 1.0, 1.0, 1.0

      # optional clamps for PID terms and output
      @p_range = (-Float::INFINITY..Float::INFINITY)
      @i_range = (-Float::INFINITY..Float::INFINITY)
      @d_range = (-Float::INFINITY..Float::INFINITY)
      @o_range = (-Float::INFINITY..Float::INFINITY)

      yield self if block_given?
    end

    def update(measure)
      self.measure = measure
      self.output
    end

    def measure=(val)
      @measure = val
      @last_error = @error
      @error = @setpoint - @measure
      dt_error = error * dt
      if @error * @last_error > 0
        @sum_error += dt_error
      else # zero crossing; reset the accumulated error
        @sum_error = dt_error
      end
    end

    def output
      (self.proportion +
       self.integral +
       self.derivative).clamp(@o_range.begin, @o_range.end)
    end

    def proportion
      (@kp * @error).clamp(@p_range.begin, @p_range.end)
    end

    def integral
      (@ki * @sum_error).clamp(@i_range.begin, @i_range.end)
    end

    def derivative
      (@kd * (@error - @last_error) / @dt).clamp(@d_range.begin, @d_range.end)
    end

    def to_s
      [format("Setpoint: %.3f  Measure: %.3f",
              @setpoint, @measure),
       format("Error: %+.3f\tLast: %+.3f\tSum: %+.3f",
              @error, @last_error, @sum_error),
       format(" Gain:\t%.3f\t%.3f\t%.3f",
              @kp, @ki, @kd),
       format("  PID:\t%+.3f\t%+.3f\t%+.3f",
              self.proportion, self.integral, self.derivative),
      ].join("\n")
    end
  end
end
