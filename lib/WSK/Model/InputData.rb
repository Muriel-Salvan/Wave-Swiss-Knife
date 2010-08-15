
module WSK

  module Model

    class InputData

      # Here we define the buffer size.
      # The buffer will be used to store contiguous audio data in RAM.
      # Each InputData object will never use more than this size.
      # It is expressed in bytes.
      #   Integer
      BUFFER_SIZE = 8388608

      # Number of samples in the data
      #   Integer
      attr_reader :NbrSamples

      # Header of the input data
      #   WSK::Model::Header
      attr_reader :Header

      # Constructor
      #
      # Parameters:
      # * *iFile* (_IO_): The file descriptor. Don't use it externally as long as it is used by this class.
      # * *iHeader* (<em>WSK::Model::Header</em>): Corresponding file header
      def initialize(iFile, iHeader)
        @File, @Header = iFile, iHeader
        @NbrSamples = nil
        @StrUnpackSample = nil
        # Size of a sample
        # Integer
        @SampleSize = (@Header.NbrChannels*@Header.NbrBitsPerSample)/8
        # Compute the number of samples to store in the buffer
        @NbrSamplesPerBuffer = BUFFER_SIZE/@SampleSize
        # Compute the real buffer size (could be different than BUFFER_SIZE if BUFFER_SIZE % @BlockAlign != 0)
        @RealBufferSize = @NbrSamplesPerBuffer*@SampleSize
        # The position of the first sample of the buffer
        # Integer
        @IdxBufferSample = 0
        # The buffer itself, made of the list of channel values
        # list< Integer >
        @Buffer = nil
        # The raw buffer
        # String
        @RawBuffer = nil
      end

      # Check that data seems coherent, and initialize the cursor
      #
      # Return:
      # * _Exception_: Error, or nil in case of success
      def initCursor
        rError = nil

        # Read the size of the data
        rError, lDataSize = RIFFReader.new(@File).setFilePos('data')
        if (rError == nil)
          # Check that the data size is coherent
          if (lDataSize % @SampleSize == 0)
            @NbrSamples = lDataSize / @SampleSize
            @FirstSamplePos = @File.pos
          else
            rError = RuntimeError.new("Data size (#{lDataSize} should be a multiple of #{@SampleSize} according to header.")
          end
        end

        return rError
      end

      # Iterate through the samples
      #
      # Parameters:
      # * *iIdxBeginSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iInputSampleData* (<em>list<Integer></em>): The list of values (1 per channel)
      def each(iIdxBeginSample = 0)
        (@NbrSamples-iIdxBeginSample).times do |iIdxSample|
          yield(getSampleData(iIdxBeginSample+iIdxSample))
        end
      end

      # Iterate through the buffers. This is far more efficient than iterating over samples.
      #
      # Parameters:
      # * *iIdxBeginSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iInputBuffer* (<em>list<Integer></em>): The list of channel values
      # ** *iNbrSamples* (_Integer_): The number of samples in this buffer
      # ** *iNbrChannels* (_Integer_): The number of channels in this buffer
      def eachBuffer(iIdxBeginSample = 0)
        lIdxFirstSample = iIdxBeginSample
        while (lIdxFirstSample != nil)
          # Load the buffer
          getSampleData(lIdxFirstSample)
          lBuffer = nil
          if (@IdxBufferSample == lIdxFirstSample)
            # The buffer is already positioned on the sample we want to read
            lBuffer = @Buffer
          else
            # The sample we want to read is not the first buffer's sample one
            # !!! Do not put this code in case iIdxBeginSample == @IdxBufferSample for perfomance reasons: don't copy for nothing in memory.
            lBuffer = @Buffer[(lIdxFirstSample-@IdxBufferSample)*@Header.NbrChannels..-1]
          end
          lNbrSamplesInBuffer = lBuffer.size/@Header.NbrChannels
          yield(lBuffer, lNbrSamplesInBuffer, @Header.NbrChannels)
          lIdxFirstSample += lNbrSamplesInBuffer
          if (lIdxFirstSample >= @NbrSamples)
            lIdxFirstSample = nil
          end
        end
      end

      # Get the current buffer.
      # !!! This must be called only if the buffer was previously initialized (call getSampleSata to do so).
      #
      # Return:
      # * <em>list<Integer></em>: The list of channel values
      # * _Integer_: The number of samples in this buffer
      # * _Integer_: The number of channels in this buffer
      def getCurrentBuffer
        return @Buffer, @Buffer.size/@Header.NbrChannels, @Header.NbrChannels
      end

      # Iterate through the buffers in the reverse order. This is far more efficient than iterating over samples.
      #
      # Parameters:
      # * *iIdxEndSample* (_Integer_): Index of the first sample to begin with [optional = @NbrSamples-1]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iInputBuffer* (<em>list<Integer></em>): The list of channel values
      # ** *iNbrSamples* (_Integer_): The number of samples in this buffer
      # ** *iNbrChannels* (_Integer_): The number of channels in this buffer
      def eachReverseBuffer(iIdxEndSample = @NbrSamples-1)
        lIdxLastSample = iIdxEndSample
        while (lIdxLastSample != nil)
          # Load the buffer
          getSampleData(lIdxLastSample, :ReverseBuffer => true)
          lBuffer = nil
          if (@IdxBufferSample+@Buffer.size-1== lIdxLastSample)
            # The buffer is already finishing on the last sample
            lBuffer = @Buffer
          else
            # The last sample is not the last buffer's one
            lBuffer = @Buffer[0..(lIdxLastSample-@IdxBufferSample+1)*@Header.NbrChannels-1]
          end
          yield(lBuffer, lBuffer.size/@Header.NbrChannels, @Header.NbrChannels)
          if (@IdxBufferSample == 0)
            lIdxLastSample = nil
          else
            lIdxLastSample = @IdxBufferSample - 1
          end
        end
      end

      # Iterate through the buffers in raw mode (strings read directly without unpacking).
      # This is far more efficient than iterating over samples or unpacked buffers.
      #
      # Parameters:
      # * *iIdxBeginSample* (_Integer_): Index of the first sample to begin with [optional = 0]
      # * *iIdxLastSample* (_Integer_): Index of the last sample to end with [optional = @NbrSamples-1]
      # * *CodeBlock*: The code called for each iteration:
      # ** *iInputRawBuffer* (_String_): The raw buffer
      # ** *iNbrSamples* (_Integer_): The number of samples in this buffer
      # ** *iNbrChannels* (_Integer_): The number of channels in this buffer
      def eachRawBuffer(iIdxBeginSample = 0, iIdxLastSample = @NbrSamples-1)
        lNbrSamplesToRead = (iIdxLastSample-iIdxBeginSample+1)
        lNbrBuffers = lNbrSamplesToRead/@NbrSamplesPerBuffer
        if (lNbrSamplesToRead % @NbrSamplesPerBuffer != 0)
          lNbrBuffers += 1
        end
        lNbrBuffers.times do |iIdxBuffer|
          # Load the buffer
          lIdxFirstSample = iIdxBeginSample+iIdxBuffer*@NbrSamplesPerBuffer
          readRawBuffer(lIdxFirstSample)
          lNbrSamplesInBuffer = @RawBuffer.size/@SampleSize
          # If the last sample is met inside this buffer, truncate the buffer
          lBuffer = nil
          if (iIdxLastSample >= lIdxFirstSample+lNbrSamplesInBuffer-1)
            lBuffer = @RawBuffer
          else
            lBuffer = @RawBuffer[0..(iIdxLastSample-lIdxFirstSample+1)*@SampleSize-1]
            lNbrSamplesInBuffer = iIdxLastSample-lIdxFirstSample+1
          end
          yield(lBuffer, lNbrSamplesInBuffer, @Header.NbrChannels)
        end
      end

      # Get a sample's data
      #
      # Parameters:
      # * *iIdxSample* (_Integer_): Index of the sample to retrieve
      # * *iOptions* (<em>map<Symbol,Object></em>): Additional options [optional = {}]
      # ** *:ReverseBuffer* (_Boolean_): Do we load the previous buffer containing this sample if needed ? [optional = false]
      # Return:
      # * <em>list<Integer></em>: The list of values (1 per channel), or nil in case of error
      def getSampleData(iIdxSample, iOptions = {})
        lReverseBuffer = (iOptions[:ReverseBuffer] != nil) ? iOptions[:ReverseBuffer] : false

        # First, read the buffer if needed
        if ((@Buffer == nil) or
            (iIdxSample < @IdxBufferSample) or
            (iIdxSample >= @NbrSamplesPerBuffer + @IdxBufferSample))
          # We have to read from the file
          if (lReverseBuffer)
            # Read the previous data
            lIdxFirstSampleToRead = iIdxSample-@NbrSamplesPerBuffer+1
            if (lIdxFirstSampleToRead < 0)
              lIdxFirstSampleToRead = 0
            end
          else
            lIdxFirstSampleToRead = iIdxSample
          end
          readRawBuffer(lIdxFirstSampleToRead)
          # Decode it
          @Buffer = @Header.getDecodedSamples(@RawBuffer, @RawBuffer.size/@SampleSize)
          logDebug "Read buffer @ #{iIdxSample} => #{@Buffer[0..31].join(' ')}"
        end
        # Now, extract the sample from our buffer
        lIdxFirstChannelValue = (iIdxSample-@IdxBufferSample)*@Header.NbrChannels

        return @Buffer[lIdxFirstChannelValue..lIdxFirstChannelValue+@Header.NbrChannels-1]
      end

      private

      # Read the raw buffer.
      # This method just reads from the file a complete buffer without unpacking it.
      # It stores it in @RawBuffer.
      # If the raw buffer was already on the required sample, nothing is read.
      #
      # Parameters:
      # * *iIdxSample* (_Integer_): Index of the sample to retrieve
      def readRawBuffer(iIdxSample)
        # TODO: Implement a cache on the RawBuffer, as some plugins (FFT comparisons in NoiseGate) access contiguous data frequently using RawBuffers only.
        if ((@RawBuffer == nil) or
            (iIdxSample != @IdxBufferSample))
          # Read it from the file
          @IdxBufferSample = iIdxSample
          @File.seek(@FirstSamplePos + iIdxSample*@SampleSize)
          @RawBuffer = @File.read(@RealBufferSize)
          logDebug "Read raw buffer from file pos #{@FirstSamplePos + iIdxSample*@SampleSize} (Sample #{iIdxSample})"
        end
      end

    end

  end

end
