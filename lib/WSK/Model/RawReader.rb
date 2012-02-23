#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'WSK/Model/CachedBufferReader'

module WSK

  module Model

    # Implement a RAW file reader using cached buffer reader.
    # Buffers returned are of type String.
    class RawReader < CachedBufferReader

      # Buffer size.
      # It is expressed in bytes.
      #   Integer
      BUFFER_SIZE = 8388608

      # Constructor
      #
      # Parameters::
      # * *iFile* (_IO_): The file descriptor. Don't use it externally as long as it is used by this class.
      # * *iFirstSampleFilePos* (_Integer_): Position in the file of the first sample
      # * *iSampleSize* (_Integer_): Size of a single sample to read
      # * *iNbrSamples* (_Integer_): Total number of samples
      def initialize(iFile, iFirstSampleFilePos, iSampleSize, iNbrSamples)
        @File, @FirstSampleFilePos, @SampleSize, @NbrSamples = iFile, iFirstSampleFilePos, iSampleSize, iNbrSamples
        super()
      end

      # Get the number of samples read per buffer
      #
      # Return::
      # * _Integer_: Nnumber of samples in 1 buffer
      def getNbrSamplesPerBuffer
        return BUFFER_SIZE/@SampleSize
      end

      # Get the total number of samples
      #
      # Return::
      # * _Integer_: Total number of samples
      def getNbrSamples
        return @NbrSamples
      end

      # Read a buffer
      #
      # Parameters::
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with
      # Return::
      # * _Object_: The corresponding buffer
      def readBuffer(iIdxStartSample, iIdxEndSample)
        @File.seek(@FirstSampleFilePos + iIdxStartSample*@SampleSize)
        log_debug "Raw read samples [#{iIdxStartSample} - #{iIdxEndSample}]"
        return @File.read((iIdxEndSample-iIdxStartSample+1)*@SampleSize)
      end

      # Extract a sub-buffer for the given index range
      #
      # Parameters::
      # * *iBuffer* (_Object_): The buffer to extract from
      # * *iIdxStartSample* (_Integer_): Index of the first sample to begin with
      # * *iIdxEndSample* (_Integer_): Index of the last sample to end with
      # Return::
      # * _Object_: The sub buffer
      def extractSubBuffer(iBuffer, iIdxStartSample, iIdxEndSample)
        return iBuffer[iIdxStartSample*@SampleSize..(iIdxEndSample+1)*@SampleSize-1]
      end

    end

  end

end
