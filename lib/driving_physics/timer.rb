module DrivingPhysics
  module Timer
    # don't use `defined?` with mruby
    if (Process::CLOCK_MONOTONIC rescue false)
      def self.now
        Process.clock_gettime Process::CLOCK_MONOTONIC
      end
    else
      def self.now
        Time.now
      end
    end

    def self.since(t)
      self.now - t
    end

    def self.elapsed(&work)
      t = self.now
      return yield, self.since(t)
    end

    # HH:MM:SS.mmm
    def self.display(seconds: 0, ms: 0)
      ms += (seconds * 1000).round if seconds > 0
      DrivingPhysics.elapsed_display(ms)
    end

    def self.summary(start, num_ticks, paused = 0)
      elapsed = self.since(start) - paused
      format("%.3f s (%d ticks/s)", elapsed, num_ticks.to_f / elapsed)
    end
  end
end
