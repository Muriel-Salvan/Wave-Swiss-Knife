#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class GenSawtooth

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return:
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
        return iInputData.Header.SampleRate
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        # Compute values used to create sawtooth
        lMaxValue = 2**(iInputData.Header.NbrBitsPerSample-1)-1
        lMinValue = -2**(iInputData.Header.NbrBitsPerSample-1)
        lMiddleSample = iInputData.Header.SampleRate/2
        # Create buffer
        lBuffer = []
        iInputData.Header.SampleRate.times do |iIdxSample|
          iInputData.Header.NbrChannels.times do |iIdxChannel|
            if (iIdxSample < lMiddleSample)
              lBuffer << (iIdxSample*lMaxValue)/lMiddleSample
            else
              lBuffer << lMinValue+(lMiddleSample-iIdxSample)*lMinValue/(iInputData.Header.SampleRate-lMiddleSample)
            end
          end
        end
        # Write buffer
        oOutputData.pushBuffer(lBuffer)

        return nil
      end

    end

  end

end