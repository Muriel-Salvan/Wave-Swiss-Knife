#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class DCShifter

      include WSK::Maps

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
        # The offset, per channel
        # list< Integer >
        lOffsets = nil
        if (@Offset.split('|').size == 1)
          lOffsets = [@Offset.to_i] * iInputData.Header.NbrChannels
        else
          lOffsets = @Offset.split('|').map { |iStrValue| iStrValue.to_i }
        end
        
        # List of functions to apply, per channel
        lMaxValue = 2**(iInputData.Header.NbrBitsPerSample-1) - 1
        lMinValue = -2**(iInputData.Header.NbrBitsPerSample-1)
        lFunctions = []
        lOffsets.each do |iOffset|
          lFunctions << {
            :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
            :MinValue => lMinValue,
            :MaxValue => lMaxValue,
            :Points => {
              lMinValue => lMinValue + iOffset,
              lMaxValue => lMaxValue + iOffset
            }
          }
        end
        applyMapFunctions(iInputData, oOutputData, lFunctions)

        return nil
      end

    end

  end

end
