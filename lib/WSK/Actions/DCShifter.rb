# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class DCShifter

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
          lOffsets = [@Offset] * iInputData.Header.NbrChannels
        else
          lOffsets = @Offset.split('|').map { |iStrValue| iStrValue.to_i }
        end
        lMaxValue = 2**(iInputData.Header.NbrBitsPerSample-1)-1
        lMinValue = -2**(iInputData.Header.NbrBitsPerSample-1)
        iInputData.eachBuffer do |iInputBuffer, iNbrSamples, iNbrChannels|
          lOutputBuffer = []
          lIdxChannel = 0
          iInputBuffer.each do |iValue|
            lNewValue = iValue + lOffsets[lIdxChannel]
            if (lNewValue > lMaxValue)
              logWarn "Exceeding maximal value: #{lNewValue}, set to #{lMaxValue}"
              lNewValue = lMaxValue
            elsif (lNewValue < lMinValue)
              logWarn "Exceeding minimal value: #{lNewValue}, set to #{lMinValue}"
              lNewValue = lMinValue
            end
            lOutputBuffer << lNewValue
            lIdxChannel += 1
            if (lIdxChannel == iNbrChannels)
              lIdxChannel = 0
            end
          end
          oOutputData.pushBuffer(lOutputBuffer)
        end

        return nil
      end

    end

  end

end
