# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class SilenceInserter

      include WSK::Common

      # Number of samples in the silent buffer
      #   Integer
      SILENT_BUFFER_SIZE = 2097152

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return:
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
        @NbrBeginSilentSamples = readDuration(@BeginSilenceLength, iInputData.Header.SampleRate)
        @NbrEndSilentSamples = readDuration(@EndSilenceLength, iInputData.Header.SampleRate)

        return iInputData.NbrSamples+@NbrBeginSilentSamples+@NbrEndSilentSamples
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        pushSilence(iInputData, oOutputData, @NbrBeginSilentSamples)
        pushFile(iInputData, oOutputData)
        pushSilence(iInputData, oOutputData, @NbrEndSilentSamples)
        
        return nil
      end
      
      private
      
      # Push silence in the file
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # * *iNbrSamples* (_Integer_): The number of silent samples to insert
      def pushSilence(iInputData, oOutputData, iNbrSamples)
        lRawSampleSize = (iInputData.Header.NbrChannels*iInputData.Header.NbrBitsPerSample)/8
        lNbrCompleteBuffers = iNbrSamples/SILENT_BUFFER_SIZE
        if (lNbrCompleteBuffers > 0)
          lCompleteRawBuffer = "\000"*SILENT_BUFFER_SIZE*lRawSampleSize
          lNbrCompleteBuffers.times do |iIdx|
            oOutputData.pushRawBuffer(lCompleteRawBuffer)
          end
        end
        lLastBufferSize = iNbrSamples % SILENT_BUFFER_SIZE
        if (lLastBufferSize > 0)
          oOutputData.pushRawBuffer("\000"*lLastBufferSize*lRawSampleSize)
        end
      end

      # Push the file
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      def pushFile(iInputData, oOutputData)
        # Then write the file
        iInputData.eachRawBuffer do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          oOutputData.pushRawBuffer(iInputRawBuffer)
        end
      end

    end

  end

end