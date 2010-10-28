# To change this template, choose Tools | Templates
# and open the template in the editor.

# Main file

require 'rUtilAnts/Logging'
RUtilAnts::Logging::initializeLogging('', '')
require 'WSK/Common'
require 'WSK/Launcher'

exit WSK::Launcher.new.execute(ARGV)
