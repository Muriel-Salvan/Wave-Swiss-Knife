#!env ruby
#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Main file

require 'rUtilAnts/Logging'
RUtilAnts::Logging::initializeLogging('', '')
require 'WSK/Common'
require 'WSK/Launcher'

exit WSK::Launcher.new.execute(ARGV)
