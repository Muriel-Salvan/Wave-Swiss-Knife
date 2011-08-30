#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

lAdditionalLocalLibs = [
  'CommonUtils'
]

require 'mkmf'
$CFLAGS += ' -Wall '
# TODO (Cygwin): Adding -L/usr/local/lib is due to some Cygwin installs that do not include it with gcc
$LDFLAGS += ' -L/usr/local/lib -lgmp '
lAdditionalLocalLibs.each do |iLibName|
  lLibDir = File.expand_path("#{File.dirname(__FILE__)}/../../../external/#{iLibName}")
  $CFLAGS += " -I#{lLibDir}/include "
  $LDFLAGS += " -L#{lLibDir}/lib -l#{iLibName} "
end
create_makefile('VolumeUtils')
if (!system('make'))
  raise RuntimeError.new("Error while running 'make': #{$?}")
end
