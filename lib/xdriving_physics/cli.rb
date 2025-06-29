require 'driving_physics/timer'

module DrivingPhysics
  module CLI
    # returns user input as a string
    def self.prompt(msg = '', default: nil)
      print "#{msg} " unless msg.empty?
      print "(#{default}) " unless default.nil?
      print '> '
      input = $stdin.gets.chomp
      input.empty? ? default.to_s : input
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
