module WSK

  # Common methods
  module Common

    # Parse plugins
    def parsePlugins
      lLibDir = File.expand_path(File.dirname(__FILE__))
      parsePluginsFromDir('Actions', "#{lLibDir}/Actions", 'WSK::Actions')
      parsePluginsFromDir('OutputInterfaces', "#{lLibDir}/OutputInterfaces", 'WSK::OutputInterfaces')
    end

    # Access a WAVE file for read access.
    # Give its header information as well as a proxy to access its data.
    # Proxies are used to cache accesses as they might be time consuming.
    #
    # Parameters:
    # * *iFileName* (_String_): The file name to open
    # * *CodeBlock*: The code block called when accessing the file:
    # ** *iHeader* (<em>WSK::Model::Header</em>): The file header information
    # ** *iInputData* (<em>WSK::Model::InputData</em>): The file data proxy
    # ** Return:
    # ** _Exception_: Error, or nil in case of success
    # Return:
    # * _Exception_: Error, or nil in case of success
    def accessInputWaveFile(iFileName)
      rError = nil

      File.open(iFileName, 'rb') do |iFile|
        logInfo "Access #{iFileName}"
        rError, lHeader, lInputData = getWaveFileAccesses(iFile)
        if (rError == nil)
          rError = yield(lHeader, lInputData)
        end
      end
      
      return rError
    end
    
    # Give Header and Data access from an opened Wave file
    #
    # Parameters:
    # * *iFile* (_IO_): The IO handler
    # Return:
    # * _Exception_: An error, or nil in case of success
    # * <em>WSK::Model::Header</em>: The header
    # * <em>WSK::Model::InputData</em>: The input data
    def getWaveFileAccesses(iFile)
      rError = nil
      rHeader = nil
      rInputData = nil
      
      # Read header
      rError, rHeader = readHeader(iFile)
      logDebug "Header: #{rHeader.inspect}"
      if (rError == nil)
        # Get a data handle
        rInputData = WSK::Model::InputData.new(iFile, rHeader)
        rError = rInputData.initCursor
      end

      return rError, rHeader, rInputData
    end

    # Access a WAVE file for write access.
    # Give its header information as well as a proxy to access its data.
    # Proxies are used to cache accesses as they might be time consuming.
    #
    # Parameters:
    # * *iFileName* (_String_): The file name to write
    # * *iHeader* (<em>WSK::Model::Header</em>): The file header information to write
    # * *iOutputInterface* (_Object_): The output interface
    # * *iNbrOutputDataSamples* (_Integer_): The number of output data samples
    # * *CodeBlock*: The code block called when accessing the file
    # ** Return:
    # ** _Exception_: Error, or nil in case of success
    # Return:
    # * _Exception_: Error, or nil in case of success
    def accessOutputWaveFile(iFileName, iHeader, iOutputInterface, iNbrOutputDataSamples)
      rError = nil

      File.open(iFileName, 'wb') do |oFile|
        # Initialize the output interface
        rError = iOutputInterface.initInterface(oFile, iHeader, iNbrOutputDataSamples)
        if (rError == nil)
          # Write header
          logInfo "Write header in #{iFileName}"
          rError = writeHeader(oFile, iHeader, iNbrOutputDataSamples)
          if (rError == nil)
            # Call client code
            rError = yield
            if (rError == nil)
              # Finalize the output interface
              lNbrSamplesWritten = iOutputInterface.finalize
              # Pad with \x00 if lNbrSamplesWritten is below iNbrOutputDataSamples
              if (lNbrSamplesWritten < iNbrOutputDataSamples)
                logWarn "#{lNbrSamplesWritten} samples written out of #{iNbrOutputDataSamples}: padding with silence."
                oFile.write(iHeader.getEncodedString([0]*(iNbrOutputDataSamples-lNbrSamplesWritten)*iHeader.NbrChannels))
              elsif (lNbrSamplesWritten > iNbrOutputDataSamples)
                logWarn "#{lNbrSamplesWritten} samples written, but #{iNbrOutputDataSamples} only were expected. #{lNbrSamplesWritten - iNbrOutputDataSamples} samples more."
              end
            end
          end
        end
      end

      return rError
    end

    # Read a duration and give its corresponding value in samples
    # Throws an exception in case of bad format.
    #
    # Parameters:
    # * *iStrDuration* (_String_): The duration to read
    # * *iSampleRate* (_Integer_): Sample rate of the file for which this duration applies
    # Return:
    # * _Integer_: The number of samples corresponding to this duration
    def readDuration(iStrDuration, iSampleRate)
      rNbrSamples = nil

      if (iStrDuration[-1..-1] == 's')
        rNbrSamples = ((iStrDuration[0..-2].to_f)*iSampleRate).round
      else
        rNbrSamples = iStrDuration.to_i
      end

      return rNbrSamples
    end

    # Read a given threshold indication on the command line.
    #
    # Parameters:
    # * *iStrThresholds* (_String_): The thresholds to read
    # * *iNbrChannels* (_Integer_): Number of channels for the file being decoded
    # Return:
    # * <em>list<[Integer,Integer]></em>: The list of min and max values, per channel
    def readThresholds(iStrThresholds, iNbrChannels)
      rThresholds = nil

      if (iStrThresholds.split('|').size == 1)
        if (iStrThresholds.split(',').size == 1)
          rThresholds = [ [ -iStrThresholds.to_i, iStrThresholds.to_i ] ] * iNbrChannels
        else
          rThresholds = [iStrThresholds.split(',').map { |iStrValue| iStrValue.to_i }] * iNbrChannels
        end
      else
        rThresholds = []
        iStrThresholds.split('|').each do |iThresholdInfo|
          if (iThresholdInfo.split(',').size == 1)
            rThresholds << [ -iThresholdInfo.to_i, iThresholdInfo.to_i ]
          else
            rThresholds << iThresholdInfo.split(',').map { |iStrValue| iStrValue.to_i }
          end
        end
      end

      return rThresholds
    end

    # Read an FFT profile file
    #
    # Parameters:
    # * *iFileName* (_String_): Name of the FFT profile file, or 'none' if none.
    # Return:
    # * _Integer_: Maximal FFT distance beyond which we consider being too far from the FFT profile
    # * <em>[Integer,Integer,list<list<Integer>>]</em>: The FFT profile
    def readFFTProfile(iFileName)
      rFFTMaxDistance = nil
      rFFTProfile = nil

      if (iFileName != 'none')
        if (File.exists?(iFileName))
          # Load the reference FFT profile
          File.open(iFileName, 'rb') do |iFile|
            rFFTMaxDistance, rFFTProfile = Marshal.load(iFile.read)
          end
          # We add an arbitrary percentage to the average distance.
          rFFTMaxDistance = (rFFTMaxDistance*1.01).to_i
        else
          logErr "Missing file #{iFileName}. Ignoring FFT."
        end
      end

      return rFFTMaxDistance, rFFTProfile
    end

    # Convert a value to its db notation and % notation
    #
    # Parameters:
    # * *iValue* (_Integer_): The value
    # * *iMaxValue* (_Integer_): The maximal possible value
    # Return:
    # * _Float_: Its corresponding db
    # * _Float_: Its corresponding percentage
    def val2db(iValue, iMaxValue)
      if (iValue == 0)
        return -1.0/0, 0.0
      else
        if (defined?(@Log2) == nil)
          @Log2 = Math.log(2.0)
        end
        return -6*(Math.log(Float(iMaxValue))-Math.log(Float(iValue.abs)))/@Log2, (Float(iValue.abs)*100)/Float(iMaxValue)
      end
    end

    private

    # Write the header to a file.
    #
    # Parameters:
    # * *oFile* (_IO_): File to write
    # * *iHeader* (<em>WSK::Model::Header</em>): The header to write
    # * *iNbrOutputDataSamples* (_Integer_): The number of output data samples
    # Return:
    # * _Exception_: The exception, or nil in case of success
    def writeHeader(oFile, iHeader, iNbrOutputDataSamples)
      rError = nil

      lBlockAlign = (iHeader.NbrChannels*iHeader.NbrBitsPerSample)/8
      lOutputDataSize = iNbrOutputDataSamples * lBlockAlign
      oFile.write("RIFF#{[lOutputDataSize+36].pack('V')}WAVEfmt #{[16, iHeader.AudioFormat, iHeader.NbrChannels, iHeader.SampleRate, iHeader.SampleRate * lBlockAlign, lBlockAlign, iHeader.NbrBitsPerSample].pack('VvvVVvv')}data#{[lOutputDataSize].pack('V')}")

      return rError
    end

    # Get the header from a file.
    # This also checks for unsupported types.
    #
    # Parameters:
    # * *iFile* (_IO_): File to read
    # Return:
    # * _Exception_: The exception, or nil in case of success
    # * <em>WSK::Model::Header</em>: The corresponding header, or nil in case of failure
    def readHeader(iFile)
      rError = nil
      rHeader = nil

      iFile.seek(0)
      lBinaryHeader = iFile.read(12)
      # Check if the format is ok
      if (lBinaryHeader[0..3] != 'RIFF')
        rError = RuntimeError.new('Invalid header: not RIFF')
      elsif (lBinaryHeader[8..11] != 'WAVE')
        rError = RuntimeError.new('Invalid header: not WAVE')
      else
        lReader = RIFFReader.new(iFile)
        rError, lFMTSize = lReader.setFilePos('fmt ')
        if (rError == nil)
          # lFMTSize should be 18
          if (lFMTSize >= 16)
            lBinFormat = iFile.read(lFMTSize)
            # Read values
            lAudioFormat, lNbrChannels, lSampleRate, lByteRate, lBlockAlign, lNbrBitsPerSample = lBinFormat[0..17].unpack('vvVVvv')
            # Check values
            if (lBlockAlign != (lNbrChannels*lNbrBitsPerSample)/8)
              rError = RuntimeError.new("Invalid header: Block alignment (#{lBlockAlign}) should be #{(lNbrChannels*lNbrBitsPerSample)/8}.")
            elsif (lByteRate != lBlockAlign*lSampleRate)
              rError = RuntimeError.new("Invalid header: Byte rate (#{lByteRate}) should be #{lBlockAlign*lSampleRate}.")
            else
              # OK, header is valid
              rHeader = WSK::Model::Header.new(lAudioFormat, lNbrChannels, lSampleRate, lNbrBitsPerSample)
            end
          else
            rError = RuntimeError.new("Invalid fmt header size: #{lFMTSize} should be >= 16.")
          end
        end
      end

      return rError, rHeader
    end

  end

end

require 'WSK/RIFFReader'
require 'WSK/Model/InputData'
require 'WSK/Model/Header'
require 'WSK/FFT'
require 'WSK/Maps'
require 'WSK/Functions'
