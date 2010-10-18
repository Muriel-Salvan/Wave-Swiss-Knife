# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class VolumeProfile

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
        if (lIdxEnd == -1)
          lIdxEnd = iInputData.NbrSamples - 1
        end
        if (lIdxEnd >= iInputData.NbrSamples)
          rError = RuntimeError.new("Profile ends at #{lIdxEnd}, superceeding last sample (#{iInputData.NbrSamples-1})")
        else
          lFunction = WSK::Functions::Function.new
          lFunction.readFromInputVolume(iInputData, lIdxBegin, lIdxEnd, lInterval)
          # Normalize the volume function on a [-1..1] scale
          lFunction.divideBy(2**(iInputData.Header.NbrBitsPerSample-1))
          lMinX, lMinY, lMaxX, lMaxY = lFunction.getBounds
          lDBMinY = val2db(lMinY, 1)[0]
          lDBMaxY = val2db(lMaxY, 1)[0]
          logInfo "Dynamic range: [#{sprintf('%.2f',lMinY)} - #{sprintf('%.2f',lMaxY)}] ([#{sprintf('%.2f',lDBMinY)}db - #{sprintf('%.2f',lDBMaxY)}db] = #{sprintf('%.2f',lDBMaxY-lDBMinY)}db)"
          lFunction.writeToFile(@FctFileName)
        end

        return rError
      end

    end

  end

end