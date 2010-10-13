lAdditionalLocalLibs = [
  'CommonUtils'
]

require 'mkmf'
$CFLAGS += ' -Wall '
lAdditionalLocalLibs.each do |iLibName|
  lLibDir = File.expand_path("#{File.dirname(__FILE__)}/../../../external/#{iLibName}")
  $CFLAGS += " -I#{lLibDir}/include "
  $LDFLAGS += " -L#{lLibDir}/lib -l#{iLibName} "
end
create_makefile('VolumeUtils')
system('make')
