#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require "#{File.dirname(__FILE__)}/../CommonBuild"
# TODO (Cygwin): Adding -L/usr/local/lib is due to some Cygwin installs that do not include it with gcc
$LDFLAGS += ' -L/usr/local/lib '
begin
  have_library('gmp')
rescue Exception
  puts "\n\n!!! Missing library gmp in this system. Please install it from http://gmplib.org/\n\n"
  raise
end
create_makefile('FFTUtils')
