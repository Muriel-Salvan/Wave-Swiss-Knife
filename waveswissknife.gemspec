# This file is a dummy gemspec that bundle asks for
# This project is packaged using RubyPackager: http://rubypackager.sourceforge.net

Gem::Specification.new do |s|
  s.name        = 'WaveSwissKnife'
  s.version     = '0.0.1'
  s.add_dependency('rUtilAnts', '>= 1.0')
  s.extensions = [
    'ext/WSK/AnalyzeUtils/extconf.rb',
    'ext/WSK/ArithmUtils/extconf.rb',
    'ext/WSK/FFTUtils/extconf.rb',
    'ext/WSK/FunctionUtils/extconf.rb',
    'ext/WSK/SilentUtils/extconf.rb',
    'ext/WSK/VolumeUtils/extconf.rb'
  ]
  s.summary = ''
  s.authors = ''

end
