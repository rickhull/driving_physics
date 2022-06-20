module DrivingPhysics
  module CLI
    # returns user input as a string
    def self.prompt(msg = '')
      print msg + ' ' unless msg.empty?
      print '> '
      $stdin.gets.chomp
    end

    # press Enter to continue, ignore input, return elapsed time
    def self.pause(msg = '')
      t = Timer.now
      puts msg unless msg.empty?
      puts '     [ Press Enter ]'
      $stdin.gets
      Timer.since(t)
    end
  end

  module Timer
    def self.now
      Time.now
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
