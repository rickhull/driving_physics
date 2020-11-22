require 'matrix' # stdlib, provides Vector class
require 'driving_physics'

module DrivingPhysics::Vector
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

  module Force
    DF = DrivingPhysics::Force

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
                            frontal_area: DF::FRONTAL_AREA,
                            drag_cof: DF::DRAG_COF,
                            air_density: DF::AIR_DENSITY)
      -1 * 0.5 * frontal_area * drag_cof * air_density *
       velocity * velocity.magnitude
    end

    def self.rotational_resistance(velocity, rot_cof: DF::ROT_COF)
      -1 * velocity * rot_cof
    end

    # dir is drive_force vector or velocity vector; will be normalized
    # normal_force is a magnitude, not a vector
    #
    def self.rolling_resistance(nf_mag, dir:, roll_cof: DF::ROLL_COF)
      return dir if dir.zero? # don't try to normalize a zero vector
      nf_mag = nf_mag.magnitude if nf_mag.is_a? Vector
      -1 * dir.normalize * roll_cof * nf_mag
    end

    #
    # convenience methods
    #

    def self.velocity_resistance(velocity,
                                 frontal_area: DF::FRONTAL_AREA,
                                 drag_cof: DF::DRAG_COF,
                                 air_density: DF::AIR_DENSITY,
                                 rot_cof: DF::ROT_COF)
      air_resistance(velocity,
                     frontal_area: frontal_area,
                     drag_cof: drag_cof,
                     air_density: air_density) +
        rotational_resistance(velocity, rot_cof: rot_cof)
    end

    def self.all_resistance(velocity,
                            frontal_area: DF::FRONTAL_AREA,
                            drag_cof: DF::DRAG_COF,
                            air_density: DF::AIR_DENSITY,
                            rot_cof: DF::ROT_COF,
                            dir:,
                            nf_mag:,
                            roll_cof: DF::ROLL_COF)
      velocity_resistance(velocity,
                          frontal_area: frontal_area,
                          drag_cof: drag_cof,
                          air_density: air_density,
                          rot_cof: rot_cof) +
        rolling_resistance(nf_mag, dir: dir, roll_cof: roll_cof)
    end
  end
end
