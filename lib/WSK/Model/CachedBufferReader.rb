module WSK

  module Model

    # Class to be inherited to define the following virtual methods:
    # * readBuffer(iIdxStart, iIdxEnd) -> Buffer
    # * extractSubBuffer(iBuffer, iIdxStart, iIdxEnd) -> Buffer
    # * getNbrSamplesPerBuffer -> Integer (number of samples in 1 buffer)
    # * getNbrSamples -> Integer (total number of samples)
    class CachedBufferReader

      # Constructor
      def initialize
        @NbrSamples = getNbrSamples
        @NbrSamplesPerBuffer = getNbrSamplesPerBuffer
        # The position of the first sample of the buffer
        # Integer
        @IdxStartBufferSample = nil
        # The position of the last sample of the buffer
        # Integer
        @IdxEndBufferSample = nil
        # The buffer itself
        @Buffer = nil
      end

      # Iterate through the buffers.
      #
      # Parameters:
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with [optional = @NbrSamples-1]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iBuffer* (_String_): The buffer
      # ** *iNbrSamples* (_Integer_): The number of samples in this buffer
      def eachBuffer(iIdxStartSample = 0, iIdxEndSample = @NbrSamples-1)
        lIdxFirstSample = iIdxStartSample
        while (lIdxFirstSample != nil)
          lIdxLastSample = lIdxFirstSample+@NbrSamplesPerBuffer
          if (lIdxLastSample > iIdxEndSample)
            lIdxLastSample = iIdxEndSample
          end
          prepareBuffer(lIdxFirstSample, lIdxLastSample)
          # Check if we need to return a sub-copy of the buffer
          lBuffer = []
          if ((lIdxFirstSample == @IdxStartBufferSample) and
              (lIdxLastSample == @IdxEndBufferSample))
            lBuffer = @Buffer
          else
            lBuffer = extractSubBuffer(@Buffer, lIdxFirstSample - @IdxStartBufferSample, lIdxLastSample - @IdxStartBufferSample)
          end
          # Call client code
          yield(lBuffer, lIdxLastSample - lIdxFirstSample + 1)
          lIdxFirstSample = lIdxLastSample+1
          if (lIdxFirstSample > iIdxEndSample)
            lIdxFirstSample = nil
          end
        end
      end

      # Iterate through the buffers in reverse order.
      #
      # Parameters:
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with [optional = @NbrSamples-1]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iBuffer* (_String_): The buffer
      # ** *iNbrSamples* (_Integer_): The number of samples in this buffer
      def eachReverseBuffer(iIdxStartSample = 0, iIdxEndSample = @NbrSamples-1)
        lIdxLastSample = iIdxEndSample
        while (lIdxLastSample != nil)
          lIdxFirstSample = lIdxLastSample-@NbrSamplesPerBuffer
          if (lIdxFirstSample < iIdxStartSample)
            lIdxFirstSample = iIdxStartSample
          end
          prepareBuffer(lIdxFirstSample, lIdxLastSample)
          # Check if we need to return a sub-copy of the buffer
          lBuffer = []
          if ((lIdxFirstSample == @IdxStartBufferSample) and
              (lIdxLastSample == @IdxEndBufferSample))
            lBuffer = @Buffer
          else
            lBuffer = extractSubBuffer(@Buffer, lIdxFirstSample - @IdxStartBufferSample, lIdxLastSample - @IdxStartBufferSample)
          end
          # Call client code
          yield(lBuffer, lIdxLastSample - lIdxFirstSample + 1)
          lIdxLastSample = lIdxFirstSample-1
          if (lIdxLastSample < iIdxStartSample)
            lIdxLastSample = nil
          end
        end
      end

      # Ensure that a given samples range is loaded in the buffer.
      # Use the caching mechanism if needed.
      # The buffer might contain more samples than desired.
      #
      # Parameters:
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with [optional = @NbrSamples-1]
      def prepareBuffer(iIdxStartSample, iIdxEndSample)
        if ((@Buffer == nil) or
            (iIdxStartSample < @IdxStartBufferSample) or
            (iIdxEndSample > @IdxEndBufferSample))
          # Read all from the data
          @Buffer = readBuffer(iIdxStartSample, iIdxEndSample)
          @IdxStartBufferSample = iIdxStartSample
          @IdxEndBufferSample = iIdxEndSample
        end
      end

      # Get the current buffer
      #
      # Return:
      # * _Object_: The current buffer
      # * _Integer_: The first sample of the buffer
      # * _Integer_: The last sample of the buffer
      def getCurrentBuffer
        return @Buffer, @IdxStartBufferSample, @IdxEndBufferSample
      end

    end

  end

end
