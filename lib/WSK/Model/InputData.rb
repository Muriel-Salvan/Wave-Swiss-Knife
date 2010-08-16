
require 'WSK/Model/RawReader.rb'
require 'WSK/Model/WaveReader.rb'

module WSK

  module Model

    class InputData

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
      end

      # Check that data seems coherent, and initialize the cursor
      #
      # Return:
      # * _Exception_: Error, or nil in case of success
      def initCursor
        rError = nil

        # Size of a sample
        # Integer
        lSampleSize = (@Header.NbrChannels*@Header.NbrBitsPerSample)/8
        # Read the size of the data
        rError, lDataSize = RIFFReader.new(@File).setFilePos('data')
        if (rError == nil)
          # Check that the data size is coherent
          if (lDataSize % lSampleSize == 0)
            @NbrSamples = lDataSize / lSampleSize
            @RawReader = RawReader.new(@File, @File.pos, lSampleSize, @NbrSamples)
            @WaveReader = WaveReader.new(@RawReader, @Header)
          else
            rError = RuntimeError.new("Data size (#{lDataSize} should be a multiple of #{lSampleSize} according to header.")
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
        eachBuffer(iIdxBeginSample) do |iBuffer, iNbrSamples|
          iBuffer.size.times do |iIdxSample|
            yield(iBuffer[iIdxSample*@Header.NbrChannels..(iIdxSample+1)*@Header.NbrChannels-1])
          end
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
        @WaveReader.eachBuffer(iIdxBeginSample) do |iBuffer, iNbrSamples|
          yield(iBuffer, iNbrSamples, @Header.NbrChannels)
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
        rBuffer, lIdxStartSample, lIdxEndSample = @WaveReader.getCurrentBuffer

        return rBuffer, lIdxEndSample-lIdxStartSample+1, @Header.NbrChannels
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
        @WaveReader.eachReverseBuffer(0, iIdxEndSample) do |iBuffer, iNbrSamples|
          yield(iBuffer, iNbrSamples, @Header.NbrChannels)
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
        @RawReader.eachBuffer(iIdxBeginSample, iIdxLastSample) do |iBuffer, iNbrSamples|
          yield(iBuffer, iNbrSamples, @Header.NbrChannels)
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
        rSampleData = nil

        lReverseBuffer = (iOptions[:ReverseBuffer] != nil) ? iOptions[:ReverseBuffer] : false
        if (lReverseBuffer)
          @WaveReader.eachReverseBuffer(0, iIdxSample) do |iBuffer, iNbrSamples|
            rSampleData = iBuffer[-@Header.NbrChannels..-1]
            break
          end
        else
          @WaveReader.eachBuffer(iIdxSample) do |iBuffer, iNbrSamples|
            rSampleData = iBuffer[0..@Header.NbrChannels-1]
            break
          end
        end

        return rSampleData
      end

    end

  end

end
