# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class SilenceRemover

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
        lSilenceThresholds = readThresholds(@SilenceThreshold, iInputData.Header.NbrChannels)
        @IdxFirstSample, lNextAboveThresholds = getNextNonSilentSample(iInputData, 0, lSilenceThresholds, nil, nil, false)
        if (@IdxFirstSample == nil)
          logInfo 'The whole file is silent'
          @IdxFirstSample = 0
          @IdxLastSample = 0
        else
          lNoiseFFTMaxDistance, lNoiseFFTProfile = readFFTProfile(@NoiseFFTFileName)
          @IdxLastSample, lNextAboveThresholds = getNextNonSilentSample(iInputData, iInputData.NbrSamples-1, lSilenceThresholds, lNoiseFFTProfile, lNoiseFFTMaxDistance, true)
          if (@IdxLastSample == nil)
            logErr "A beginning sample has been found (#{@IdxFirstSample}), but no ending sample could. This is a bug."
            raise RuntimeError.new("A beginning sample has been found (#{@IdxFirstSample}), but no ending sample could. This is a bug.")
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