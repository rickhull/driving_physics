require 'driving_physics/components'
require 'driving_physics/disk'
require 'driving_physics/friction'

module DrivingPhysics
  class UserInputSystem
    STARTING_TIME = 3.0  # seconds to attempt starting
    IDLE_RPM = 810       # starter should reach this minimum
    IDLE_THROTTLE = 0.05 # should maintain IDLE_RPM, slowly climb

    def update(world, dt)
      # We only care about the single engine we created.
      # A real game would query for a "PlayerControlled" component.
      world.query(CombustionState, ElectricState).each do |id|
        motor = world.get!(id, CombustionState)
        starter = world.get!(id, ElectricState)

        # --- Simulate the Starting Sequence ---

        # attempt starting for only 3 seconds
        if world.time <= STARTING_TIME
          if motor.rpm < IDLE_RPM
            # below idle, keep the starter on
            if starter.throttle < 1.0
              motor.throttle = 0
              starter.throttle = 1.0
            end
          else
            # above idle, kill the starter and give some throttle
            if starter.throttle > 0
              starter.throttle = 0
              motor.throttle = IDLE_THROTTLE
            end
          end
        end
      end
    end
  end

  class StarterSystem
    def update(world, dt)
      # Find all entities that have electric power, a state to control it,
      # and a composition to know where to apply the force.
      world.query(ElectricPower, ElectricState, EngineComposition).each do |id|
        composition = world.get!(id, EngineComposition)
        power       = world.get!(id, ElectricPower)
        state       = world.get!(id, ElectricState)

        next if state.throttle <= 0.0

        # Apply throttled torque to the crankshaft
        crank_id = composition.crankshaft
        atq = world.access(crank_id, AppliedTorque)
        atq.value += power.torque * state.throttle
      end
    end
  end

  class CombustionSystem
    def update(world, dt)
      # Find all entities with combustion power, state, and composition.
      world.query(CombustionPower,
                  CombustionState,
                  EngineComposition).each do |id|
        composition = world.get!(id, EngineComposition)
        power       = world.get!(id, CombustionPower)
        state       = world.get!(id, CombustionState)

        next if state.throttle <= 0.0

        # By design, engagement of the starter motor inhibits combustion
        starter = world.get!(id, ElectricState)&.throttle
        next if starter and starter > 0.0

        # Calculate torque from the curve and throttle
        tq = power.torque_curve.torque(state.rpm) * state.throttle
        crank_id = composition.crankshaft
        atq = world.access(crank_id, AppliedTorque)
        atq.value += tq
      end
    end
  end

  class FrictionSystem
    def update(world, dt)
      # remember which engine assemblies have been handled
      engine_disk_ids = Set.new

      # Handle engine assemblies (rigidly connected components)
      # One input torque but multiple frictional components
      world.query(EngineComposition).each do |engine_id|
        # get the crank_id and flywheel_id
        composition = world.get!(engine_id, EngineComposition)
        crank_id    = composition.crankshaft
        flywheel_id = composition.flywheel
        engine_disk_ids.add(crank_id).add(flywheel_id) # ignore these later

        # Get the rotation state for the crank, identical for flywheel
        crank_state = world.get!(crank_id, RotationState)

        # apply friction
        # Get both disk definitions to calculate total friction
        atq = world.access(crank_id, AppliedTorque)
        cfm = world.get!(crank_id, FrictionModel)
        ffm = world.get!(flywheel_id, FrictionModel)
        total = cfm.friction(atq.value, crank_state.omega) +
                ffm.friction(atq.value, crank_state.omega)
        atq.value += total
      end

      # Handle standalone disks (not part of an engine assembly)
      world.query(Disk, RotationState, FrictionModel).each do |id|
        # Skip if this disk is part of an engine (handled above)
        next if engine_disk_ids.include?(id)

        disk  = world.get!(id, Disk)
        state = world.get!(id, RotationState)
        fm = world.get!(id, FrictionModel)
        atq = world.access(id, AppliedTorque)
        
        atq.value += fm.friction(atq.value, state.omega)
      end
    end
  end

  class IntegrationSystem
    def update(world, dt)
      # The crankshaft and flywheel are rigidly connected, so they should have
      # a combined inertia and a single angular velocity. We'll handle this
      # by applying the change to both. A more advanced simulation might
      # introduce a Clutch component to disconnect them.

      # Let's find all engines to calculate their total inertia.
      world.query(EngineComposition).each do |id|
        composition = world.get!(id, EngineComposition)
        crank_id    = composition.crankshaft
        flywheel_id = composition.flywheel

        # Get components for both parts
        crank_def      = world.get!(crank_id, Disk)
        crank_state    = world.get!(crank_id, RotationState)
        flywheel_def   = world.get!(flywheel_id, Disk)
        flywheel_state = world.get!(flywheel_id, RotationState)

        # Get the torque applied to each part (usually just the crank)
        net_torque = [crank_id, flywheel_id].map { |id|
          world.get(id, AppliedTorque)&.value || 0.0
        }.sum

        # Combine inertia to determine combined velocity from acceleration
        total_inertia = crank_def.inertia + flywheel_def.inertia
        omega = crank_state.omega + Disk.alpha(net_torque, total_inertia) * dt

        # don't allow friction to reverse direction
        if (crank_state.omega > 0 and omega < 0) or
          (crank_state.omega < 0 and omega > 0)
          omega = 0.0
        end

        # Update crank state
        crank_state.omega = omega
        crank_state.theta += omega * dt

        # Update the flywheel state to that of the crankshaft
        flywheel_state.omega = crank_state.omega
        flywheel_state.theta = crank_state.theta

        # Update engine RPM
        engine_state = world.get!(id, CombustionState)
        engine_state.rpm = Disk.rpm(crank_state.omega) if engine_state
      end

      # --- Cleanup Phase ---
      # Now that all calculations are done, remove the transient component
      # from all entities that had it, preparing them for the next frame.
      world.query(AppliedTorque).each do |id|
        world.remove(id, AppliedTorque)
      end
    end
  end
end
