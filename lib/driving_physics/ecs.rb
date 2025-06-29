# ECS: Entity Component System
# Note, this is *NOT* an "Entity Component" system.
# This is an "Entity - Component - System" system.
# Entities have an ID.  Any ID may generally be assumed to be an Entity ID.
# Components have a class.  Any class - often denoted klass - a component class.
# Systems take action with an update method.
# A World orchestrates everything.
# Entities are simply an integer ID, assigned by the World.
# Components are attached to Entities in the World.
# Systems query the World for Components and update associated Entities.
#

module DrivingPhysics
  class World
    def self.wall_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # ivars
    # @entities - look up component classes by entity id          attr_reader
    # @components - look up component instances by klass and id
    # @systems - ordered list of system instances                 attr_accessor
    # @next_id - entity id for the next created entity
    # @tick - a fraction of a logical second, 1/100               attr_accessor
    # @time - accumulation of ticks                               attr_reader
    # @wall_time - monotonically increasing timestamp
    
    attr_accessor :systems, :tick
    attr_reader :entities, :time

    def initialize
      @entities = {}   # id => Set[klass]
      @components = {} # klass => { id => component }
      @systems = []    # ordered list of system instances
      @next_id = 0
      @tick = 1/100r
      @time = Rational(0)
      @wall_time = World.wall_time
    end

    def hz=(val)
      @tick = Rational(1) / val
    end

    def tick=(val)
      @tick = val.rationalize
    end

    def sync
      t = World.wall_time
      diff = t - @wall_time
      @wall_time = t
      diff
    end
    
    # create the storage for an entity's component classes (as yet unspecified)
    def create_entity
      id = @next_id
      @entities[id] = Set.new
      @next_id += 1
      id
    end

    # Remove all components associated with this entity
    # Remove the entity itself
    def destroy_entity(id)
      e = @entities[id] or return
      e.each { |klass| @components[klass]&.delete(id) }
      @entities.delete(id)
    end

    # add an component instance to an entity
    # update @entities to look up this component class via id
    # update @components to look up this entity and component instances
    # via the component class
    def add(id, component)
      klass = component.class
      @entities[id].add(klass)
      @components[klass] ||= {}
      @components[klass][id] = component
    end

    # remove this component class from the entity
    # remove the entity from the component class registry
    def remove(id, klass)
      e, c = @entities[id], @components[klass]
      if e and c
        e.delete(klass)
        c.delete(id)
      end
    end

    # Get a specific component instance for a given entity.
    def get(id, klass)
      @components.dig(klass, id)
    end

    # get the component or create it if it doesn't exist
    # e.g. world.access(eid, MyComponent) { MyComponent.new(0.0) }
    def access(id, klass, &creation)
      self.get(id, klass) or self.add(id, creation.call)
    end
    
    # Find all entity IDs that have the given set of components.
    # This is optimized to start its search from the rarest component.
    def query(*klasses)
      return [] if klasses.empty?

      # Find the component storage with the fewest entities to start the search
      first, *rest = klasses.sort_by { |c| @components[c]&.size || 0 }

      initial_candidates = @components[first]&.keys
      return [] if initial_candidates.nil? || initial_candidates.empty?

      # Start with a copy of the smallest candidate list and filter it down.
      rest.reduce(initial_candidates) do |candidates, klass|
        # In-place selection is efficient.
        candidates.select! { |id| @components[klass]&.key?(id) }
        candidates # prevent select! from returning nil
      end
    end

    def update(dt = @tick)
      @time += dt
      @systems.each { |system| system.update(self, dt) }
    end
  end

  # mass in kg
  # radius and extent in m
  # default density is 1 kg/L or 1000 kg / m^3
  class Disk < Data.define(:mass, :radius, :extent,
                           :friction_base, :friction_omega)
    def self.revs(rads) = rads * 0.5 / Math::PI
    def self.rads(revs) = revs *  2  * Math::PI
    def self.omega(rpm) = self.rads(rpm / 60.0)
    def self.rpm(omega) = self.revs(omega) * 60.0
    
    def self.inertia(mass, radius) = 0.5 * mass * radius ** 2
    def self.volume(radius, extent) = Math::PI * radius ** 2 * extent    # m^3
    def self.liters(radius, extent) = self.volume(radius, extent) * 1000 # L
    def self.density(mass, liters) = mass.to_f / liters
    def self.tangential(rotational, radius) = rotational * radius
    def self.rotational(tangental, radius) = tangential.to_f / radius
    def self.torque(force, radius) = self.tangential(force, radius)
    def self.force(torque, radius) = self.rotational(torque, radius)
    def self.alpha(torque, inertia) = torque.to_f / inertia
    def self.energy(omega, inertia) = 0.5 * inertia * omega ** 2

    def initialize(mass:, radius:, extent:,
                   friction_base: 1, friction_omega: 0.001)
      super(mass:, radius:, extent:, friction_base:, friction_omega:)
    end

    def inertia = Disk.inertia(mass, radius)
    def volume = Disk.volume(radius, extent)
    def liters = Disk.liters(radius, extent)
    def density = Disk.density(mass, self.liters)
    def tangential(rotational) = Disk.tangential(rotational, radius)
    def rotational(tangential) = Disk.rotational(tangential, radius)
    def torque(force) = Disk.torque(force, radius)
    def force(torque) = Disk.force(torque, radius)
    def alpha(torque) = Disk.alpha(torque, self.inertia)
    def energy(omega) = Disk.energy(omega, self.inertia)
    def friction(magnitude) = friction_base + magnitude * friction_omega
  end
  
  # A high-performance, high-precision linear interpolation method.
  # xs must be sorted, with ys dependent on xs (same size).
  # Return interpolated y for any given x.
  def self.interpolate(x, xs:, ys:)
    # Guard Clauses: handle errors and out-of-range values first
    raise("Xs and Ys must have the same size") unless xs.size == ys.size
    return ys.first if x <= xs.first
    return ys.last  if x >= xs.last

    # Binary Search: find the upper bound of the segment containing x
    upper_idx = xs.bsearch_index { |xi| xi > x }

    # Upper Bound: if no xs > x, x must be the last item
    return ys.last if upper_idx.nil?

    # Lower Bound: one below, maybe zero but non-negative
    lower_idx = upper_idx - 1

    # Match Lower Bound: quick return
    return ys[lower_idx] if xs[lower_idx] == x

    # Interpolate!
    last_x, last_y = xs[lower_idx], ys[lower_idx]
    next_x, next_y = xs[upper_idx], ys[upper_idx]
    last_y + (next_y - last_y) * Rational(x - last_x) / (next_x - last_x)
  end

  class TorqueCurve
    # at 500 RPM, 0 torque.  1000 RPM = 70 Nm. 7000, redline.  7100, cutoff
    RPMS    = [500, 1000, 1500, 2000, 2500, 3500, 5000, 6000, 7000, 7100]
    TORQUES = [  0,   70,  130,  200,  250,  320,  330,  320,  260,    0]

    def self.validate_rpms!(rpms)
      raise("rpms should be positive") if rpms.any? { |r| r < 0 }
      rpms.each.with_index { |r, i|
        if i > 0 and r <= rpms[i-1]
          raise("rpms #{rpms.inspect} should increase")
        end
      }
      rpms
    end

    def self.validate_torques!(torques)
      raise("first torque should be zero") unless torques.first == 0
      raise("last torque should be zero") unless torques.last == 0
      raise("torques should be positive") if torques.any? { |t| t < 0 }
      torques
    end

    def initialize(rpms: RPMS, torques: TORQUES)
      if rpms.size != torques.size
        raise("RPMs size #{rpms.size}; Torques size #{torques.size}")
      end
      @rpms = self.class.validate_rpms! rpms
      @torques = self.class.validate_torques! torques
      peak_torque = 0
      idx = 0
      @torques.each.with_index { |t, i|
        if t > peak_torque
          peak_torque = t
          idx = i
        end
      }
      @peak = idx
    end

    def peak
      [@rpms[@peak], @torques[@peak]]
    end

    def to_s
      @rpms.map.with_index { |r, i|
        format("%s RPM %s Nm",
               r.to_s.rjust(5, ' '),
               @torques[i].round(1).to_s.rjust(4, ' '))
      }.join("\n")
    end

    { min: 0,
      idle: 1,
      redline: -2,
      max: -1,
    }.each { |name, idx|
      define_method(name) do @rpms[idx] end
    }

    # interpolate based on torque curve points
    def torque(rpm)
      DrivingPhysics.interpolate(rpm, xs: @rpms, ys: @torques)
    end
  end
  
  CombustionPower = Data.define(:torque_curve)
  CombustionState = Struct.new(:rpm, :throttle)
  ElectricPower = Data.define(:torque)
  ElectricState = Struct.new(:throttle)
  
  RotationState = Struct.new(:theta, :omega)

  EngineComposition = Data.define(:crankshaft, :flywheel)
  AppliedTorque = Struct.new(:value)

  # UserInputSystem: read user input and update throttle(s) (e.g. starter)
  # StarterSystem: add ElectricPower to Crankshaft's AppliedTorque
  # CombustionSystem: read throttle and rpm, find tq on curve, AppliedTorque
  # FrictionSystem: find all Disk, RotationState; subtract from AppliedTorque
  # IntegrationSystem: determine acceleration from torque
  #                    determine angular velocity
  #                    update RotationState and clear AppliedTorque

  class UserInputSystem
    def update(world, dt)
      # We only care about the single engine we created.
      # A real game would query for a "PlayerControlled" component.
      world.query(CombustionState, ElectricState).each do |id|
        motor = world.get(id, CombustionState)
        starter = world.get(id, ElectricState)
        
        # --- Simulate the Starting Sequence ---

        # attempt starting for only 3 seconds
        if world.time <= 3.0
          if motor.rpm < 800
            # below idle, keep the starter on
            if starter.throttle < 1.0
              motor.throttle = 0
              starter.throttle = 1.0
            end
          else
            # above idle, kill the starter and give some throttle
            if starter.throttle > 0
              starter.throttle = 0
              motor.throttle = 0.06
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
        composition = world.get(id, EngineComposition)
        power       = world.get(id, ElectricPower)
        state       = world.get(id, ElectricState)

        next if state.throttle <= 0.0
        
        # Apply throttled torque to the crankshaft
        crank_id = composition.crankshaft
        atq = world.access(crank_id, AppliedTorque) { AppliedTorque.new(0.0) }
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
        composition = world.get(id, EngineComposition)
        power       = world.get(id, CombustionPower)
        state       = world.get(id, CombustionState)
        
        next if state.throttle <= 0.0

        # By design, engagement of the starter motor inhibits combustion
        starter = world.get(id, ElectricState)&.throttle
        next if starter and starter > 0.0
        
        # Calculate torque from the curve and throttle
        tq = power.torque_curve.torque(state.rpm) * state.throttle
        crank_id = composition.crankshaft
        atq = world.access(crank_id, AppliedTorque) { AppliedTorque.new(0.0) }
        atq.value += tq
      end
    end
  end


  # TODO: currently the combustion system only applies torque to the crank
  #       and so with the flywheel never seeing torque, it never adds frictional
  #       resistance
  class FrictionSystem
    def update(world, dt)
      # Find ALL disks with rotation state
      world.query(Disk, RotationState).each do |id|
        disk    = world.get(id, Disk)
        state   = world.get(id, RotationState)

        # friction only applies if we're moving
        if state.omega > 0
          atq = world.access(id, AppliedTorque) { AppliedTorque.new(0.0) }
          atq.value -= disk.friction(state.omega)
        end
      end
    end
  end

  class FrictionSystem
    def update(world, dt)
      # remember which engine assemblies have been handled
      engine_disk_ids = Set.new
      
      # Handle engine assemblies (rigidly connected components)
      world.query(EngineComposition).each do |engine_id|
        composition = world.get(engine_id, EngineComposition)
        crank_id    = composition.crankshaft
        flywheel_id = composition.flywheel

        # don't apply friction to these, later below
        engine_disk_ids.merge [crank_id, flywheel_id]
        
        # Get the rotation state, identical for crank and flywheel
        crank_state = world.get(crank_id, RotationState)
      
        # Only apply friction if we're moving
        if crank_state.omega > 0
          # Get both disk definitions to calculate total friction
          crank_disk    = world.get(crank_id, Disk)
          flywheel_disk = world.get(flywheel_id, Disk)
          
          # Calculate friction for both disks based on their current omega
          total_friction = crank_disk.friction(crank_state.omega) + 
                           flywheel_disk.friction(crank_state.omega)
          
          # Apply the total friction to the crankshaft (the driven component)
          atq = world.access(crank_id, AppliedTorque) { AppliedTorque.new(0.0) }
          atq.value -= total_friction
        end
      end
    
      # Handle standalone disks (not part of an engine assembly)
      world.query(Disk, RotationState).each do |id|
        # Skip if this disk is part of an engine (handled above)
        next if engine_disk_ids.include?(id)
        
        disk  = world.get(id, Disk)
        state = world.get(id, RotationState)
        
        # friction only applies if we're moving
        if state.omega > 0
          atq = world.access(id, AppliedTorque) { AppliedTorque.new(0.0) }
          atq.value -= disk.friction(state.omega)
        end
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
        composition = world.get(id, EngineComposition)
        crank_id    = composition.crankshaft
        flywheel_id = composition.flywheel
        
        # Get components for both parts
        crank_def      = world.get(crank_id, Disk)
        crank_state    = world.get(crank_id, RotationState)
        flywheel_def   = world.get(flywheel_id, Disk)
        flywheel_state = world.get(flywheel_id, RotationState)
        
        # Get the torque applied to each part (usually just the crank)
        net_torque = [crank_id, flywheel_id].map { |id|
          world.get(id, AppliedTorque)&.value || 0.0
        }.sum
        
        # Combine inertia to determine combined velocity from acceleration
        total_inertia = crank_def.inertia + flywheel_def.inertia
        omega = Disk.alpha(net_torque, total_inertia) * dt
        
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
        engine_state = world.get(id, CombustionState)
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

