require 'driving_physics/world'
require 'driving_physics/components'
require 'driving_physics/friction'

module DrivingPhysics
  class World
    FRICTION_MODEL = FrictionModel.new
    
    def create_disk(mass:, radius:, extent:, friction_model: FRICTION_MODEL)
      disk_id = self.create_entity
      self.add(disk_id, Disk.new(mass:, radius:, extent:))
      self.add(disk_id, friction_model)
      self.add(disk_id, RotationState.new)
      disk_id
    end

    # def create_engine
    # starter_torque
    # torque_curve
    # crankshaft_disk
    # crankshaft_state
    # crankshaft_friction
    # flywheel_disk
    # flywheel_state
    # flywheel_friction

    def create_engine(starter_torque: 200, 
                      torque_curve:, 
                      crankshaft: {mass: 15, radius: 0.1, extent: 0.05},
                      flywheel: {mass: 8, radius: 0.15, extent: 0.02},
                      crankshaft_friction: FrictionModel.new,
                      flywheel_friction: FrictionModel.new)
      
      # Create the engine entity
      engine_id = self.create_entity
      
      # Create crankshaft and flywheel
      crank_id = create_disk(**crankshaft, friction_model: crankshaft_friction)
      flywheel_id = create_disk(**flywheel, friction_model: flywheel_friction)
      
      # Add engine components
      self.add(engine_id, CombustionPower.new(torque_curve: torque_curve))
      self.add(engine_id, CombustionState.new)
      self.add(engine_id, ElectricPower.new(torque: starter_torque))
      self.add(engine_id, ElectricState.new)
      self.add(engine_id, EngineComposition.new(crankshaft: crank_id, flywheel: flywheel_id))
      
      engine_id
    end
  end
end
