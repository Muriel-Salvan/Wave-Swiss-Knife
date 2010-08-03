# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Model

    class Header

      # Audio format
      # PCM = 1 (i.e. Linear quantization)
      # Values other than 1 indicate some form of compression.
      #   Integer
      attr_reader :AudioFormat

      # Number of channels
      #   Integer
      attr_reader :NbrChannels

      # Sample Rate
      #   Integer
      attr_reader :SampleRate

      # Bits per sample
      #   Integer
      attr_reader :NbrBitsPerSample

      # Constructor
      #
      # Parameters:
      # * *iAudioFormat* (_Integer_): Audio format
      # * *iNbrChannels* (_Integer_): Number of channels
      # * *iSampleRate* (_Integer_): Sample rate
      # * *iNbrBitsPerSample* (_Integer_): Number of bits per channel's sample
      def initialize(iAudioFormat, iNbrChannels, iSampleRate, iNbrBitsPerSample)
        @AudioFormat, @NbrChannels, @SampleRate, @NbrBitsPerSample = iAudioFormat, iNbrChannels, iSampleRate, iNbrBitsPerSample
        # The pack/unpack formula to use
        lStrChannelPackFormula = ''
        case @NbrBitsPerSample
        when 8
          lStrChannelPackFormula = 'C'
        when 16
          lStrChannelPackFormula = 's'
        when 24
          lStrChannelPackFormula = 'Cs'
        when 32
          lStrChannelPackFormula = 'l'
        else
          raise RuntimeError.new("#{@NbrBitsPerSample} bits PCM data not supported.")
        end
        @StrSamplePackFormula = lStrChannelPackFormula*@NbrChannels
      end

      # Get decoded samples from an encoded PCM string.
      #
      # Parameters:
      # * *iEncodedString* (_String_): The encoded string
      # * *iNbrSamplesToDecode* (_String_): Number of samples to decode
      # Return:
      # * <em>list<Integer></em>: The list of samples (there will be iNbrSamplesToDecode*@NbrChannels values)
      def getDecodedSamples(iEncodedString, iNbrSamplesToDecode)
        rSamples = iEncodedString.unpack(@StrSamplePackFormula*iNbrSamplesToDecode)

        if (@NbrBitsPerSample == 8)
          # Values are read unsigned. Shift them.
          rSamples.map! do |iChannelValue|
            next iChannelValue-128
          end
        elsif (@NbrBitsPerSample == 24)
          # Each channel value has been decoded into 2 integers. We have to sum them.
          lRealSamples = []
          (iNbrSamplesToDecode*@NbrChannels).times do |iIdxChannelSample|
            lIdxSamples = iIdxChannelSample*2
            lRealSamples[iIdxChannelSample] = rSamples[lIdxSamples] + rSamples[lIdxSamples+1] * 256
          end
          rSamples = lRealSamples
        end

        return rSamples
      end

      # Get encoded PCM string from decoded samples
      #
      # Parameters:
      # * *iChannelSamples* (<em>list<Integer></em>): The list of samples to encode
      # Return:
      # * _String_: Encoded PCM samples
      def getEncodedString(iChannelSamples)
        lRealChannelSamples = nil
        if (@NbrBitsPerSample == 8)
          # Values have to be stored unsigned. Shift them.
          lRealChannelSamples = []
          iChannelSamples.each do |iChannelValue|
            lRealChannelSamples << iChannelValue+128
          end
        elsif (@NbrBitsPerSample == 24)
          # Each channel must be split into 2 integer values before encoding.
          lRealChannelSamples = []
          iChannelSamples.size.times do |iIdxChannelSample|
            lIdxReal = iIdxChannelSample*2
            lRealChannelSamples[lIdxReal] = iChannelSamples[iIdxChannelSample] & 255
            lRealChannelSamples[lIdxReal+1] = iChannelSamples[iIdxChannelSample] / 256
          end
        else
          lRealChannelSamples = iChannelSamples
        end

        return lRealChannelSamples.pack(@StrSamplePackFormula*(iChannelSamples.size/@NbrChannels))
      end

      # Compare with a different object
      #
      # Parameters:
      # * *iOther* (_Object_): Another object
      # Return:
      # * _Boolean_: Are the objects equal ?
      def ==(iOther)
        return ((iOther.object_id == self.object_id) or
                ((iOther.is_a?(WSK::Model::Header)) and
                 (iOther.AudioFormat == @AudioFormat) and
                 (iOther.NbrChannels == @NbrChannels) and
                 (iOther.SampleRate == @SampleRate) and
                 (iOther.NbrBitsPerSample == @NbrBitsPerSample)))

      end

    end

  end

end
