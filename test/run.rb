#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rUtilAnts/Logging'
RUtilAnts::Logging::initializeLogging('', '', true)
activateLogDebug(true)

# Run all tests
Dir.glob("#{File.dirname(__FILE__)}/WSK/**/*").sort.each do |iFileName|
  require iFileName
end
