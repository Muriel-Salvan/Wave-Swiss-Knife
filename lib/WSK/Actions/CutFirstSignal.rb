module WSK

  module Actions

    class CutFirstSignal

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
        require 'time'

        @IdxStartSample = 0
        lSilenceThresholds = readThresholds(@SilenceThreshold, iInputData.Header.NbrChannels)
        # Find the first signal
        lIdxSignalSample, lIdxNextAboveThresholds = getNextNonSilentSample(iInputData, 0, lSilenceThresholds, nil, nil, false)
        if (lIdxSignalSample == nil)
          logWarn 'No signal found. Keeping the whole file.'
        else
          lNoiseFFTMaxDistance, lNoiseFFTProfile = readFFTProfile(@NoiseFFTFileName)
          lSilenceDuration = readDuration(@SilenceMin, iInputData.Header.SampleRate)
          lIdxSilenceSample, lSilenceLength, lIdxNextAboveThresholds = getNextSilentSample(iInputData, lIdxSignalSample, lSilenceThresholds, lSilenceDuration, lNoiseFFTProfile, lNoiseFFTMaxDistance, false)
          if (lIdxSilenceSample == nil)
            logWarn "No silence found after the signal beginning at #{lIdxSignalSample}. Keeping the whole file."
          else
            @IdxStartSample = lIdxSilenceSample + lSilenceLength
          end
        end

        return iInputData.NbrSamples-@IdxStartSample
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        iInputData.eachRawBuffer(@IdxStartSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          oOutputData.pushRawBuffer(iInputRawBuffer)
        end

        return nil
      end

    end

  end

end