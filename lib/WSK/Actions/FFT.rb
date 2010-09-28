# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class FFT

      include WSK::Common
      include WSK::FFT

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return:
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
        return 0
      end
      
      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)

        # 1. Create the whole FFT profile
        logInfo 'Creating FFT profile ...'
        # Object that will create the FFT
        lFFTComputing = FFTComputing.new(false, iInputData.Header)
        # Parse the data
        lIdxSample = 0
        iInputData.eachRawBuffer do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          lFFTComputing.completeFFT(iInputRawBuffer, iNbrSamples)
          lIdxSample += iNbrSamples
          $stdout.write("#{(lIdxSample*100)/iInputData.NbrSamples} %\015")
          $stdout.flush
        end
        # Compute the result
        require 'WSK/FFTUtils/FFTUtils'
        lFFTUtils = FFTUtils::FFTUtils.new
        lFFTProfile = lFFTComputing.getFFTProfile
        lFFTReferenceProfile = lFFTUtils.createCFFTProfile(lFFTProfile)

        # 2. Compute the distance obtained by comparing this profile with a normal file pass
        logInfo 'Computing average distance ...'
        lFFTComputing2 = FFTComputing.new(true, iInputData.Header)
        lIdxSample = 0
        lNbrTimes = 0
        lSumDist = 0
        while (lIdxSample < iInputData.NbrSamples)
          # Compute the number of samples needed to have a valid FFT.
          # Modify this number if it exceeds the range we have
          lNbrSamplesFFTMax = iInputData.Header.SampleRate/FFTSAMPLE_FREQ
          lIdxBeginFFTSample = lIdxSample
          lIdxEndFFTSample = lIdxSample+lNbrSamplesFFTMax-1
          if (lIdxEndFFTSample >= iInputData.NbrSamples)
            lIdxEndFFTSample = iInputData.NbrSamples-1
          end
          lNbrSamplesFFT = lIdxEndFFTSample-lIdxBeginFFTSample+1
          # Load an FFT buffer of this
          lFFTBuffer = ''
          iInputData.eachRawBuffer(lIdxBeginFFTSample, lIdxEndFFTSample, :NbrSamplesPrefetch => iInputData.NbrSamples-lIdxBeginFFTSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
            lFFTBuffer.concat(iInputRawBuffer)
          end
          # Compute its FFT profile
          lFFTComputing2.resetData
          lFFTComputing2.completeFFT(lFFTBuffer, lNbrSamplesFFT)
          lSumDist += distFFTProfiles(lFFTReferenceProfile, lFFTUtils.createCFFTProfile(lFFTComputing2.getFFTProfile), FFTDIST_MAX).abs
          lNbrTimes += 1
          lIdxSample = lIdxEndFFTSample+1
          $stdout.write("#{(lIdxSample*100)/iInputData.NbrSamples} %\015")
          $stdout.flush
        end
        lAverageDist = lSumDist/lNbrTimes
        logDebug "Average distance with silence: #{lAverageDist}"

        # Display results
        (FREQINDEX_FIRST..FREQINDEX_LAST).each_with_index do |iIdx, iIdxFreq|
          logDebug "[#{(440*(2**(iIdx/12.0))).round} Hz]: #{lFFTProfile[2][iIdxFreq].join(', ')}"
        end

        # Write the result in a file
        File.open('fft.result', 'wb') do |oFile|
          oFile.write(Marshal.dump([lAverageDist, lFFTProfile]))
        end

        return nil
      end

    end

  end

end
