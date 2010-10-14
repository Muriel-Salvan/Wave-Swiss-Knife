# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class VolumeProfile

      include WSK::Common
      include WSK::Functions

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return:
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
        return 0
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        rError = nil

        lIdxBegin = readDuration(@Begin, iInputData.Header.SampleRate)
        lIdxEnd = readDuration(@End, iInputData.Header.SampleRate)
        lInterval = readDuration(@Interval, iInputData.Header.SampleRate)
        if (lIdxEnd >= iInputData.NbrSamples)
          rError = RuntimeError.new("Profile ends at #{lIdxEnd}, superceeding last sample (#{iInputData.NbrSamples-1})")
        else
          require 'WSK/VolumeUtils/VolumeUtils'
          lVolumeUtils = VolumeUtils::VolumeUtils.new
          # Create the C object that will store the volume profile
          # TODO
          # Profile
          lIdxCurrentSample = lIdxBegin
          while (lIdxCurrentSample <= lIdxEnd)
            lIdxCurrentEndSample = lIdxCurrentSample + lInterval - 1
            if (lIdxCurrentEndSample > lIdxEnd)
              lIdxCurrentEndSample = lIdxEnd
            end
            lRawBuffer = ''
            iInputData.eachRawBuffer(lIdxCurrentSample, lIdxCurrentEndSample, :NbrSamplesPrefetch => lIdxEnd-lIdxCurrentSample+1) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
              lRawBuffer += iInputRawBuffer
            end
            # Profile this buffer
            # TODO
            lIdxCurrentSample = lIdxCurrentEndSample + 1
          end
          # Get the profile back from C and write it into the required file
          # TODO
        end

        return 0
      end

    end

  end

end