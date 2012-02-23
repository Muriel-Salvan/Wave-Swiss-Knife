#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class Cut

      include WSK::Common

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return::
      # * _Integer_: The number of samples to be written
      def get_nbr_samples(iInputData)
        @IdxBeginSample = readDuration(@BeginSample, iInputData.Header.SampleRate)
        @IdxEndSample = readDuration(@EndSample, iInputData.Header.SampleRate)

        return @IdxEndSample-@IdxBeginSample+1
      end

      # Execute
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return::
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        lChannelsSampleSize = (iInputData.Header.NbrChannels*iInputData.Header.NbrBitsPerSample)/8
        lIdxFirstSample = @IdxBeginSample
        iInputData.each_raw_buffer(@IdxBeginSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          # If the end sample is in this buffer, write only up to it
          if (@IdxEndSample < lIdxFirstSample + iNbrSamples - 1)
            oOutputData.pushRawBuffer(iInputRawBuffer[0..(@IdxEndSample-lIdxFirstSample+1)*lChannelsSampleSize-1])
          else
            oOutputData.pushRawBuffer(iInputRawBuffer)
          end
          if (@IdxEndSample < lIdxFirstSample + iNbrSamples)
            # Nothing left to write
            break
          end
          lIdxFirstSample += iNbrSamples
        end

        return nil
      end

    end

  end

end