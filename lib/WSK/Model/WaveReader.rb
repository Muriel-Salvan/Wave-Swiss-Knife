require 'WSK/Model/CachedBufferReader'

module WSK

  module Model

    # Implement a Wave file reader using a raw buffer reader.
    # Buffers returned are of type list<Integer>.
    class WaveReader < CachedBufferReader

      # Number of channel samples per buffer.
      #   Integer
      NBR_CHANNEL_SAMPLES_PER_BUFFER = 2097152

      # Constructor
      #
      # Parameters:
      # * *iRawReader* (_CachedBufferReader_): The reader that provides raw data
      # * *iHeader* (<em>WSK::Model::Header</em>): Corresponding file header
      def initialize(iRawReader, iHeader)
        @RawReader, @Header = iRawReader, iHeader
        super()
      end

      # Get the number of samples read per buffer
      #
      # Return:
      # * _Integer_: Nnumber of samples in 1 buffer
      def getNbrSamplesPerBuffer
        return NBR_CHANNEL_SAMPLES_PER_BUFFER/@Header.NbrChannels
      end

      # Get the total number of samples
      #
      # Return:
      # * _Integer_: Total number of samples
      def getNbrSamples
        return @RawReader.getNbrSamples
      end

      # Read a buffer
      #
      # Parameters:
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with
      # Return:
      # * _Object_: The corresponding buffer
      def readBuffer(iIdxStartSample, iIdxEndSample)
        lRawBuffer = nil
        lNbrSamplesToRead = iIdxEndSample - iIdxStartSample + 1
        @RawReader.eachBuffer(iIdxStartSample, iIdxEndSample) do |iBuffer, iNbrSamples|
          if (lRawBuffer == nil)
            if (lNbrSamplesToRead == iNbrSamples)
              # We have the buffer directly. No copy.
              lRawBuffer = iBuffer
            else
              # We will need to concatenate other buffers. Clone it.
              lRawBuffer = iBuffer.clone
            end
          else
            # Concatenate
            lRawBuffer.concat(iBuffer)
          end
        end
        logDebug "Decode samples [#{iIdxStartSample} - #{iIdxEndSample}]"
        
        return @Header.getDecodedSamples(lRawBuffer, lNbrSamplesToRead)
      end

      # Extract a sub-buffer for the given index range
      #
      # Parameters:
      # * *iBuffer* (_Object_): The buffer to extract from
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with
      # Return:
      # * _Object_: The sub buffer
      def extractSubBuffer(iBuffer, iIdxStartSample, iIdxEndSample)
        return iBuffer[iIdxStartSample*@Header.NbrChannels..(iIdxEndSample+1)*@Header.NbrChannels-1]
      end

    end

  end

end
