MRuby::Gem::Specification.new('mruby-driving-physics') do |spec|
  spec.license = 'LGPL-3.0'
  spec.authors = 'Rick Hull'
  spec.summary = 'Physical simulation for driving cars'

  spec.rbfiles = Dir.glob("#{spec.dir}/mrblib/**/*.rb").sort.reverse
end
