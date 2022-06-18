module DrivingPhysics
  module CLI
    # returns user input as a string
    def self.prompt(msg = '')
      print msg + ' ' unless msg.empty?
      print '> '
      $stdin.gets.chomp
    end

    # press Enter to continue
    # return the elapsed time
    def self.pause(msg = '')
      t = Timer.now
      puts msg unless msg.empty?
      puts '     [ Press Enter ]'
      $stdin.gets
      Timer.since(t)
    end
  end

  module Timer
    if defined? Process::CLOCK_MONOTONIC
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

    def self.summary(elapsed, num_ticks)
      format("%.3f s (%d ticks/s)", elapsed, num_ticks.to_f / elapsed)
    end
  end
end
