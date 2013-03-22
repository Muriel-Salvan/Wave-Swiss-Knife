#!env ruby
#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# Main file
require 'rubygems'
require 'rUtilAnts/Logging'
RUtilAnts::Logging::install_logger_on_object
require 'WSK/Common'
require 'WSK/Launcher'

exit WSK::Launcher.new.execute(ARGV)
