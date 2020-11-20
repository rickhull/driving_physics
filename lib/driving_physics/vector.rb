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

  # velocity is a vector; return value is a force vector
  def self.force_drag_full(drag_coefficient:,
                           frontal_area:,
                           air_density:,
                           velocity:)
    -1 * 0.5 * drag_coefficient * frontal_area * air_density *
     velocity * velocity.magnitude
  end

  # approximate for normal tires on concrete
  # coefficient of rolling friction
  CRF = 0.01

  # note: does not depend on speed but just opposes the drive force
  def self.force_rolling_resistance_full(drive_force:,
                                         normal_force:,
                                         coefficient:)
    # direction opposes the drive_force
    # magnitude is from the normal_force
    -1 * drive_force.normalize * coefficient * normal_force.magnitude
  end

  # in a planar world, the normal force is always mass * G
  def self.force_rolling_resistance(drive_force:, mass:)
    -1 * drive_force.normalize * CRF * mass * DrivingPhysics::G
  end

  def self.force_rotational_resistance(velocity,
                                       coefficient: DrivingPhysics::C_RR)
    -1 * velocity * coefficient
  end

  def self.force_air_resistance(velocity)
    force_drag_full(drag_coefficient: DrivingPhysics::DRAG_COF,
                    frontal_area: DrivingPhysics::FRONTAL_AREA,
                    air_density: DrivingPhysics::AIR_DENSITY,
                    velocity: velocity)
  end

  def self.net_drive_force(drive_force:, velocity:, mass:)
    drive_force +
      force_rolling_resistance(drive_force: drive_force,
                               mass: mass) +
      force_rotational_resistance(velocity) +
      force_air_resistance(velocity)
  end
end
