require 'driving_physics'

# treat instances of this class as immutable
# Tire::Condition has mutable attributes
#
class DrivingPhysics::Tire
  class Error < RuntimeError; end

  attr_accessor :roll_cof,
                :tread_mm,
                :cords_mm,
                :radius_mm,
                :g_factor,
                :max_heat_cycles,
                :temp_profile,
                :condition

  def initialize
    @roll_cof = DrivingPhysics::Force::ROLL_COF
    @tread_mm = 10
    @cords_mm = 1
    @radius_mm = 350
    @g_factor = 1.0
    @max_heat_cycles = 50
    @temp_profile = TemperatureProfile.new

    yield self if block_given?
    @condition = Condition.new(tread_mm: @tread_mm, cords_mm: @cords_mm)
  end

  def to_s
    [[format("Grip: %.2f / %.1f G", max_g, @g_factor),
      format("Radius: %d mm", @radius_mm),
      format("RR: %.3f", @roll_cof),
     ].join(' | '),
     @condition,
    ].join("\n")
  end

  def tread_left?
    @condition.tread_mm > 0.0
  end

  # cords give half the traction as tread
  def tread_factor
    tread_left? ? 1.0 : 0.5 * @condition.cords_mm / @cords_mm
  end

  # up to max_heat_cycles, the grip decays down to 80%
  # beyond max_heat_cycles, the grip decay plateaus at 80%
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

  # treat instances of this class as immutable
  class TemperatureProfile
    class Error < DrivingPhysics::Tire::Error; end

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

    def to_s
      lines = []
      @deg_c.each_with_index { |deg, i|
        lines << [deg, @grip_pct[i]].join("\t")
      }
      lines.join("\n")
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

  # treat attributes of this class as *mutable*
  class Condition
    class Error < DrivingPhysics::Tire::Error; end
    class Destroyed < Error; end

    DEFAULT_TEMP = DrivingPhysics::AMBIENT_TEMP

    attr_accessor :tread_mm,
                  :cords_mm,
                  :temp_c,
                  :heat_cycles,
                  :debug_temp,
                  :debug_wear

    def initialize(temp_c: DEFAULT_TEMP, tread_mm:, cords_mm:)
      @tread_mm = tread_mm.to_f
      @cords_mm = cords_mm.to_f
      @temp_c = temp_c.to_f
      @heat_cycles = 0
      @hottest_temp = @temp_c
      @debug_temp = false
      @debug_wear = false
    end

    def to_s
      [format("Temp: %.1f C", @temp_c),
       format("Tread: %.2f (%.1f) mm", @tread_mm, @cords_mm),
       format("Cycles: %d", @heat_cycles),
      ].join(' | ')
    end

    def temp_tick(ambient_temp:, g:, slide_speed:,
                  mass:, tire_mass:, critical_temp:)
      # env:
      # * mass (kg) (e.g. 1000 kg)
      # * tire_mass (kg) (e.g. 10 kg)
      # * critical temp (c) (e.g. 100c)
      # * g (e.g. 1.0 g)
      # * slide_speed (m/s) (typically 0.1, up to 1 or 10 or 50)
      # * ambient_temp (c) (e.g. 30c)

      # g gives a target temp between 25 and 100
      # at 0g, tire tends to ambient temp
      # at 1g, tire tends to 100 c
      # that 100c upper target also gets adjusted due to ambient temps

      target_hot = critical_temp + 5
      ambient_diff = DEFAULT_TEMP - ambient_temp
      target_hot -= (ambient_diff / 2)
      puts "target_hot=#{target_hot}" if @debug_temp

      if slide_speed <= 0.1
        target_g_temp = ambient_temp + (target_hot - ambient_temp) * g
      else
        target_g_temp = target_hot
      end
      puts "target_g_temp=#{target_g_temp}" if @debug_temp

      slide_factor = slide_speed * 5
      target_slide_temp = target_g_temp + slide_factor

      puts "target_slide_temp=#{target_slide_temp}" if @debug_temp

      # temp_tick is presumed to be +1.0 or -1.0 (100th of a degree)
      # more mass biases towards heat
      # more tire mass biases for smaller tick

      tick = @temp_c < target_slide_temp ? 1.0 : -1.0
      tick += slide_speed / 10
      puts "base tick: #{tick}" if @debug_temp

      mass_factor = (mass - 1000).to_f / 1000
      if mass_factor < 0
        # lighter car cools quicker; heats slower
        tick += mass_factor
      else
        # heavier car cools slower, heats quicker
        tick += mass_factor / 10
      end
      puts "mass tick: #{tick}" if @debug_temp

      tire_mass_factor = (tire_mass - 10).to_f / 10
      if tire_mass_factor < 0
        # lighter tire has bigger tick
        tick -= tire_mass_factor
      else
        # heavier tire has smaller tick
        tire_mass_factor = (tire_mass - 10).to_f / 100
        tick -= tire_mass_factor
      end
      puts "tire mass tick: #{tick}" if @debug_temp
      puts if @debug_temp

      tick
    end

    def wear_tick(g:, slide_speed:, mass:, critical_temp:)
      # cold tires wear less
      tick = [0, @temp_c.to_f / critical_temp].max
      puts "wear tick: #{tick}" if @debug_wear

      # lower gs reduce wear in the absence of sliding
      tick *= g if slide_speed <= 0.1
      puts "g wear tick: #{tick}" if @debug_wear

      # slide wear
      tick += slide_speed
      puts "slide wear tick: #{tick}" if @debug_wear
      puts if @debug_wear
      tick
    end


    def tick!(ambient_temp:, g:, slide_speed:,
              mass:, tire_mass:, critical_temp:)

      # heat cycle:
      # when the tire goes above the critical temp and then
      # cools significantly below the critical temp
      # track @hottest_temp

      @temp_c += temp_tick(ambient_temp: ambient_temp,
                           g: g,
                           slide_speed: slide_speed,
                           mass: mass,
                           tire_mass: tire_mass,
                           critical_temp: critical_temp) / 100
      @hottest_temp = @temp_c if @temp_c > @hottest_temp
      if @hottest_temp > critical_temp and @temp_c < critical_temp * 0.8
        @heat_cycles += 1
        @hottest_temp = @temp_c
      end

      # a tire should last for 30 minutes at 1g sustained
      # with minimal sliding
      # 100 ticks / sec
      # 6000 ticks / min
      # 180_000 ticks / 30 min
      # 10mm = 180_000 ticks
      # wear_tick is nominally 1 / 18_000 mm

      wt = wear_tick(g: g,
                     slide_speed: slide_speed,
                     mass: mass,
                     critical_temp: critical_temp)

      if @tread_mm > 0
        @tread_mm -= wt / 18000
        @tread_mm = 0 if @tread_mm < 0
      else
        # cords wear 2x faster
        @cords_mm -= wt * 2 / 18000
        if @cords_mm <= 0
          raise(Destroyed, "no more cords")
        end
      end
    end
  end
end
