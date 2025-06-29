require 'driving_physics'

# Work is Force * Distance   (Torque * Theta)
# W = F * s  (W = T * Th)
# W = T * Theta

# Power is Work / time
# P = W / dt
# P = T * Th / dt
# P = T * Omega

module DrivingPhysics
  def self.work(force, displacement)
    force * displacement
  end

  def self.power(force, speed)
    force * speed
  end
end
