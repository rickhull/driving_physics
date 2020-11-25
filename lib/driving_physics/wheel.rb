require 'driving_physics/environment'
require 'driving_physics/vector'

module DrivingPhysics
  # we're just going to model a solid rubber wheel that also acts as a tire
  # we will apply a torque to the wheel, generate a slip ratio
  # and use the longitudinal traction force to get the wheel rolling

  # given: axle torque
  # axle torque acts on the pavement generating a rearward force
  # the pavement force is countered by a forward force at the axle bearing
  #
  # T(axle) = F(pav) * r(wheel)
  # V(axle) = AngV(whl) * r(wheel)     (no slip)

  # coefficient of friction is the relationship between the max traction
  # force and the load (e.g. normal force) on the tire:
  # u = F(trac) / F(load)

  # this depends on whether the tire is sliding (kinetic) or not (static)
  # also on the road surface, temperature, and degree of wetness


  # Dry
  # ---
  # u(static)  = (1.0..1.3)
  # u(kinetic) = (0.2..0.8)
  #
  # Wet
  # ---
  # u(s) = (0.2..0.8)
  # u(k) = (0.05..0.5)
  #

  class Wheel
    attr_accessor :radius, :mass, :ustatic, :ukinetic

    def self.traction(normal_force, cof)
      normal_force * cof
    end

    def self.max_g(normal_force, cof, g)
      traction(normal_force, cof) * g
    end

    def initialize(env)
      @env = env
      @radius = 350 # mm
      @mass = 25    # kg
      @ustatic = 1.1
      @ukinetic = 0.8

      yield self if block_given?
    end

    def to_s
      [format("Radius: %d mm", @radius),
       format("Mass: %.1f kg", @mass),
       format("cF: %.1f / %.1f", @ustatic, @ukinetic),
      ].join(" | ")
    end

    def traction(nf, static: true)
      self.class.traction(nf, static? ? @ustatic : @ukinetic)
    end

    def max_g(nf, static: true)
      traction(nf, static: static) * @env.g
    end

    def force(axle_torque)
      axle_torque / @radius
    end
  end
end
