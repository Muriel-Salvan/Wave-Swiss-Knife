#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

RubyPackager::ReleaseInfo.new.
  author(
    :Name => 'Muriel Salvan',
    :EMail => 'murielsalvan@users.sourceforge.net',
    :WebPageURL => 'http://murielsalvan.users.sourceforge.net'
  ).
  project(
    :Name => 'WaveSwissKnife',
    :WebPageURL => 'http://waveswissknife.sourceforge.net/',
    :Summary => 'Command-line tool performing various operations on Wave files.',
    :Description => 'WSK is a command-line utility that processes WAV audio PCM files to apply audio filters, analysis tools or signals generation plugins: Test audio hardware bit-perfect fidelity, by providing many ways to compare and analyze WAV files ; Process audio files for mastering engineers (noise gates, mixers...).',
    :ImageURL => 'http://waveswissknife.sourceforge.net/wiki/images/c/c9/Logo.png',
    :FaviconURL => 'http://waveswissknife.sourceforge.net/wiki/images/2/26/Favicon.png',
    :SVNBrowseURL => 'http://waveswissknife.git.sourceforge.net/',
    :DevStatus => 'Beta'
  ).
  addCoreFiles( [
    '{lib,bin,ext}/**/*'
    # Add external directory for releases that have to compile.
    # TODO (RubyPackager): Make RubyPackager handle compilable packages.
  ] ).
  addTestFiles( [
    'test/**/*'
  ] ).
  addAdditionalFiles( [
    'README',
    'LICENSE',
    'AUTHORS',
    'Credits',
    'ChangeLog'
  ] ).
  gem(
    :GemName => 'WaveSwissKnife',
    :GemPlatformClassName => 'Gem::Platform::CURRENT',
    :RequirePaths => [ 'lib', 'ext' ],
    :HasRDoc => true,
    :TestFile => 'test/run.rb',
    :GemDependencies => [
      [ 'rUtilAnts', '>= 0.1' ]
    ]
  ).
  sourceForge(
    :Login => 'murielsalvan',
    :ProjectUnixName => 'waveswissknife'
  ).
  rubyForge(
    :ProjectUnixName => 'waveswissknife'
  ).
  executable(
    :StartupRBFile => 'bin/WSK.rb'
  )

