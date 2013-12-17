#--
# Copyright (c) 2012 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rubygems'
require 'mkmf'

ROOT_DIR = File.expand_path("#{File.dirname(__FILE__)}/../..")

# Build external libraries.
# Set CFLAGS and LDFLAGS accordingly.
#
# Parameters::
# * *iLstExternalLibs* (<em>list<String></em>): List of external libraries names (taken from the external directory)
def build_external_libs(*iLstExternalLibs)
  require 'rUtilAnts/Misc'
  RUtilAnts::Misc::install_misc_on_object
  iLstExternalLibs.each do |iLibName|
    lLibDir = File.expand_path("#{File.dirname(__FILE__)}/../../external/#{iLibName}")
    # Build the external library first
    # Don't do it from this environment, as it can modify global compilation variables
    change_dir(lLibDir) do
      lCmd = 'ruby -w build.rb'
      raise "Unable to build external library #{iLibName} (using #{lCmd}): #{$?.inspect}" if (!system(lCmd)) or (($? != nil) and ($? != 0))
    end
    $CFLAGS += " -I#{lLibDir}/include "
    $LDFLAGS += " -L#{lLibDir}/lib -l#{iLibName} "
  end
end

# Execute a command, with nice logging and error handling around
#
# Parameters:
# * *iCmd* (_String_): Command to execute
def exec_cmd(iCmd)
  puts "[#{Dir.getwd}]> #{iCmd}"
  raise RuntimeError, "Unable to execute \"#{iCmd}\" on your system." if !system(iCmd)
  puts ''
end

# Build a local copy of GMP, downloaded directly from the Internet
def build_local_gmp
  lGMPBaseName = 'gmp-5.1.3'
  lGMPDir = "#{ROOT_DIR}/gmp"
  lGMPInstallDir = "#{ROOT_DIR}/gmp/#{lGMPBaseName}-install"

  puts "**** Have to download, compile and install the GMP library in #{lGMPInstallDir}."
  puts ''

  FileUtils::mkdir_p(lGMPDir)
  lOldDir = Dir.getwd
  Dir.chdir(lGMPDir)
  begin
    puts "** Download #{lGMPBaseName} from ftp://ftp.gmplib.org/pub/gmp/#{lGMPBaseName}.tar.bz2 ..."
    require 'net/ftp'
    ftp = Net::FTP.new('ftp.gmplib.org')
    ftp.login
    ftp.getbinaryfile("pub/gmp/#{lGMPBaseName}.tar.bz2")
    ftp.close
    puts '** Extract archive contents ...'
    exec_cmd "tar xjf #{lGMPBaseName}.tar.bz2"
    Dir.chdir(lGMPBaseName)
    puts '** Configure GMP for compilation ...'
    exec_cmd "sh ./configure --prefix=#{lGMPInstallDir}"
    puts '** Compile GMP ...'
    exec_cmd 'make'
    puts "** Install locally GMP in #{lGMPInstallDir} ..."
    exec_cmd 'make install'
  ensure
    Dir.chdir(lOldDir)
  end

  puts "**** GMP installed correctly in #{lGMPInstallDir}."
  puts ''
end

# Look for GMP in system and locally
# If it is found, compilation and link options will include it
#
# Return:
# * _Boolean_: Has GMP been found?
def find_gmp
  rSuccess = have_library('gmp','mpz_get_str','gmp.h')

  if (!rSuccess)
    # Find locally installed GMP
    lGMPDir = File.expand_path("#{File.dirname(__FILE__)}/../../gmp")
    if (File.exist?(lGMPDir))
      lLastInstalledGMP = Dir.glob("#{lGMPDir}/*-install").sort[-1]
      if (lLastInstalledGMP != nil)
        puts "Found GMP installed in #{lLastInstalledGMP}."
        find_header('gmp.h',"#{lLastInstalledGMP}/include")
        find_library('gmp',nil,"#{lLastInstalledGMP}/lib")
        rSuccess = true
      else
        puts 'Could not find GMP library installed locally.'
      end
    end
  end

  return rSuccess
end

$CFLAGS += ' -Wall '
if (!find_gmp)
  build_local_gmp
  raise RuntimeError, 'Unable to install GMP library automatically. Please do it manually from http://gmplib.org before attempting to install WaveSwissKnife.' unless find_gmp
end

build_external_libs('CommonUtils')
