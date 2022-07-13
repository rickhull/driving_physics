require 'driving_physics/timer'

module DrivingPhysics
  module CLI
    # returns user input as a string
    def self.prompt(msg = '', default: '')
      unless msg.empty?
        print msg + ' '
        print '(' + default + ')' unless default.empty?

      print msg + ' ' unless msg.empty?
      print '> '
      input = $stdin.gets.chomp
      input.empty? ? default : input
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
end
