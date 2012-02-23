#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rUtilAnts/Logging'
RUtilAnts::Logging::install_logger_on_object(:mute_stdout => true, :debug_mode => true)

lWSKRootDir = File.expand_path("#{File.dirname(__FILE__)}/..")

# Add lib path to the LOAD_PATH
$: << "#{lWSKRootDir}/lib"
# Add ext path to the LOAD_PATH
$: << "#{lWSKRootDir}/ext"

# Run all tests
Dir.glob("#{lWSKRootDir}/test/WSK/**/*").sort.each do |iFileName|
  require iFileName
end
