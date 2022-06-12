require 'driving_physics/environment'
require 'driving_physics/vector_force'

module DrivingPhysics
  # Rotational complements to acc/vel/pos
  # alpha - angular acceleration
  # omega - angular velocity (radians / s)
  # theta - radians

  class Wheel
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

    def self.force(axle_torque, radius_m)
      axle_torque / radius_m.to_f
    end

    # in m^3
    def self.volume(radius_m, width_m)
      Math::PI * radius_m ** 2 * width_m.to_f
    end

    # in L
    def self.volume_l(radius_m, width_m)
      volume(radius_m, width_m) * 1000
    end

    def self.density(mass, volume_l)
      mass.to_f / volume_l
    end

    def self.mass(radius_m, width_m, density)
      density * volume_l(radius_m, width_m)
    end

    # I = 1/2 (m)(r^2) for a disk
    def self.rotational_inertia(radius_m, mass)
      mass * radius_m**2 / 2.0
    end
    class << self
      alias_method(:moment_of_inertia, :rotational_inertia)
    end

    # angular acceleration
    def self.alpha(torque, inertia)
      torque / inertia
    end

    def self.tangential(rotational, radius_m)
      rotational * radius_m
    end
    class << self
      alias_method(:tangential_a, :tangential)
      alias_method(:tangential_v, :tangential)
      alias_method(:tangential_p, :tangential)
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
    attr_accessor :radius, :width, :density, :temp,
                  :mu_s, :mu_k, :omega_friction, :base_friction, :roll_cof

    def initialize(env)
      @env = env
      @radius = 350/1000r # m
      @width  = 200/1000r # m
      @density = DENSITY
      @temp = @env.air_temp
      @mu_s = 11/10r # static friction
      @mu_k =  7/10r # kinetic friction
      @base_friction = 5/1_000r
      @omega_friction = 3/10_000r # scales with speed
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

    def mass=(val)
      @density = self.class.density(val, self.volume_l)
    end

    def wear!(amount)
      @radius -= amount
    end

    def heat!(amount_deg_c)
      @temp += amount_deg_c
    end

    def mass
      self.class.mass(@radius, @width, @density)
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

    def traction(nf, static: true)
      self.class.traction(nf, static ? @mu_s : @mu_k)
    end

    def force(axle_torque)
      self.class.force(axle_torque, @radius)
    end

    # torque opposing omega
    def friction_loss(normal_force, omega)
      return omega if omega.zero?
      normal_force * (@base_friction + @omega_friction * omega)
    end

    # rolling loss in terms of axle torque
    def rolling_loss(normal_force, omega)
      return omega if omega.zero?
      (normal_force * @roll_cof) * @radius
    end

    # inertial loss in terms of axle torque when used as a drive wheel
    def inertial_loss(axle_torque, total_driven_mass)
      drive_force = self.force(axle_torque)
      force_loss = 0
      # The force loss depends on the acceleration, but the acceleration
      # depends on the force loss.  Converge the value via 5 round trips.
      # This is a rough way to compute an integral and should be accurate
      # to 8+ digits.
      5.times {
        acc = DrivingPhysics.acc(drive_force - force_loss, total_driven_mass)
        alpha = acc / @radius
        force_loss = self.inertial_torque(alpha) / @radius
      }
      force_loss * @radius
    end

    # how much torque to accelerate rotational inertia at alpha
    def inertial_torque(alpha)
      alpha * self.rotational_inertia
    end

    def net_torque(axle_torque, mass:, omega:, normal_force:)
      net = axle_torque -
            self.rolling_loss(normal_force, omega) -
            self.friction_loss(normal_force, omega)
      # inertial loss has interdependencies; calculate last
      net - self.inertial_loss(net, mass)
    end

    def net_tractable_torque(axle_torque,
                             mass:, omega:, normal_force:, static: true)
      net = self.net_torque(axle_torque,
                            mass: mass,
                            omega: omega,
                            normal_force: normal_force)
      traction = self.traction(normal_force, static: static)
      self.force(net) > traction ? self.tractable_torque : net
    end

    # this doesn't take inertial losses or internal frictional losses
    # into account.  input torque required to saturate traction will be
    # higher than what this method returns
    def tractable_torque(nf, static: true)
      traction(nf, static: static) * @radius
    end
  end
end
