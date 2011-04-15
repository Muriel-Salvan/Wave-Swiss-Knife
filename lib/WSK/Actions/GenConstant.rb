#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class GenConstant

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
        return @NbrSamples
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        lRawSample = iInputData.Header.getEncodedString([@Value]*iInputData.Header.NbrChannels)
        # Write complete buffers
        lNbrCompleteBuffers = @NbrSamples/MAX_BUFFER_SAMPLES
        if (lNbrCompleteBuffers > 0)
          lCompleteRawBuffer = lRawSample*MAX_BUFFER_SAMPLES
          lNbrCompleteBuffers.times do |iIdx|
            oOutputData.pushRawBuffer(lCompleteRawBuffer)
          end
        end
        # Write last buffer
        lLastBufferSize = @NbrSamples % MAX_BUFFER_SAMPLES
        if (lLastBufferSize > 0)
          oOutputData.pushRawBuffer(lRawSample*lLastBufferSize)
        end

        return nil
      end

    end

  end

end