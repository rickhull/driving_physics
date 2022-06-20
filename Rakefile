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

#
# mruby
#

def write_mrblib(input_file, append: false)
  dest_dir =  File.join(%w[mruby mrblib])
  raise "#{dest_dir} is not accessible" unless File.directory? dest_dir
  write_mode = append ? 'a' : 'w'
  dest_file = File.open(File.join(dest_dir, 'driving_physics.rb'), write_mode)
  line_count = 0

  File.readlines(input_file).each { |line|
    next if line.match /\A *(?:require|autoload)/
    dest_file.write(line)
    line_count += 1
  }
  line_count
end

desc "Copy lib/**/*.rb to mruby/mrblib/*.rb"
task :mrblib do
  line_count = write_mrblib(File.join(%w[lib driving_physics.rb]))
  %w[mruby environment imperial power
     disk tire motor gearbox powertrain car].each { |name|
    file = File.join ['lib', 'driving_physics', [name, 'rb'].join('.')]
    line_count += write_mrblib(file, append: true)
    puts "wrote #{file} to mrblib"
  }
  puts "wrote #{line_count} lines to mrblib"
end

%w[disk tire motor gearbox powertrain car].each { |name|
  task "demo_#{name}" do
    lines = write_mrblib(File.join('demo', "#{name}.rb"), append: true)
    puts "wrote #{lines} lines to mrblib"
  end
}

task :mrbc do
  rb_file  = File.join(%w[mruby mrblib driving_physics.rb])
  mrb_file = File.join(%w[mruby mrblib driving_physics.mrb])
  sh('mrbc', '-c', rb_file)
  sh('mrbc', rb_file)
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
