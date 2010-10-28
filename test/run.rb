require 'rUtilAnts/Logging'
RUtilAnts::Logging::initializeLogging('', '', true)
activateLogDebug(true)

# Run all tests
Dir.glob("#{File.dirname(__FILE__)}/WSK/**/*").sort.each do |iFileName|
  require iFileName
end
