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
