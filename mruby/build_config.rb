MRuby::Build.new do |conf|
  toolchain ENV.fetch('TOOLCHAIN', :gcc)

  conf.enable_debug
  conf.enable_test

  conf.gem __dir__
end
