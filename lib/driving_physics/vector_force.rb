require 'matrix' # stdlib, provides Vector class
require 'driving_physics'

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
