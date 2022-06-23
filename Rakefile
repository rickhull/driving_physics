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

MRBLIB_DIR = File.join %w[mruby mrblib]
MRBLIB_FILE = File.join(MRBLIB_DIR, 'driving_physics.rb')
MRBLIB_MRB = File.join(MRBLIB_DIR, 'driving_physics.mrb')
MRUBY_DEMO_DIR = File.join %w[demo mruby]

def write_mruby(input_file, output_file = MRBLIB_FILE, append: false)
  file_obj = File.open(output_file, append ? 'a' : 'w')
  line_count = 0

  File.readlines(input_file).each { |line|
    next if line.match /\A *(?:require|autoload)/
    file_obj.write(line)
    line_count += 1
  }
  file_obj.close
  line_count
end

file MRBLIB_FILE do
  line_count = write_mruby(File.join(%w[lib driving_physics.rb]), MRBLIB_FILE)
  %w[mruby environment imperial power
     disk tire motor gearbox powertrain car].each { |name|
    file = File.join('lib', 'driving_physics', "#{name}.rb")
    line_count += write_mruby(file, MRBLIB_FILE, append: true)
    puts "wrote #{file} to #{MRBLIB_FILE}"
  }
  puts "wrote #{line_count} lines to #{MRBLIB_FILE}"
end

file MRBLIB_MRB => MRBLIB_FILE do
  rb_file  = File.join(%w[mruby mrblib driving_physics.rb])
  mrb_file = File.join(%w[mruby mrblib driving_physics.mrb])
  sh 'mrbc', rb_file
  puts format("%s: %d bytes (created %s)",
              mrb_file, File.size(mrb_file), File.birthtime(mrb_file))
end

file MRUBY_DEMO_DIR do
  mkdir_p MRUBY_DEMO_DIR
end

desc "Map/Filter/Reduce lib/**/*.rb to mruby/mrblib/driving_physics.rb"
task mrblib: MRBLIB_FILE

desc "Compile mruby/mrblib/driving_physics.rb to .mrb bytecode"
task mrbc: MRBLIB_MRB

%w[disk tire motor gearbox powertrain car].each { |name|
  demo_file = File.join(MRUBY_DEMO_DIR, "#{name}.rb")
  demo_mrb = File.join(MRUBY_DEMO_DIR, "#{name}.mrb")

  file demo_file => MRUBY_DEMO_DIR do
    write_mruby(File.join('demo', "#{name}.rb"), demo_file)
  end

  file demo_mrb => demo_file do
    sh 'mrbc', demo_file
  end

  desc "run demo/#{name}.rb via mruby"
  task "demo_#{name}" => [demo_file, MRBLIB_MRB] do
    sh 'mruby', '-r', MRBLIB_MRB, demo_file
  end

  desc "run demo/#{name}.rb via mruby bytecode"
  task "mrb_#{name}" => [demo_mrb, MRBLIB_MRB] do
    sh 'mruby', '-r', MRBLIB_MRB, '-b', demo_mrb
  end
}

desc "Remove generated .rb and .mrb files"
task :clean do
  [MRBLIB_DIR, MRUBY_DEMO_DIR].each { |dir|
    Dir[File.join(dir, '*rb')].each { |file|
      rm file unless File.directory?(file)
    }
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
