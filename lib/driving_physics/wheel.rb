require 'driving_physics/environment'
require 'driving_physics/vector_force'

module DrivingPhysics
  class Wheel
    # Note, this is not the density of solid rubber.  This density
    # yields a sensible mass for a wheel / tire combo at common radius
    # and width, assuming a uniform density
    # e.g. 25kg at 350mm R x 200mm W
    #
    DENSITY = 0.325  # kg / L

    def self.traction(normal_force, cof)
      normal_force * cof
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

    # I = 1/2 m*r^2
    def self.inertia(radius_m, mass)
      radius_m ** 2 * mass / 2
    end

    # angular acceleration
    def self.alpha(torque, inertia)
      torque / inertia
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

    attr_reader :env, :radius, :width, :density, :temp,
                :mu_s, :mu_k
    attr_accessor :omega

    def initialize(env,
                   radius: 350, width: 200, density: DENSITY,
                   temp: nil, mass: nil,
                   mu_s: 1.1, mu_k: 0.7)
      @env = env
      @radius = radius.to_f # mm
      @width  = width.to_f  # mm
      @mu_s = mu_s.to_f
      @mu_k = mu_k.to_f
      @density = mass.nil? ? density : self.class.density(mass, volume_l)
      @temp = temp.to_f || @env.air_temp
      @omega = 0.0 # radians / sec
    end

    def to_s
      [[format("%d mm (R) x %d mm (W)", @radius, @width),
        format("Mass: %.1f kg %.3f kg/L", mass, @density),
        format("cF: %.1f / %.1f", @mu_s, @mu_k),
       ].join(" | "),
       [format("Temp: %.1f C", @temp),
        format("Vel: %.2f r/s (%.2f m/s)", @omega, surface_v),
       ].join(" | "),
      ].join("\n")
    end

    def wear!(amount_mm)
      @radius -= amount_mm
    end

    def mass
      self.class.mass(radius_m, width_m, @density)
    end

    # in m^3
    def volume
      self.class.volume(radius_m, width_m)
    end

    # in L
    def volume_l
      self.class.volume_l(radius_m, width_m)
    end

    def inertia
      self.class.inertia(radius_m, mass)
    end

    def traction(nf, static: true)
      self.class.traction(nf, static ? @mu_s : @mu_k)
    end

    def force(axle_torque)
      axle_torque / radius_m
    end

    def max_torque(nf, static: true)
      traction(nf, static: static) * radius_m
    end

    def surface_v
      @omega * radius_m * 2
    end

    def radius_m
      @radius.to_f / 1000
    end

    def width_m
      @width.to_f / 1000
    end
  end
end
