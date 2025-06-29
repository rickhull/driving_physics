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

# On time:
# Logical timekeeping is Rational, so fp errors do not accumulate
#   TARGET_HZ = 100, dt = 1/100r
# Physical timekeeping is Float, via World.wall_time
#   The simulation loop will adjust to maintain TARGET_HZ
# Physical calculation is Float, as calculations are reset every frame
#   Theta, Omega, Alpha, Torque, Radius, Mass, Inertia -- all floats
# Simulation time is deterministic, and so may exceed wall clock time.
# If the simulation time is less than wall clock time, sleep to maintain
#   a regular render interval and reach wall clock time.
module DrivingPhysics
  class World
    class GetError < RuntimeError; end

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

    # physics should update 100x per second
    TARGET_HZ = 100

    attr_accessor :systems, :dt
    attr_reader :entities, :ticks

    def initialize
      @entities = {}   # id => Set[klass]
      @components = {} # klass => { id => component }
      @systems = []    # ordered list of system instances
      @next_id = 0
      @ticks = 0
      @wall_time = World.wall_time
      self.hz = TARGET_HZ # @dt = 1/100r
    end

    def hz=(val)
      @dt = Rational(1) / val
    end

    def dt=(val)
      @dt = val.rationalize
    end

    def time
      @ticks * @dt
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

    def get!(id, klass)
      self.get(id, klass) or raise(GetError, "#{id} #{klass}")
    end
    
    # get the component or try klass.new if it doesn't exist
    def access(id, klass, &creation)
      self.get(id, klass) or self.add(id, klass.new)
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

    def update(dt = @dt)
      @ticks += 1
      @systems.each { |system| system.update(self, dt) }
    end
  end
end
