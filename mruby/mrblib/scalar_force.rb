
module DrivingPhysics
  module ScalarForce
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
    # Note: here we only consider speed; we're in a 1D world for now
    #

    # opposes the direction of speed
    def self.air_resistance(speed,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY)
      -1 * 0.5 * frontal_area * drag_cof * air_density * speed ** 2
    end

    # opposes the direction of speed
    def self.rotational_resistance(speed, rot_cof: ROT_COF)
      -1 * speed * rot_cof
    end

    # opposes the direction of speed
    # normal force is not always mass * G, e.g. aero downforce
    def self.rolling_resistance(normal_force, roll_cof: ROLL_COF)
      -1 * normal_force * roll_cof
    end

    #
    # convenience methods
    #

    def self.speed_resistance(speed,
                              frontal_area: FRONTAL_AREA,
                              drag_cof: DRAG_COF,
                              air_density: AIR_DENSITY,
                              rot_cof: ROT_COF)
      air_resistance(speed,
                     frontal_area: frontal_area,
                     drag_cof: drag_cof,
                     air_density: air_density) +
        rotational_resistance(speed, rot_cof: rot_cof)
    end

    def self.all_resistance(speed,
                            frontal_area: FRONTAL_AREA,
                            drag_cof: DRAG_COF,
                            air_density: AIR_DENSITY,
                            rot_cof: ROT_COF,
                            nf_mag:,
                            roll_cof: ROLL_COF)
      speed_resistance(speed,
                       frontal_area: frontal_area,
                       drag_cof: drag_cof,
                       air_density: air_density,
                       rot_cof: rot_cof) +
        rolling_resistance(nf_mag, roll_cof: roll_cof)
    end
  end
end
