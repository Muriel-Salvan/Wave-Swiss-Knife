#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'optparse'
require 'date'

module WSK

  class Launcher

    include WSK::Common

    # Constructor
    def initialize
      # Options set by the command line parser
      @InputFileName = nil
      @OutputFileName = nil
      @Action = nil
      @DisplayHelp = false
      @Debug = false
      parsePlugins

      # The command line parser
      @Options = OptionParser.new
      @Options.banner = 'WSK.rb [--help] [--debug] --input <InputFile> --output <OutputFile> --action <ActionName> -- <ActionOptions>'
      @Options.on( '--input <InputFile>', String,
        '<InputFile>: WAVE file name to use as input',
        'Specify input file name') do |iArg|
        @InputFileName = iArg
      end
      @Options.on( '--output <OutputFile>', String,
        '<OutputFile>: WAVE file name to use as output',
        'Specify output file name') do |iArg|
        @OutputFileName = iArg
      end
      @Options.on( '--action <ActionName>', String,
        "<ActionName>: Name of the action to process. Available Actions: #{get_plugins_names('Actions').join(', ')}",
        'Specify the Action to execute') do |iArg|
        @Action = iArg
      end
      @Options.on( '--help',
        'Display help') do
        @DisplayHelp = true
      end
      @Options.on( '--debug',
        'Activate debug logs') do
        @Debug = true
      end
    end

    # Execute command line arguments
    #
    # Parameters::
    # * *iArgs* (<em>list<String></em>): Command line arguments
    # Return::
    # * _Integer_: The error code to return to the terminal
    def execute(iArgs)
      rResult = 0

      lBeginTime = DateTime.now
      lError = nil
      lActionArgs = nil
      begin
        # Split the arguments
        lMainArgs, lActionArgs = splitParameters(iArgs)
        lRemainingArgs = @Options.parse(lMainArgs)
        if (!lRemainingArgs.empty?)
          lError = RuntimeError.new("Unknown arguments: #{lRemainingArgs.join(' ')}")
        end
      rescue Exception
        lError = $!
      end
      if (lError == nil)
        if (@DisplayHelp)
          puts @Options
        else
          if (@Debug)
            activate_log_debug(true)
          end
          # Check mandatory arguments were given
          if (@InputFileName == nil)
            lError = RuntimeError.new('Missing --input option. Please specify an input file.')
          elsif (@OutputFileName == nil)
            lError = RuntimeError.new('Missing --output option. Please specify an output file.')
          elsif (@Action == nil)
            lError = RuntimeError.new('Missing --action option. Please specify an action to perform.')
          elsif (!File.exists?(@InputFileName))
            lError = RuntimeError.new("Missing input file #{@InputFileName}")
          elsif (File.exists?(@OutputFileName))
            lError = RuntimeError.new("Output file #{@OutputFileName} already exists.")
          else
            # Access the Action
            access_plugin('Actions', @Action) do |ioActionPlugin|
              lDesc = ioActionPlugin.pluginDescription
              # Check the output interface required by this plugin
              lOutputInterfaceName = lDesc[:OutputInterface]
              if (lOutputInterfaceName == nil)
                lOutputInterfaceName = 'DirectStream'
              end
              # Initialize the variables if options are specified
              if (lDesc[:Options] == nil)
                if (!lActionArgs.empty?)
                  lError = RuntimeError.new("Unknown Action arguments: #{lActionArgs.join(' ')}. Normally no parameter was expected.")
                end
              else
                # Check options
                lPluginOptions = OptionParser.new
                # Variables to instantiate
                lVariables = {}
                lDesc[:Options].each do |iVariable, iOptionInfo|
                  # Set the variable correctly when the option is encountered
                  lPluginOptions.on(*iOptionInfo) do |iArg|
                    lVariables[iVariable] = iArg
                  end
                end
                if (lActionArgs.empty?)
                  lError = RuntimeError.new("Action was expecting arguments: #{lPluginOptions.to_s}. Please specify them after -- separator.")
                else
                  # Parse Action's options
                  begin
                    lRemainingActionArgs = lPluginOptions.parse(lActionArgs)
                    if (!lRemainingActionArgs.empty?)
                      lError = RuntimeError.new("Unknown Action arguments: #{lRemainingActionArgs.join(' ')}. Expected signature: #{lPluginOptions.to_s}")
                    end
                  rescue Exception
                    lError = $!
                  end
                  # Instantiate variables if needed
                  if (lError == nil)
                    instantiateVars(ioActionPlugin, lVariables)
                  end
                end
              end
              # Plugin is initialized
              if (lError == nil)
                # Access the output interface plugin
                access_plugin('OutputInterfaces', lOutputInterfaceName) do |ioOutputPlugin|
                  # Access the input file
                  lError = accessInputWaveFile(@InputFileName) do |iInputHeader, iInputData|
                    lInputSubError = nil

                    # Get the maximal output data samples
                    lNbrOutputDataSamples = ioActionPlugin.getNbrSamples(iInputData)
                    log_debug "Number of samples to be written: #{lNbrOutputDataSamples}"

                    # Access the output file
                    lInputSubError = accessOutputWaveFile(@OutputFileName, iInputHeader, ioOutputPlugin, lNbrOutputDataSamples) do
                      # Execute
                      log_info "Execute Action #{@Action}, reading #{@InputFileName} and writing #{@OutputFileName} using #{lOutputInterfaceName} output interface."
                      next ioActionPlugin.execute(iInputData, ioOutputPlugin)
                    end

                    next lInputSubError
                  end
                end
              end
            end
          end
        end
      end

      if (lError != nil)
        log_err "Error encountered: #{lError}"
        rResult = 1
      end
      log_info "Elapsed milliseconds: #{((DateTime.now-lBeginTime)*86400000).to_i}"

      return rResult
    end

    private

    # Split parameters, before and after the first -- encountered
    #
    # Parameters::
    # * *iParameters* (<em>list<String></em>): The parameters
    # Return::
    # * <em>list<String></em>: The first part
    # * <em>list<String></em>: The second part
    def splitParameters(iParameters)
      rFirstPart = iParameters
      rSecondPart = []

      lIdxSeparator = iParameters.index('--')
      if (lIdxSeparator != nil)
        if (lIdxSeparator == 0)
          rFirstPart = []
        else
          rFirstPart = iParameters[0..lIdxSeparator-1]
        end
        if (lIdxSeparator == iParameters.size-1)
          rSecondPart = []
        else
          rSecondPart = iParameters[lIdxSeparator+1..-1]
        end
      end

      return rFirstPart, rSecondPart
    end

    # Store a map of variable names and their corresponding values as instance variables of a given class
    #
    # Parameters::
    # * *ioObject* (_Object_): Object where we want to instantiate those variables
    # * *iVars* (<em>map<Symbol,Object></em>): The map of variables and their values
    def instantiateVars(ioObject, iVars)
      iVars.each do |iVariable, iValue|
        ioObject.instance_variable_set("@#{iVariable}".to_sym, iValue)
      end
    end

  end

end
