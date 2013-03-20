#--
# Copyright (c) 2013 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'fileutils'

# Change for upgrading version
lGMPBaseName = 'gmp-5.1.1'
lRootDir = File.expand_path(Dir.getwd)
lGMPDir = "#{lRootDir}/gmp"
lGMPInstallDir = "#{lRootDir}/gmp/#{lGMPBaseName}-install"

FileUtils::mkdir_p(lGMPDir)
Dir.chdir(lGMPDir)
raise RuntimeError if !system("wget ftp://ftp.gmplib.org/pub/gmp/#{lGMPBaseName}.tar.bz2")
raise RuntimeError if !system("tar xvjf #{lGMPBaseName}.tar.bz2")
Dir.chdir(lGMPBaseName)
raise RuntimeError if !system("./configure --prefix=#{lGMPInstallDir}")
raise RuntimeError if !system('make')
raise RuntimeError if !system('make install')
