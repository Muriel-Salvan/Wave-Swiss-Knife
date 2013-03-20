#--
# Copyright (c) 2012 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

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

require 'mkmf'
$CFLAGS += ' -Wall '
if (!have_library('gmp','mpz_get_str','gmp.h'))
  # Find locally installed GMP
  lGMPDir = File.expand_path("#{File.dirname(__FILE__)}/../../gmp")
  if (File.exist?(lGMPDir))
    lLastInstalledGMP = Dir.glob("#{lGMPDir}/*-install").sort[-1]
    puts "Take GMP installed in #{lLastInstalledGMP}"
    find_header('gmp.h',"#{lLastInstalledGMP}/include")
    find_library('gmp',nil,"#{lLastInstalledGMP}/lib")
  end
end

build_external_libs('CommonUtils')
