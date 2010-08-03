# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class SilenceRemover

      include WSK::Common

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return:
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
        # The bounds of the gating, per channel
        # list< [ Min, Max ] >
        lSilenceThresholds = nil
        if (@SilenceThreshold.split('|').size == 1)
          if (@SilenceThreshold.split(',').size == 1)
            lSilenceThresholds = [ [ -@SilenceThreshold.to_i, @SilenceThreshold.to_i ] ] * iInputData.Header.NbrChannels
          else
            lSilenceThresholds = [@SilenceThreshold.split(',').map { |iStrValue| iStrValue.to_i }] * iInputData.Header.NbrChannels
          end
        else
          lSilenceThresholds = []
          @SilenceThreshold.split('|').each do |iSilenceThresholdInfo|
            if (iSilenceThresholdInfo.split(',').size == 1)
              lSilenceThresholds << [ -iSilenceThresholdInfo.to_i, iSilenceThresholdInfo.to_i ]
            else
              lSilenceThresholds << iSilenceThresholdInfo.split(',').map { |iStrValue| iStrValue.to_i }
            end
          end
        end
        @IdxFirstSample = nil
        lIdxSample = 0
        iInputData.eachBuffer do |iInputBuffer, iNbrSamples, iNbrChannels|
          lIdxBufferSample = 0
          lIdxChannel = 0
          iInputBuffer.each do |iInputChannelValue|
            if ((iInputChannelValue < lSilenceThresholds[lIdxChannel][0]) or
                (iInputChannelValue > lSilenceThresholds[lIdxChannel][1]))
              # It exceeds
              @IdxFirstSample = lIdxSample + lIdxBufferSample/iNbrChannels
              logInfo "Found first non silent sample at position #{@IdxFirstSample} on #{iInputData.NbrSamples} (#{iInputChannelValue} < #{lSilenceThresholds[lIdxChannel][0]} or > #{lSilenceThresholds[lIdxChannel][1]})"
              break
            end
            lIdxBufferSample += 1
            lIdxChannel += 1
            if (lIdxChannel == iNbrChannels)
              lIdxChannel = 0
            end
          end
          if (@IdxFirstSample != nil)
            break
          end
          lIdxSample += iNbrSamples
        end
        if (@IdxFirstSample == nil)
          logInfo 'The whole input file is silent.'
          # Set it to the last sample
          @IdxFirstSample = iInputData.NbrSamples-1
          @IdxLastSample = iInputData.NbrSamples-1
        else
          # Look for the last non-silent sample
          @IdxLastSample = nil
          lIdxSample = iInputData.NbrSamples*iInputData.Header.NbrChannels-1
          iInputData.eachReverseBuffer do |iInputBuffer, iNbrSamples, iNbrChannels|
            lIdxChannel = iNbrChannels - 1
            iInputBuffer.reverse_each do |iInputChannelValue|
              if ((iInputChannelValue < lSilenceThresholds[lIdxChannel][0]) or
                  (iInputChannelValue > lSilenceThresholds[lIdxChannel][1]))
                # It exceeds
                @IdxLastSample = lIdxSample/iInputData.Header.NbrChannels
                logInfo "Found last non silent sample at position #{@IdxLastSample} on #{iInputData.NbrSamples} (#{iInputChannelValue} < #{lSilenceThresholds[lIdxChannel][0]} or > #{lSilenceThresholds[lIdxChannel][1]})"
                break
              end
              lIdxSample -= 1
              lIdxChannel -= 1
              if (lIdxChannel == -1)
                lIdxChannel = iNbrChannels - 1
              end
            end
            if (@IdxLastSample != nil)
              break
            end
          end
          # Check with FFT that the last non silent sample does not contain any music
          if (File.exists?(@NoiseFFTFileName))
            # Load the reference FFT profile
            lNoiseFFTProfile = nil
            File.open(@NoiseFFTFileName, 'rb') do |iFile|
              lNoiseFFTProfile = Marshal.load(iFile.read)
            end
            # Get the real silent sample
            @IdxLastSample = getNextFFTSample(@IdxLastSample+1, lNoiseFFTProfile, iInputData) - 1
          else
            logErr "Missing file #{@NoiseFFTFileName}"
          end
          # Compute the limits of fadein and fadeout
          lNbrAttack = readDuration(@Attack, iInputData.Header.SampleRate)
          lNbrRelease = readDuration(@Release, iInputData.Header.SampleRate)
          @IdxFirstSample -= lNbrAttack
          if (@IdxFirstSample < 0)
            logWarn "Attack duration #{lNbrAttack} makes first non silent sample negative. Setting it to 0. Please consider decreasing attack duration."
            @IdxFirstSample = 0
          end
          @IdxLastSample += lNbrRelease
          if (@IdxLastSample >= iInputData.NbrSamples)
            logWarn "Release duration #{lNbrRelease} makes last non silent sample overflow. Setting it to the last sample (#{iInputData.NbrSamples - 1}). Please consider decreasing release duration."
            @IdxLastSample = iInputData.NbrSamples - 1
          end
        end

        return @IdxLastSample-@IdxFirstSample+1
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        iInputData.eachRawBuffer(@IdxFirstSample, @IdxLastSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          oOutputData.pushRawBuffer(iInputRawBuffer)
        end

        return nil
      end

    end

  end

end