Gem::Specification.new do |s|
  s.name = 'driving_physics'
  s.summary = "WIP"
  s.description = "WIP"
  s.authors = ["Rick Hull"]
  s.homepage = "https://github.com/rickhull/driving_physics"
  s.license = "LGPL-3.0"

  s.required_ruby_version = "> 2"
  s.add_runtime_dependency 'device_control', '~> 0.3'

  s.version = File.read(File.join(__dir__, 'VERSION')).chomp

  s.files = %w[driving_physics.gemspec VERSION README.md Rakefile]
  s.files += Dir['lib/**/*.rb']
  s.files += Dir['test/**/*.rb']
  s.files += Dir['demo/**/*.rb']
end
