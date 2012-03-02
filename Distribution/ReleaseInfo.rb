#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

RubyPackager::ReleaseInfo.new.
  author(
    :name => 'Muriel Salvan',
    :email => 'muriel@x-aeon.com',
    :web_page_url => 'http://murielsalvan.users.sourceforge.net'
  ).
  project(
    :name => 'WaveSwissKnife',
    :web_page_url => 'http://waveswissknife.sourceforge.net/',
    :summary => 'Command-line tool performing various operations on Wave files.',
    :description => 'WSK is a command-line utility that processes WAV audio PCM files to apply audio filters, analysis tools or signals generation plugins: Test audio hardware bit-perfect fidelity, by providing many ways to compare and analyze WAV files ; Process audio files for mastering engineers (noise gates, mixers...).',
    :image_url => 'http://waveswissknife.sourceforge.net/wiki/images/c/c9/Logo.png',
    :favicon_url => 'http://waveswissknife.sourceforge.net/wiki/images/2/26/Favicon.png',
    :browse_source_url => 'http://waveswissknife.git.sourceforge.net/',
    :dev_status => 'Beta'
  ).
  add_core_files( [
    '{lib,bin}/**/*',
    '{ext,external}/**/*.{rb,c,h}'
  ] ).
  add_test_files( [
    'test/**/*'
  ] ).
  add_additional_files( [
    'README',
    'LICENSE',
    'AUTHORS',
    'Credits',
    'ChangeLog'
  ] ).
  gem(
    :gem_name => 'WaveSwissKnife',
    :gem_platform_class_name => 'Gem::Platform::CURRENT',
    :require_paths => [ 'lib', 'ext' ],
    :has_rdoc => true,
    :test_file => 'test/run.rb',
    :gem_dependencies => [
      [ 'rUtilAnts', '>= 1.0' ]
    ],
    :extensions => [
      'ext/WSK/AnalyzeUtils/extconf.rb',
      'ext/WSK/ArithmUtils/extconf.rb',
      'ext/WSK/FFTUtils/extconf.rb',
      'ext/WSK/FunctionUtils/extconf.rb',
      'ext/WSK/SilentUtils/extconf.rb',
      'ext/WSK/VolumeUtils/extconf.rb'
    ]
  ).
  source_forge(
    :login => 'murielsalvan',
    :project_unix_name => 'waveswissknife',
    :ask_for_key_passphrase => true
  ).
  ruby_forge(
    :project_unix_name => 'waveswissknife'
  ).
  executable(
    :startup_rb_file => 'bin/WSK.rb'
  )

