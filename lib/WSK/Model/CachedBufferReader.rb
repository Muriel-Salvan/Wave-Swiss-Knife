#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

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
      # * *iOptions* (<em>map<Symbol,Object></em>): Additional options [optional = {}]:
      # ** *:NbrSamplesPrefetch* (_Integer_): Specify a number of samples to effectively read if the data needs to be accessed. This number will always be minored by the number of samples to read and majored by the number of samples per buffer. [optional = 0]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iBuffer* (_String_): The buffer
      # ** *iNbrSamples* (_Integer_): The number of samples in this buffer
      def eachBuffer(iIdxStartSample = 0, iIdxEndSample = @NbrSamples-1, iOptions = {})
        lNbrSamplesPrefetch = iOptions[:NbrSamplesPrefetch]
        if (lNbrSamplesPrefetch == nil)
          lNbrSamplesPrefetch = 0
        end
        lIdxFirstSample = iIdxStartSample
        while (lIdxFirstSample <= iIdxEndSample)
          lIdxLastSample = lIdxFirstSample+@NbrSamplesPerBuffer
          if (lIdxLastSample > iIdxEndSample)
            lIdxLastSample = iIdxEndSample
          end
          # Compute the last sample to prefetch
          lIdxLastSamplePrefetch = lIdxFirstSample + lNbrSamplesPrefetch
          if (lIdxLastSamplePrefetch < lIdxLastSample)
            lIdxLastSamplePrefetch = lIdxLastSample
          elsif (lIdxLastSamplePrefetch > lIdxFirstSample+@NbrSamplesPerBuffer)
            lIdxLastSamplePrefetch = lIdxFirstSample+@NbrSamplesPerBuffer
          end
          prepareBuffer(lIdxFirstSample, lIdxLastSample, lIdxFirstSample, lIdxLastSamplePrefetch)
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
        end
      end

      # Iterate through the buffers in reverse order.
      #
      # Parameters:
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with [optional = @NbrSamples-1]
      # * *iOptions* (<em>map<Symbol,Object></em>): Additional options [optional = {}]:
      # ** *:NbrSamplesPrefetch* (_Integer_): Specify a number of samples to effectively read if the data needs to be accessed. This number will always be minored by the number of samples to read and majored by the number of samples per buffer. [optional = 0]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iBuffer* (_String_): The buffer
      # ** *iNbrSamples* (_Integer_): The number of samples in this buffer
      def eachReverseBuffer(iIdxStartSample = 0, iIdxEndSample = @NbrSamples-1, iOptions = {})
        lNbrSamplesPrefetch = iOptions[:NbrSamplesPrefetch]
        if (lNbrSamplesPrefetch == nil)
          lNbrSamplesPrefetch = 0
        end
        lIdxLastSample = iIdxEndSample
        while (lIdxLastSample >= iIdxStartSample)
          lIdxFirstSample = lIdxLastSample-@NbrSamplesPerBuffer
          if (lIdxFirstSample < iIdxStartSample)
            lIdxFirstSample = iIdxStartSample
          end
          # Compute the first sample to prefetch
          lIdxFirstSamplePrefetch = lIdxLastSample - lNbrSamplesPrefetch
          if (lIdxFirstSamplePrefetch > lIdxFirstSample)
            lIdxFirstSamplePrefetch = lIdxFirstSample
          elsif (lIdxFirstSamplePrefetch < lIdxLastSample-@NbrSamplesPerBuffer)
            lIdxFirstSamplePrefetch = lIdxLastSample-@NbrSamplesPerBuffer
          end
          prepareBuffer(lIdxFirstSample, lIdxLastSample, lIdxFirstSamplePrefetch, lIdxLastSample)
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
        end
      end

      # Ensure that a given samples range is loaded in the buffer.
      # Use the caching mechanism if needed.
      # The buffer might contain more samples than desired.
      #
      # Parameters:
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with [optional = @NbrSamples-1]
      # * *iIdxStartSamplePrefetch* (_Integer_): Specify the first sample to effectively read if the data needs to be accessed. [optional = iIdxStartSample]
      # * *iIdxEndSamplePrefetch* (_Integer_): Specify the last sample to effectively read if the data needs to be accessed. [optional = iIdxEndSample]
      def prepareBuffer(iIdxStartSample, iIdxEndSample, iIdxStartSamplePrefetch = iIdxStartSample, iIdxEndSamplePrefetch = iIdxEndSample)
        if ((@Buffer == nil) or
            (iIdxStartSample < @IdxStartBufferSample) or
            (iIdxEndSample > @IdxEndBufferSample))
          # Read all from the data
          @Buffer = readBuffer(iIdxStartSamplePrefetch, iIdxEndSamplePrefetch)
          @IdxStartBufferSample = iIdxStartSamplePrefetch
          @IdxEndBufferSample = iIdxEndSamplePrefetch
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
