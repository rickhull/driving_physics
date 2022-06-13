require 'driving_physics/environment'
require 'driving_physics/vector_force'

module DrivingPhysics
  # radius is always in meters

  # Rotational complements to acc/vel/pos
  # alpha - angular acceleration
  # omega - angular velocity (radians / s)
  # theta - radians

  def self.revs(rads)
    rads / (2 * Math::PI)
  end

  def self.rads(revs)
    revs * 2 * Math::PI
  end

  def self.omega(rpm)
    self.rads(rpm / 60.0)
  end

  def self.rpm(omega)
    self.revs(omega) * 60
  end

  class Disk
    DENSITY = 1.0 # kg / L

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

    def self.tangential(rotational, radius)
      rotational * radius
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
    attr_accessor :radius, :width, :density

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

    def alpha(torque)
      torque / self.rotational_inertia
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
      mag = omega.abs
      sign = omega / mag
      -1 * sign * (normal_force || self.normal_force) *
       (@base_friction + @omega_friction * mag)
    end

    # how much torque to accelerate rotational inertia at alpha
    def inertial_torque(alpha)
      alpha * self.rotational_inertia
    end
  end
end