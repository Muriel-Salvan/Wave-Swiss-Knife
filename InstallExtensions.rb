#--
# Copyright (c) 2013 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'mkmf'
if (!have_library('gmp','mpz_get_str','gmp.h'))
  puts 'Missing GMP library. Downloading, compiling and installing it locally in ./gmp'
  load 'InstallGMP.rb'
end
load 'BuildExt.rb'
