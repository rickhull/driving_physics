module DrivingPhysics
  # treat instances of this class as immutable
  class Tire
    class Error < RuntimeError; end

    # treat instances of this class as immutable
    class TemperatureProfile
      class Error < Tire::Error; end

      TEMPS = [-100, 0, 25, 50, 75, 80, 85, 95, 100, 105, 110, 120, 130, 150]
      GRIPS = [0.1, 0.5, 0.75, 0.8, 0.9, 0.95, 1.0,
               0.95, 0.9, 0.75, 0.5, 0.25, 0.1, 0.05]
      MIN_GRIP = 0.01

      attr_reader :critical_temp

      def initialize(deg_ary = TEMPS, grip_ary = GRIPS)
        if !deg_ary.is_a?(Array) or !grip_ary.is_a?(Array)
          raise(ArgumentError, "two arrays are required")
        end
        if deg_ary.count != grip_ary.count
          raise(ArgumentError, "arrays don't match")
        end
        @deg_c = deg_ary
        @grip_pct = grip_ary
        determine_critical_temp!
      end

      def grip_factor(temp_c)
        pct = MIN_GRIP
        @deg_c.each_with_index { |deg, i|
          pct = @grip_pct[i] if temp_c >= deg
          break if temp_c < deg
        }
        pct
      end

      private
      def determine_critical_temp!
        return @critical_temp if @critical_temp
        reached_100 = false
        # go up to 100% grip, then back down to less than 80%
        @deg_c.each_with_index { |deg, i|
          next if !reached_100 and @grip_pct[i] < 1.0
          reached_100 = true if @grip_pct[i] == 1.0
          if reached_100 and @grip_pct[i] <= 0.8
            @critical_temp = deg
            break
          end
        }
        raise(Error, "bad profile, can't find 100% grip") unless reached_100
        raise(Error, "bad profile, no critical temp") unless @critical_temp
      end
    end

    # treat instances of this class as *mutable*
    class Condition
      attr_accessor :tread_pct,
                    :cords_pct,
                    :temp_c,
                    :heat_cycles

      def initialize
        @tread_pct = 1.0
        @cords_pct = 1.0
        @temp_c = 25
        @heat_cycles = 0
        @min_cycle_temp = 0
        @max_cycle_temp = 0
      end

      def tick(env)
        # env:
        # * mass (kg) (e.g. 1000 kg)
        # * critical temp (c) (e.g. 100c)
        # * g (e.g. 1.0 g)
        # * slide_speed (m/s) (typically 0.1, up to 1 or 10 or 50)
        # * last_temp_cycle (c) - update if our current temp is on the same
        #                         side of the critical temp but differs more
        #                       -- used to determine the heat cycle magnitude

        # heat cycle:
        #  depends on critical_temp
        #  every time critical temp is crossed by 10% on either side,
        #  add 0.5 heat cycle point, up to max 2 heat cycle points:
        #  e.g.
        #  * critical temp: 100 c
        #    tire warms to 90 c, no heat cycles
        #    tire warms to 100 c, no heat cycles
        #    tire warms to 110c, add 0.5 heat cycle
        #    tire warms to 120c, add 0.5 heat cycles
        #    tire cools to 110c, add 0 heat cycles (still on the hot cycle)
        #    tire warms to 120c, add 0 heat cycles (still on the hot cycle)
        #    tire cools to 90c, add 0.5 heat cycles
        #    tire cools to 80c, add 0.5 heat cycles
        #    tire cools to 25c, add 0 heat cycles (max 1 cycle on cooling)
        #    tire warms to 120c, add 1 heat cycles


        # should be able to sustain 100c at 1.0g, 0.1 m/s slide, 1000 kg
        # wear_tick should be 1.0 at these levels

        # mass:
        # 1 point per 1000 kg

        mass_factor = mass.to_f / 1000




        # based on env: mass, g, slide_spead
        # add wear
        # add/subtract heat

        # heat is based on slide_speed and current_g
        # bias towards 100% grip
        #  hot tires get less heat, subtract more
        #  cold tires get more heat, subtract less

        # wear is based on slide_speed and current_g and current_heat

      end
    end

    attr_accessor :tread_mm,
                  :cords_mm,
                  :radius_mm,
                  :g_factor,
                  :max_heat_cycles,
                  :temp_profile,
                  :condition

    def initialize
      @tread_mm = 10
      @cords_mm = 1
      @radius_mm = 350
      @g_factor = 1.0
      @max_heat_cycles = 50
      @temp_profile = TemperatureProfile.new
      @condition = Condition.new

      yield self if block_given?
    end

    def tread_depth
      @tread_mm * @condition.tread_pct
    end

    def tread_left?
      tread_depth > 0.05
    end

    def tread_factor
      tread_left? ? 1.0 : 0.1 * @condition.cords_pct
    end

    def heat_cycle_factor
      heat_cycles = [@condition.heat_cycles, @max_heat_cycles].min.to_f
      heat_pct = heat_cycles / @max_heat_cycles
      1.0 - 0.2 * heat_pct
    end

    def temp_factor
      @temp_profile.grip_factor(@condition.temp_c)
    end

    def max_g
      @g_factor * temp_factor * heat_cycle_factor * tread_factor
    end
  end
end
