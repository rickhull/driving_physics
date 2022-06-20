require 'rake/testtask'

Rake::TestTask.new :test do |t|
  t.pattern = "test/*.rb"
  t.warning = true
end

desc "Run demo scripts"
task demo: [:test] do
  Dir['demo/*.rb'].each { |filepath|
    puts
    sh "ruby -w -Ilib #{filepath}"
    puts
  }
end

task default: :test

desc "Copy lib/**/*.rb to mruby/mrblib/*.rb"
task :mrblib do
  # COPY:
  # lib/driving_physics/*.rb
  # lib/driving_physics.rb
  #
  # TO:
  # mruby/mrblib/driving_physics.rb
  #
  # CONCATENATE:
  # all files together
  #
  # REMOVE:
  # all requires along the way
  #
  dest_dir =  File.join(%w[mruby mrblib])
  raise "#{dest_dir} is not accessible" unless File.directory? dest_dir
  dest_file = File.open(File.join(dest_dir, 'driving_physics.rb'), 'w')
  line_count = 0
  # slurp all into one file without requires; order matters
  files = [File.join(%w[lib driving_physics mruby.rb]),
           File.join(%w[lib driving_physics.rb])] +
           %w[environment imperial power
              disk tire motor gearbox powertrain car].map { |name|
    File.join ['lib', 'driving_physics', [name, 'rb'].join('.')]
  }

  files.each { |file|
    File.readlines(file).each { |line|
      next if line.match /\A *(?:require|autoload)/
      dest_file.write(line)
      line_count += 1
    }
    puts "wrote #{file} to #{dest_file.path}"
  }
  puts "wrote #{line_count} lines to #{dest_file.path}"
end

task mrbc: :mrblib do
  rb_file  = File.join(%w[mruby mrblib driving_physics.rb])
  mrb_file = File.join(%w[mruby mrblib driving_physics.mrb])

  sh('mrbc', rb_file) { |ok, res|
    if !ok
      p res
    end
  }
end

#
# METRICS
#

begin
  require 'flog_task'
  FlogTask.new do |t|
    t.threshold = 9000
    t.dirs = ['lib']
    t.verbose = true
  end
rescue LoadError
  warn 'flog_task unavailable'
end

begin
  # need to stop looking in old/ and also the scoring seems wack
  if false
    require 'flay_task'
    FlayTask.new do |t|
      t.dirs = ['lib']
      t.verbose = true
    end
  end
rescue LoadError
  warn 'flay_task unavailable'
end

begin
  require 'roodi_task'
  # RoodiTask.new config: '.roodi.yml', patterns: ['lib/**/*.rb']
  RoodiTask.new patterns: ['lib/**/*.rb']
rescue LoadError
  warn "roodi_task unavailable"
end

#
# GEM BUILD / PUBLISH
#

begin
  require 'buildar'

  Buildar.new do |b|
    b.gemspec_file = 'driving_physics.gemspec'
    b.version_file = 'VERSION'
    b.use_git = true
  end
rescue LoadError
  warn "buildar tasks unavailable"
end
