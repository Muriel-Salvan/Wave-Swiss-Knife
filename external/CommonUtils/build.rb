lLibName = 'CommonUtils'

require 'mkmf'
require 'fileutils'
# Create it as static, as Ruby does not seem to be able to require libraries linking to external shared libraries (at least on cygwin), even when LD_LIBRARY_PATH is set correctly. The only workaround (unacceptable) is to put the shared library in the exact same directory as the Ruby library.
$static = true
$CFLAGS += ' -Wall -Iinclude'
create_makefile(lLibName, 'src')
system('make static')
FileUtils::mkdir_p('lib')
FileUtils::mkdir_p('obj')
Dir.glob('*.o').each do |iObjectFile|
  FileUtils::mv(iObjectFile, "obj/#{File.basename(iObjectFile)}")
end
Dir.glob('*.a').each do |iLibFile|
  # Create the file for ld to link with
  FileUtils::mv(iLibFile, "lib/lib#{File.basename(iLibFile)}")
end
