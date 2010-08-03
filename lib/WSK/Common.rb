require 'WSK/RIFFReader'
require 'WSK/Model/InputData'
require 'WSK/Model/Header'

module WSK

  # Frequencies used to compute FFT profiles.
  # !!! When changing these values, all fft.result files generated are invalidated
  FREQINDEX_FIRST = -59
  FREQINDEX_LAST = 79

  # Scale used to measure FFT values
  FFTDIST_MAX = 10000000000000

  # Frequency of the FFT samples to take (Hz)
  FFTSAMPLE_FREQ = 15
  # Number of FFT buffers needed to detect a constant Moving Average.
  FFTNBRSAMPLES_HISTORY = 5

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
                logInfo "#{lNbrSamplesWritten} samples written out of #{iNbrOutputDataSamples}: padding with silence."
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
        rNbrSamples = iStrDuration[0..-2].to_i
      end

      return rNbrSamples
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

    # Compare 2 FFT profiles and measure their distance.
    # Here is an FFT profile structure:
    # [ Integer,          Integer,    list<list<Integer>> ]
    # [ NbrBitsPerSample, NbrSamples, FFTValues ]
    # FFTValues are declined per channel, per frequency index
    #
    # Parameters:
    # * *iProfile1* (<em>[Integer,Integer,Integer,list<list<Integer>>]</em>): Profile 1
    # * *iProfile2* (<em>[Integer,Integer,Integer,list<list<Integer>>]</em>): Profile 2
    # Return:
    # * _Integer_: Distance (Profile 2 - Profile 1). The scale is given by FFTDIST_MAX.
    def distFFTProfiles(iProfile1, iProfile2)
      # Return the max of the distances
      rMaxDist = 0

      iNbrBitsPerSample1, iNbrSamples1, iFFT1 = iProfile1
      iNbrBitsPerSample2, iNbrSamples2, iFFT2 = iProfile2

      # Each value is limited by the maximum value of 2*(NbrSamples*MaxAbsValue)^2
      lMaxFFTValue1 = 2*((iNbrSamples1*(2**(iNbrBitsPerSample1-1)))**2)
      lMaxFFTValue2 = 2*((iNbrSamples2*(2**(iNbrBitsPerSample2-1)))**2)
      iFFT1.each_with_index do |iFFT1ChannelValues, iIdxFreq|
        iFFT2ChannelValues = iFFT2[iIdxFreq]
        iFFT1ChannelValues.each_with_index do |iFFT1Value, iIdxChannel|
          iFFT2Value = iFFT2ChannelValues[iIdxChannel]
          # Compute iFFT2Value - iFFT1Value, on a scale of FFTDIST_MAX
          lDist = (iFFT2Value*FFTDIST_MAX)/lMaxFFTValue2 - (iFFT1Value*FFTDIST_MAX)/lMaxFFTValue1
