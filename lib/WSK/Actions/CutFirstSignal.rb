#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class CutFirstSignal

      include WSK::Common
      include WSK::FFT

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return::
      # * _Integer_: The number of samples to be written
      def get_nbr_samples(iInputData)
        @IdxStartSample = 0
        lSilenceThresholds = readThresholds(@SilenceThreshold, iInputData.Header.NbrChannels)
        # Find the first signal
        lIdxSignalSample, lIdxNextAboveThresholds = getNextNonSilentSample(iInputData, 0, lSilenceThresholds, nil, nil, false)
        if (lIdxSignalSample == nil)
          log_warn 'No signal found. Keeping the whole file.'
        else
          lNoiseFFTMaxDistance, lNoiseFFTProfile = readFFTProfile(@NoiseFFTFileName)
          lSilenceDuration = readDuration(@SilenceMin, iInputData.Header.SampleRate)
          lIdxSilenceSample, lSilenceLength, lIdxNextAboveThresholds = getNextSilentSample(iInputData, lIdxSignalSample, lSilenceThresholds, lSilenceDuration, lNoiseFFTProfile, lNoiseFFTMaxDistance, false)
          if (lIdxSilenceSample == nil)
            log_warn "No silence found after the signal beginning at #{lIdxSignalSample}. Keeping the whole file."
          elsif (lSilenceLength == nil)
            # Find the silence length by parsing following data
            lIdxNonSilentSample, lIdxNextAboveThresholds = getNextNonSilentSample(iInputData, lIdxSilenceSample+1, lSilenceThresholds, lNoiseFFTProfile, lNoiseFFTMaxDistance, false)
            if (lIdxNonSilentSample == nil)
              # The file should be empty
              @IdxStartSample = iInputData.NbrSamples-1
            else
              @IdxStartSample = lIdxNonSilentSample
            end
          else
            @IdxStartSample = lIdxSilenceSample + lSilenceLength
          end
        end

        return iInputData.NbrSamples-@IdxStartSample
      end

      # Execute
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return::
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        iInputData.each_raw_buffer(@IdxStartSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          oOutputData.pushRawBuffer(iInputRawBuffer)
        end

        return nil
      end

    end

  end

end
