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
      t = self.now
      puts msg unless msg.empty?
      puts '     [ Press Enter ]'
      $stdin.gets
      self.since(t)
    end

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
  end
end
