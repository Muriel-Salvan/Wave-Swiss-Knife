#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class GenAllValues

      MAX_BUFFER_SAMPLES = 65536

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return:
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
        @MaxValue = 2**(iInputData.Header.NbrBitsPerSample-1)-1
        @MinValue = -2**(iInputData.Header.NbrBitsPerSample-1)

        return @MaxValue-@MinValue+1
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        # Create buffer
        lNbrBuffers = ((@MaxValue-@MinValue+1) / MAX_BUFFER_SAMPLES)+1
        lSizeofLastBuffer = ((@MaxValue-@MinValue+1) % MAX_BUFFER_SAMPLES)
        lIdxValue = @MinValue
        logDebug "Will output #{@MaxValue-@MinValue+1} samples in #{lNbrBuffers} buffers."
        lNbrBuffers.times do |iIdxBuffer|
          lBuffer = []
          lSamplesInBuffer = nil
          if (iIdxBuffer == lNbrBuffers-1)
            # The last one
            lSamplesInBuffer = lSizeofLastBuffer
          else
            lSamplesInBuffer = MAX_BUFFER_SAMPLES
          end
          lSamplesInBuffer.times do |iIdxSampleBuffer|
            iInputData.Header.NbrChannels.times do |iIdxChannel|
              lBuffer << lIdxValue
            end
            lIdxValue += 1
          end
          oOutputData.pushBuffer(lBuffer)
        end

        return nil
      end

    end

  end

end