#          logDebug "[Freq #{iIdxFreq}] [Ch #{iIdxChannel}] - Distance = #{lDist}"
          if (lDist > rMaxDist)
            rMaxDist = lDist
          end
        end
      end

      return rMaxDist
    end

    # Get the next sample that has an FFT buffer similar to a given FFT profile
    #
    # Parameters:
    # * *iIdxFirstSample* (_Integer_): First sample we are trying from
    # * *iFFTProfile* (<em>[Integer,Integer,list<list<Integer>>]</em>): The FFT profile
    # * *iInputData* (_InputData_): The input data to read
    # * *iIdxLastPossibleSample* (_Integer_): Index of the sample marking the limit of the search [optional = iInputData.NbrSamples-1]
    # Return:
    # * _Integer_: Index of the sample (can be 1 after the end)
    def getNextFFTSample(iIdxFirstSample, iFFTProfile, iInputData, iIdxLastPossibleSample = iInputData.NbrSamples-1)
      rCurrentSample = iIdxFirstSample

      require 'WSK/FFTUtils/FFTUtils'
      lFFTUtils = FFTUtils::FFTUtils.new

      # Historical values of FFT diffs to know when it is stable
      # This is the implementation of the Moving Average algorithm.
      # We are just interested in the difference of 2 different Moving Averages. Therefore comparing the oldest history value with the new one is enough.
      # Cycling buffer of size FFTNBRSAMPLES_HISTORY
      # list< Integer >
      lHistory = []
      lIdxOldestHistory = 0
      # Initialize FFT utils objects
      lW = lFFTUtils.createWi(FREQINDEX_FIRST, FREQINDEX_LAST, iInputData.Header.SampleRate)
      lNbrFreq = FREQINDEX_LAST - FREQINDEX_FIRST + 1
      while (rCurrentSample < iIdxLastPossibleSample+1)
        # Compute the number of samples needed to have a valid FFT.
        lNbrSamplesFFT = iInputData.Header.SampleRate/FFTSAMPLE_FREQ
        lLastFFTBufferSample = rCurrentSample+lNbrSamplesFFT-1
        if (lLastFFTBufferSample >= iIdxLastPossibleSample+1)
          lLastFFTBufferSample = iIdxLastPossibleSample
          lNbrSamplesFFT = lLastFFTBufferSample-rCurrentSample+1
        end
        # Load an FFT buffer of this
        lFFTBuffer = ''
        iInputData.eachRawBuffer(rCurrentSample, lLastFFTBufferSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          lFFTBuffer.concat(iInputRawBuffer)
        end
        # Compute its FFT profile
        lSumCos = lFFTUtils.initSumArray(lNbrFreq, iInputData.Header.NbrChannels)
        lSumSin = lFFTUtils.initSumArray(lNbrFreq, iInputData.Header.NbrChannels)
        lFFTUtils.completeSumCosSin(lFFTBuffer, 0, iInputData.Header.NbrBitsPerSample, lNbrSamplesFFT, iInputData.Header.NbrChannels, lNbrFreq, lW, lSumCos, lSumSin)
        lFFTValues = lFFTUtils.computeFFT(iInputData.Header.NbrChannels, lNbrFreq, lSumCos, lSumSin)
        lDist = distFFTProfiles(iFFTProfile, [iInputData.Header.NbrBitsPerSample, lNbrSamplesFFT, lFFTValues]).abs
        logDebug "FFT distance computed with FFT sample [#{rCurrentSample} - #{lLastFFTBufferSample}]: #{lDist}"
        # Detect if the Moving Average is going up
        if ((lHistory.size == FFTNBRSAMPLES_HISTORY) and
            (lHistory[lIdxOldestHistory] < lDist))
          # We got it
          break
        else
          # Check next FFT sample
          rCurrentSample = lLastFFTBufferSample + 1
          # Update the history with the new diff
          lHistory[lIdxOldestHistory] = lDist
          lIdxOldestHistory += 1
          if (lIdxOldestHistory == FFTNBRSAMPLES_HISTORY)
            lIdxOldestHistory = 0
          end
        end
      end

      return rCurrentSample
    end

    # Get the previous sample that has an FFT buffer similar to a given FFT profile
    #
    # Parameters:
    # * *iIdxLastSample* (_Integer_): Last sample we are trying from
    # * *iFFTProfile* (<em>[Integer,Integer,list<list<Integer>>]</em>): The FFT profile
    # * *iInputData* (_InputData_): The input data to read
    # * *iIdxFirstPossibleSample* (_Integer_): Index of the sample marking the limit of the search [optional = 0]
    # Return:
    # * _Integer_: Index of the sample (can be 1 after the end)
    def getPreviousFFTSample(iIdxLastSample, iFFTProfile, iInputData, iIdxFirstPossibleSample = 0)
      rCurrentSample = iIdxLastSample

      require 'WSK/FFTUtils/FFTUtils'
      lFFTUtils = FFTUtils::FFTUtils.new
      # Historical values of FFT diffs to know when it is stable
      # This is the implementation of the Moving Average algorithm.
      # We are just interested in the difference of 2 different Moving Averages. Therefore comparing the oldest history value with the new one is enough.
      # Cycling buffer of size FFTNBRSAMPLES_HISTORY
      # list< Integer >
      lHistory = []
      lIdxOldestHistory = 0
      # Initialize FFT utils objects
      lW = lFFTUtils.createWi(FREQINDEX_FIRST, FREQINDEX_LAST, iInputData.Header.SampleRate)
      lNbrFreq = FREQINDEX_LAST - FREQINDEX_FIRST + 1
      while (rCurrentSample > iIdxFirstPossibleSample-1)
        # Compute the number of samples needed to have a valid FFT. We want 15 Hz.
        lNbrSamplesFFT = iInputData.Header.SampleRate/FFTSAMPLE_FREQ
        lFirstFFTBufferSample = rCurrentSample-lNbrSamplesFFT+1
        if (lFirstFFTBufferSample <= iIdxFirstPossibleSample-1)
          lFirstFFTBufferSample = iIdxFirstPossibleSample
          lNbrSamplesFFT = rCurrentSample-lFirstFFTBufferSample+1
        end
        # Load an FFT buffer of this
        lFFTBuffer = ''
        iInputData.eachRawBuffer(lFirstFFTBufferSample, rCurrentSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          lFFTBuffer.concat(iInputRawBuffer)
        end
        # Compute its FFT profile
        lSumCos = lFFTUtils.initSumArray(lNbrFreq, iInputData.Header.NbrChannels)
        lSumSin = lFFTUtils.initSumArray(lNbrFreq, iInputData.Header.NbrChannels)
        lFFTUtils.completeSumCosSin(lFFTBuffer, 0, iInputData.Header.NbrBitsPerSample, lNbrSamplesFFT, iInputData.Header.NbrChannels, lNbrFreq, lW, lSumCos, lSumSin)
        lFFTValues = lFFTUtils.computeFFT(iInputData.Header.NbrChannels, lNbrFreq, lSumCos, lSumSin)
        lDist = distFFTProfiles(iFFTProfile, [iInputData.Header.NbrBitsPerSample, lNbrSamplesFFT, lFFTValues]).abs
        logDebug "FFT distance computed with FFT sample [#{lFirstFFTBufferSample} - #{rCurrentSample}]: #{lDist}"
        # Detect if the Moving Average is going up
        if ((lHistory.size == FFTNBRSAMPLES_HISTORY) and
            (lHistory[lIdxOldestHistory] < lDist))
          # We got it
          break
        else
          # Check next FFT sample
          rCurrentSample = lFirstFFTBufferSample - 1
          # Update the history with the new diff
          lHistory[lIdxOldestHistory] = lDist
          lIdxOldestHistory += 1
          if (lIdxOldestHistory == FFTNBRSAMPLES_HISTORY)
            lIdxOldestHistory = 0
          end
        end
      end

      return rCurrentSample
    end

  end

end