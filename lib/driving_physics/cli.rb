module DrivingPhysics
  module CLI
    # returns user input as a string
    def self.prompt(msg = '')
      print msg + ' ' unless msg.empty?
      print '> '
      $stdin.gets.chomp
    end

    # press Enter to continue
    def self.pause(msg = '')
      puts msg unless msg.empty?
      puts '     [ Press Enter ]'
      $stdin.gets
    end
  end
end
