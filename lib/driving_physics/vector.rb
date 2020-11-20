require 'matrix' # stdlib, provides Vector class
require 'driving_physics'

module DrivingPhysics::Vector
  # e.g. given 5, yields a uniformly random number from -5 to +5
  def self.random_centered_zero(magnitude)
    m = [magnitude.abs, 1].max
    Random.rand(m * 2 + 1) - m
  end

  def self.random_unit_vector(dimensions = 2, resolution: 9)
    a = Array.new(dimensions) { random_centered_zero(resolution) }
    while a.all? { |i| i == 0 }
      a = Array.new(dimensions) { random_centered_zero(resolution) }
    end
    Vector.elements(a).normalize
  end

  module Force
    # see lib/driving_physics.rb for more information on these constants
    G = DrivingPhysics::Force::G
    AIR_DENSITY = DrivingPhysics::Force::AIR_DENSITY
    DRAG_COF = DrivingPhysics::Force::DRAG_COF
    FRONTAL_AREA = DrivingPhysics::Force::FRONTAL_AREA
    CRF = DrivingPhysics::Force::CRF
    ROTATIONAL_RESISTANCE = DrivingPhysics::Force::ROTATIONAL_RESISTANCE

    # velocity is a vector; return value is a force vector
    def self.air_resistance(velocity,
                            frontal_area: FRONTAL_AREA,
                            drag_coefficient: DRAG_COF,
                            air_density: AIR_DENSITY)
      -1 * 0.5 * frontal_area * drag_coefficient * air_density *
       velocity * velocity.magnitude
    end

    def self.rotational_resistance(velocity)
      -1 * velocity * ROTATIONAL_RESISTANCE
    end

    # note: does not depend on speed but just opposes the drive force
    def self.rolling_resistance_full(drive_force:,
                                     normal_force:,
                                     crf: CRF)
      # direction opposes the drive_force
      # magnitude is from the normal_force
      -1 * drive_force.normalize * crf * normal_force.magnitude
    end

    # in a planar world, the normal force is always mass * G
    def self.rolling_resistance(mass, drive_force:, crf: CRF)
      -1 * drive_force.normalize * crf * mass * G
    end

    def self.all_resistance(drive_force,
                            velocity:,
                            mass:,
                            crf: CRF,
                            frontal_area: FRONTAL_AREA,
                            drag_coefficient: DRAG_COF,
                            air_density: AIR_DENSITY)
      air_resistance(velocity,
                     frontal_area: frontal_area,
                     drag_coefficient: drag_coefficient,
                     air_density: air_density) +
        rotational_resistance(velocity) +
        rolling_resistance(mass, drive_force: drive_force)
    end
  end
end
