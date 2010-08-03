# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class ApplyMap

      include WSK::Common

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return:
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
        return iInputData.NbrSamples
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        lTransformMap = nil
        File.open(@MapFileName, 'rb') do |iFile|
          lTransformMap = Marshal.load(iFile.read)
        end
        iInputData.eachBuffer do |iBuffer, iNbrSamples, iNbrChannels|
          lTransformedBuffer = iBuffer.map do |iValue|
            if (lTransformMap[iValue] == nil)
              logWarn "Unknown value from the transform map: #{iValue}. Keeping it."
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