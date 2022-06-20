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

task :mrblib do
  # mruby/mrblib/*rb
  # lib/driving_physics/*.rb
  # lib/driving_physics.rb
  dest_dir = 'mruby/mrblib'
  raise "#{dest_dir} is not accessible" unless File.directory? dest_dir

  files = ['lib/driving_physics.rb'] + Dir['lib/driving_physics/*.rb']
  outfiles = []
  files.each { |file|
    lines = []
    # line includes trailing newline
    File.readlines(file).each { |line|
      lines << line unless line.match /\A *require/
    }
    outfile = File.join(dest_dir, File.basename(file))
    File.open(outfile, 'w') { |f| f.write lines.join }
    outfiles << outfile
  }
  puts outfiles
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
