#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class ApplyMap

      include WSK::Common

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return::
      # * _Integer_: The number of samples to be written
      def get_nbr_samples(iInputData)
        return iInputData.NbrSamples
      end

      # Execute
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return::
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        lTransformMap = nil
        File.open(@MapFileName, 'rb') do |iFile|
          lTransformMap = Marshal.load(iFile.read)
        end
        iInputData.each_buffer do |iBuffer, iNbrSamples, iNbrChannels|
          lTransformedBuffer = iBuffer.map do |iValue|
            if (lTransformMap[iValue] == nil)
              log_warn "Unknown value from the transform map: #{iValue}. Keeping it."
              next iValue
            else
              next lTransformMap[iValue]
            end
          end
          oOutputData.pushBuffer(lTransformedBuffer)
        end

        return nil
      end

    end

  end

end