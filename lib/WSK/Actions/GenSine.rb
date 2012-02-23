#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class GenSine

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return::
      # * _Integer_: The number of samples to be written
      def get_nbr_samples(iInputData)
        return @NbrSamples
      end

      # Execute
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return::
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        # Compute values used to create sawtooth
        lMaxValue = 2**(iInputData.Header.NbrBitsPerSample-1)-1
        # Compute the number of complete periods to put in the samples we want
        lNbrSamplesPeriod = iInputData.Header.SampleRate/@Frequency
        lNbrPeriods = @NbrSamples/lNbrSamplesPeriod
        lBuffer = nil
        if (lNbrPeriods > 0)
          # Generate a buffer with a omplete period in it
          lBuffer = []
          lNbrSamplesPeriod.times do |iIdx|
            lBuffer.concat( [(Math.sin((2*Math::PI*iIdx)/lNbrSamplesPeriod)*lMaxValue).round] * iInputData.Header.NbrChannels )
          end
          # Write them
          lNbrPeriods.times do |iIdx|
            oOutputData.pushBuffer(lBuffer)
          end
        end
        lRemainingSamples = @NbrSamples % lNbrSamplesPeriod
        if (lRemainingSamples > 0)
          # Add the remaining part of the buffer
          if (lBuffer == nil)
            # Generate a part of the buffer
            lBuffer = []
            lRemainingSamples.times do |iIdx|
              lBuffer.concat( [(Math.sin((2*Math::PI*iIdx)/lNbrSamplesPeriod)*lMaxValue).round] * iInputData.Header.NbrChannels )
            end
            # Write it
            oOutputData.pushBuffer(lBuffer)
          else
            # Write a part of the already generated buffer
            oOutputData.pushBuffer(lBuffer[0..iInputData.Header.NbrChannels*lRemainingSamples-1])
          end
        end

        return nil
      end

    end

  end

end