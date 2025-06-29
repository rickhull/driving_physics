require 'driving_physics/disk'

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
