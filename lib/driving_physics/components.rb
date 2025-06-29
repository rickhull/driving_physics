# include these complex components when requiring driving_physics/components
require 'driving_physics/disk'

module DrivingPhysics
  # e.g. Disks have an angular position and velocity
  class RotationState < Struct.new(:theta, :omega)
    def initialize(theta: 0.0, omega: 0.0)
      super(theta, omega)
    end
  end
  
  #
  # Gearbox
  #

  class Gearbox < Data.define(:gears, :final_drive, :efficiency)
    # sensible defaults
    RATIOS = [1/5r, 2/5r, 5/9r, 5/7r, 1r, 5/4r]
    FINAL_DRIVE = 11/41r
    REVERSE = -1
    REVERSE_RATIO = -1/10r
    EFFICIENCY = 0.95      # losses due to friction and heat

    def initialize(gears: RATIOS,
                   final_drive: FINAL_DRIVE,
                   efficiency: EFFICIENCY)
      super(gears:, final_drive:, efficiency:)
    end
  end

  class GearboxState < Struct.new(:gear, :clutch)
    def initialize(gear: 0, clutch: 1.0)
      super(gear, clutch)
    end
  end


  #
  # Combusion Motor with starter motor
  #

  # Combustion Motor
  CombustionPower = Data.define(:torque_curve)
  class CombustionState < Struct.new(:rpm, :throttle)
    def initialize(throttle: 0.0, rpm: 0.0)
      super(rpm, throttle)
    end
  end
      
  # Starter Motor
  ElectricPower = Data.define(:torque)
  class ElectricState < Struct.new(:throttle)
    def initialize(throttle: 0.0)
      super(throttle)
    end
  end

  #
  # Assemblies - Components composed of Entities (not other Components)
  #
  
  # Model inertia and frictional losses in the rotating assembly
  EngineComposition = Data.define(:crankshaft, :flywheel)
  DrivetrainComposition = Data.define(:engine, :gearbox, :driveshaft)


  #
  # Utilities
  #
  
  # Component to transmit torque between components
  class AppliedTorque < Struct.new(:value)
    def initialize(value: 0.0)
      super(value)
    end
  end
end
