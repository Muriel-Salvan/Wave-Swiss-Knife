#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'test/unit'
require 'tmpdir'
require 'fileutils'
require 'WSK/Common'
require 'WSK/Launcher'

module WSKTest

  module Common

    # Return the directory containing test files
    #
    # Return::
    # * _String_: The directory containing files
    def getFilesDir
      return File.expand_path("#{File.dirname(__FILE__)}/../WSKFiles")
    end

    # Generate a Wave file based on a function
    #
    # Parameters::
    # * *iFunction* (<em>map<Symbol,Object></em>): The function (in a map) used to generate the Wave file
    # * *iParams* (<em>map<Symbol,Object></em>): Additional parameters [optional = {}]:
    #   * *:UnitDB* (_Boolean_): Are function units in db scale ? [optional = false]
    # * _CodeBlock_: The code called once the Wave file is generated:
    #   * *iWaveFileName* (_String_): The name of the generated Wave file
    def genWave(iFunction, iParams = {})
      lParams = {
        :UnitDB => false
      }.merge(iParams)
      # Create the function
      lWaveFunction = WSK::Functions::Function.new
      lWaveFunction.set(iFunction)
      # Set the temporary directory
      lTmpDir = "#{Dir.tmpdir}/WSKReg"
      FileUtils::mkdir_p(lTmpDir)
      # Create needed files
      lBaseWaveName = "TmpFctWave_#{iFunction.to_a.hash}"
      lTempFctFileName = "#{lTmpDir}/#{lBaseWaveName}.fct.rb"
      if (!File.exists?(lTempFctFileName))
        lWaveFunction.write_to_file(lTempFctFileName)
      end
      lTempWaveFileName = "#{lTmpDir}/#{lBaseWaveName}.wav"
      if (!File.exists?(lTempWaveFileName))
        lWSKCmdLineArgs = [
          '--input', "#{getFilesDir}/Waves/Empty_44_16_Mono.wav",
          '--output', lTempWaveFileName,
          '--action', 'DrawFct',
          '--',
          '--function', lTempFctFileName,
          '--unitdb', lParams[:UnitDB] ? '1' : '0'
        ]
        if (debug_activated?)
          lWSKCmdLineArgs = [ '--debug' ] + lWSKCmdLineArgs
        end
        # Remove output to stdout, and put it in a log file
        set_log_file("#{lTmpDir}/#{lBaseWaveName}.log.txt")
        WSK::Launcher.new.execute(lWSKCmdLineArgs)
        set_log_file(nil)
      end
      # Launch the test
      begin
        yield(lTempWaveFileName)
      rescue Exception
        log_err "Error: #{$!}\n#{$!.backtrace.join("\n")}\nFiles \"#{lTempFctFileName}\" and \"#{lTempWaveFileName}\" can be used to investigate the error."
        raise
      end
    end

  end

end
