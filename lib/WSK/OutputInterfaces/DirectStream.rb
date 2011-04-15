#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module OutputInterfaces

    class DirectStream

      # Here we define the buffer size.
      # The buffer will be used to store contiguous audio data in RAM.
      # Each OutputData object will never use more than this size.
      # It is expressed in bytes.
      #   Integer
      BUFFER_SIZE = 2097152

      # Initialize the plugin
      #
      # Parameters:
      # * *oFile* (_IO_): The file descriptor. Don't use it externally as long as it is used by this class.
      # * *iHeader* (<em>WSK::Model::Header</em>): Corresponding file header
      # * *iNbrOutputDataSamples* (_Integer_): The number of output data samples
      # Return:
      # * _Exception_: An error, or nil in case of success
      def initInterface(oFile, iHeader, iNbrOutputDataSamples)
        rError = nil

        @File, @Header, @NbrSamples = oFile, iHeader, iNbrOutputDataSamples
        @NbrSamplesWritten = 0
        # Size of a sample
        # Integer
        @SampleSize = (@Header.NbrChannels*@Header.NbrBitsPerSample)/8
        # Compute the number of samples to store in the buffer
        @NbrSamplesPerBuffer = BUFFER_SIZE/@SampleSize
        # The position of the last written sample in the buffer
        # Integer
        @IdxCurrentBufferSample = 0
        # The buffer itself, list of channels values
        # list< Integer >
        @Buffer = []

        return rError
      end

      # Finalize writing
      #
      # Return:
      # * _Integer_: The number of samples written
      def finalize
        if (!@Buffer.empty?)
          flushBuffer
        end

        return @NbrSamplesWritten
      end

      # Add a sample data
      #
      # Parameters:
      # * *iSampleData* (<em>list<Integer></em>): The list of channel values for this sample
      def pushSample(iSampleData)
        # Write data in the buffer
        @Buffer += iSampleData
        @IdxCurrentBufferSample += 1
        if (@IdxCurrentBufferSample == @NbrSamplesPerBuffer)
          # We have to flush the buffer
          flushBuffer
        end
      end

      # Add a buffer
      #
      # Parameters:
      # * *iBuffer* (<em>list<Integer></em>): The list of channel values for this buffer
      def pushBuffer(iBuffer)
        # Write data in the current buffer
        @Buffer += iBuffer
        @IdxCurrentBufferSample += iBuffer.size/@Header.NbrChannels
        if (@IdxCurrentBufferSample >= @NbrSamplesPerBuffer)
          # We have to flush the buffer
          flushBuffer
        end
      end

      # Add a raw buffer
      #
      # Parameters:
      # * *iRawBuffer* (_String_): The raw buffer
      def pushRawBuffer(iRawBuffer)
        # First, flush eventually remaining buffer to encode
        if (!@Buffer.empty?)
          flushBuffer
        end
        # Then write our raw buffer
        @File.write(iRawBuffer)
        updateProgress(iRawBuffer.size/@SampleSize)
      end

      # Loop on a range of samples split into buffers
      #
      # Parameters:
      # * *iIdxBeginSample* (_Integer_): The beginning sample
      # * *iIdxEndSample* (_Integer_): The ending sample
      # * _CodeBlock_: The code called for each buffer:
      # ** *iIdxBeginBufferSample* (_Integer_): The beginning of this buffer's sample
      # ** *iIdxEndBufferSample* (_Integer_): The ending of this buffer's sample
      def eachBuffer(iIdxBeginSample, iIdxEndSample)
        lIdxBeginBufferSample = iIdxBeginSample
        while (lIdxBeginBufferSample <= iIdxEndSample)
          lIdxEndBufferSample = lIdxBeginBufferSample + @NbrSamplesPerBuffer - 1
          if (lIdxEndBufferSample > iIdxEndSample)
            lIdxEndBufferSample = iIdxEndSample
          end
          yield(lIdxBeginBufferSample, lIdxEndBufferSample)
          lIdxBeginBufferSample = lIdxEndBufferSample + 1
        end
      end

      private

      # Write the buffer to the disk
      def flushBuffer
        # Write it
        @File.write(@Header.getEncodedString(@Buffer))
        updateProgress(@Buffer.size/@Header.NbrChannels)
        @IdxCurrentBufferSample = 0
        @Buffer = []
      end

      # Add a samples' number to the progression
      #
      # Parameters:
      # * *iNbrSamples* (_Integer_): Number of samples
      def updateProgress(iNbrSamples)
        @NbrSamplesWritten += iNbrSamples
        $stdout.write("[#{(@NbrSamplesWritten*100)/@NbrSamples}%]\015")
        $stdout.flush
      end

    end

  end

end