if __FILE__ == $0
  include DrivingPhysics

  # let's build an engine

  # create world and reusable components / definitions
  world = World.new
  
  # create a crankshaft entity
  crank_id = world.create_entity
  world.add(crank_id, Disk.new(mass: 20, radius: 0.05, extent: 0.2))
  world.add(crank_id, RotationState.new(0.0, 0.0))

  # create a flywheel entity
  fly_id = world.create_entity
  world.add(fly_id, Disk.new(mass: 12, radius: 0.165, extent: 0.03))
  world.add(fly_id, RotationState.new(0.0, 0.0))

  # create the engine entity
  engine = world.create_entity

  # give it combustion power
  tc = TorqueCurve.new
  world.add(engine, CombustionPower.new(torque_curve: tc))
  world.add(engine, CombustionState.new(rpm: 0, throttle: 0))

  # give it a starter motor
  world.add(engine, ElectricPower.new(torque: 25))
  world.add(engine, ElectricState.new(throttle: 0))

  # attach the crankshaft and flywheel to the engine
  composition = EngineComposition.new(crankshaft: crank_id, flywheel: fly_id)
  world.add(engine, composition)

  # add systems; order matters
  world.systems = [UserInputSystem.new,
                   StarterSystem.new,
                   CombustionSystem.new,
                   FrictionSystem.new,
                   IntegrationSystem.new]

  # start the simulation
  accumulator = Rational(0)
  deadline = 1/10r # 0.1 seconds
  
  while world.time < 10.0
    # fake render
    sleep world.tick * (1 + rand(4))

    # how much wall time has elapsed?
    frame_time = world.sync

    # update the accumulator, with a safety cap
    accumulator += (frame_time < deadline ? frame_time : deadline)

    # drain the accumulator by running fixed-size physics steps
    while accumulator >= world.tick
      # run physics ticks
      world.update
      accumulator -= world.tick
    end

    # print status report
    starter = world.get(engine, ElectricState)
    motor = world.get(engine, CombustionState)

    if starter.throttle > 0
      torque = world.get(engine, ElectricPower).torque * starter.throttle
    elsif motor.throttle > 0
      torque =
        world.get(engine, CombustionPower).torque_curve.torque(motor.rpm) *
        motor.throttle
    else
      torque = 0
    end
      
    puts format("Time: %.2f | Starter: %s | Throttle: %.3f | " +
                "Torque: %.3f Nm | RPM: %i",
                world.time,
                starter.throttle > 0 ? 'on' : 'off',
                motor.throttle,
                torque,
                motor.rpm)
  end
end
