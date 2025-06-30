require 'driving_physics'

module DrivingPhysics
  #  RotatingBody: Disk, RotationState, FrictionModel
  #          Disk: mass, radius, extent
  # RotationState: theta, omega (pos, vel)
  # FrictionModel: static, kinetic, viscous
  # This is the main physics component for automotive entities
  class RotatingBody < Data.define(:disk, :rotation_state, :friction_model)
    def initialize(mass:, radius:, extent:,
                   rotation_state: RotationState.new,
                   friction_model: FrictionModel.new)
        super(disk: Disk.new(mass:, radius:, extent:),
              rotation_state:,
              friction_model:)
    end
    def inertia      = disk.inertia
    def mass         = disk.mass
    def radius       = disk.radius
    def extent       = disk.extent
    def theta        = rotation_state.theta
    def omega        = rotation_state.omega
    def friction(tq) = friction_model.friction(tq, rotation_state.omega)
    def update(dt)   = rotation_state.update(dt) 
  end

  # angular position and velocity
  class RotationState < Struct.new(:theta, :omega)
    def initialize(theta: 0.0, omega: 0.0)
      super(theta, omega)
    end

    def update(dt)
      self.theta += self.omega * dt
    end
  end

  #
  # Rotating Bodies
  #

  class Crankshaft < RotatingBody
    def initialize(mass: 20, radius: 0.05, extent: 0.2,
                   friction_model: FrictionModel.new)
      super
    end
  end

  class Flywheel < RotatingBody
    def initialize(mass: 12, radius: 0.15, extent: 0.03,
                   friction_model: FrictionModel.new)
      super
    end
  end
  
  class Driveshaft < RotatingBody
    def initialize(mass: 10, radius: 0.04, extent: 1.5,
                   friction_model: FrictionModel.new)
      super
    end

    # TODO: WTF ?!?!?!
    # The resistive torque the driveshaft creates (from its own friction)
    def load_torque
      # We need the torque it *receives* to calculate friction, but that
      # creates a chicken-and-egg problem.
      # So we'll use a simplified friction model here based on its own speed.
      # This is a common and effective simplification.
      # A negative torque opposing rotation.
      omega = self.omega
      -5.0 * omega.abs - 2.0 * omega
    end
  end
  
  #
  # CombustionEngine
  #

  class CombustionEngine < Data.define(:torque_curve, :starter_torque,
                                       :crankshaft, :flywheel)
    STARTER_TORQUE = 50
    IDLE_RPM = 850

    def initialize(torque_curve: TorqueCurve.new,
                   starter_torque: STARTER_TORQUE,
                   crankshaft: Crankshaft.new,
                   flywheel: Flywheel.new)
      super
    end

    # combine crankshaft and flywheel inertia
    def inertia
      crankshaft.inertia + flywheel.inertia
    end

    # combine crankshaft and flywheel friction
    def friction(input_tq)
      crankshaft.friction(input_tq) + flywheel.friction(input_tq)
    end

    # provide starter_torque below IDLE_RPM
    def torque(throttle)
      rpm = self.rpm
      rpm < IDLE_RPM ? starter_torque : torque_curve.torque(rpm) * throttle
    end

    # generated torque net friction
    def net_torque(throttle)
      tq = self.torque(throttle)
      tq + self.friction(tq)
    end

    # angular acceleration net friction
    def alpha(throttle)
      self.net_torque(throttle) / self.inertia
    end

    # angular velocity
    def omega
      crankshaft.omega
    end

    # based on crankshaft
    def rpm
      Disk.rpm(self.omega)
    end

    def update(throttle, dt)
      crankshaft.rotation_state.omega += self.alpha(throttle) * dt
      crankshaft.rotation_state.update(dt)
      flywheel.rotation_state.omega = crankshaft.rotation_state.omega
      flywheel.rotation_state.theta = crankshaft.rotation_state.theta
    end
  end

  # clutch value 1.0 means fully engaged (clutch pedal out)
  class VehicleControls < Struct.new(:throttle, :clutch, :gear, :steering)
    def initialize(throttle: 0.0, clutch: 1.0, gear: 0, steering: 0.0)
      super(throttle, clutch, gear, steering)
    end
  end

  #
  # Gearbox
  #

  class Gearbox
    class InvalidGear < RuntimeError; end
    
    # CONFIGURATION
    attr_reader :gears, :final_drive, :efficiency
    
    # STATE
    attr_reader :drive_omega, :drive_torque

    # CONSTANTS
    REVERSE = -1
    REVERSE_RATIO = -1/10r
    NEUTRAL = 0
    NEUTRAL_RATIO = 0
    
    # DEFAULTS
    RATIOS = [1/5r, 2/5r, 5/9r, 5/7r, 1r, 5/4r]
    FINAL_DRIVE = 11/41r
    EFFICIENCY = 0.95

    # PHYSICAL CONSTRAINTS
    MIN_GEAR_RADIUS = 0.05
    MAX_GEAR_RADIUS = 0.25
    GEAR_EXTENT = 0.02

    def initialize(gears: RATIOS,
                   final_drive: FINAL_DRIVE,
                   efficiency: EFFICIENCY)
      @gears, @final_drive, @efficiency = gears, final_drive, efficiency
      @drive_omega = 0.0
      @drive_torque = 0.0
    end

    def generate_bodies
      # input shaft
      # each gear including reverse
      # final drive
      # output shaft
      # only the selected gear is rotating
      @input_shaft = RotatingBody.new(mass: 1.5, radius: 0.02, extent: 0.3)
      @output_shaft = RotatingBody.new(mass: 2.5, radius: 0.025, extent: 0.4)
    end
    
    # Returns the internal ratio for a given gear number (1st = 1)
    def ratio(gear)
      case gear
      when REVERSE then REVERSE_RATIO
      when NEUTRAL then NEUTRAL_RATIO
      when (1..@gears.size) then @gears[gear - 1]
      else
        raise(InvalidGear, gear.inspect)
      end
    end

    # Returns the total reduction for the selected gear (1st = 1)
    def final_ratio(gear)
      self.ratio(gear) * final_drive
    end

    # Gearbox operation; update outputs given the inputs
    def update(engine_omega, engine_torque, gear, clutch)
      reduction = self.final_ratio(gear)
      @drive_torque = engine_torque * reduction * @efficiency * clutch
      @drive_omega = reduction.zero? ? 0.0 : engine_omega / reduction
    end
  end

  #
  # Utilities
  #
  
  # Component to transmit torque between components
  #class AppliedTorque < Struct.new(:value)
  #  def initialize(value: 0.0)
  #    super(value)
  #  end
  #end
end
