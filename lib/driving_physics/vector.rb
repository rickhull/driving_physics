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

    # velocity is a vector; return value is a force vector
    def self.air_resistance(velocity,
                            frontal_area: DF::FRONTAL_AREA,
                            drag_coefficient: DF::DRAG_COF,
                            air_density: DF::AIR_DENSITY)
      -1 * 0.5 * frontal_area * drag_coefficient * air_density *
       velocity * velocity.magnitude
    end

    def self.rotational_resistance(velocity,
                                   rotational_coefficient: DF::RR_COF)
      -1 * velocity * rotational_coefficient
    end

    # This is used to model rolling resistance and braking forces
    # These have a special case when v=0, as they should resist
    #   the drive force, but not exceed it
    # Take care to reduce the magnitude appropriately when summing
    #   forces.
    # They can oppose a net motivating force or oppose velocity
    def self.resistance(magnitude,
                        velocity:,
                        drive_force:)
      zero_v = velocity.magnitude == 0.0

      # generally oppose velocity, but oppose drive_force when v=0
      if drive_force.magnitude == 0.0 and zero_v
        # nothing to oppose
        Vector.zero(velocity.size)
      elsif zero_v
        -1 * drive_force.normalize * magnitude
      else
        -1 * velocity.normalize * magnitude
      end
    end

    def self.rolling_resistance(normal_force,
                                velocity:,
                                drive_force:,
                                crf: DF::CRF)
      resistance(crf * normal_force.magnitude,
                 velocity: velocity,
                 drive_force: drive_force)
    end

    # in a planar world, without aero, the normal force is always mass * G
    def self.rolling_resistance_simple(mass,
                                       velocity:,
                                       drive_force:,
                                       crf: DF::CRF)
      resistance(crf * mass * DrivingPhysics::G,
                 velocity: velocity,
                 drive_force: drive_force)
    end

    def self.braking(clamping_force,
                     velocity:,
                     drive_force:,
                     brake_coefficient: DF::BRAKE_COF)
      resistance(clamping_force * brake_coefficient,
                 velocity: velocity,
                 drive_force: drive_force)
    end

    def self.all_resistance(drive_force:,
                            velocity:,
                            mass:,
                            crf: DF::CRF,
                            frontal_area: DF::FRONTAL_AREA,
                            drag_coefficient: DF::DRAG_COF,
                            air_density: DF::AIR_DENSITY)
      air_resistance(velocity,
                     frontal_area: frontal_area,
                     drag_coefficient: drag_coefficient,
                     air_density: air_density) +
        rotational_resistance(velocity) +
        rolling_resistance(mass,
                           velocity: velocity,
                           drive_force: drive_force)
    end
  end
end
