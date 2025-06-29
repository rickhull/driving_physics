module DrivingPhysics
  # Combustion Motor
  CombustionPower = Data.define(:torque_curve)
  CombustionState = Struct.new(:rpm, :throttle)

  # Starter Motor
  ElectricPower = Data.define(:torque)
  ElectricState = Struct.new(:throttle)

  # Disks have an angular position and velocity
  RotationState = Struct.new(:theta, :omega)

  # Model inertia and frictional losses in the rotating assembly
  EngineComposition = Data.define(:crankshaft, :flywheel)

  # Component to transmit torque between components
  AppliedTorque = Struct.new(:value)
end
