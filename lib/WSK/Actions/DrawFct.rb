# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class DrawFct

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
        rError = nil

        lFunction = WSK::Functions::Function.new
        begin
          lFunction.readFromFile(@FctFileName)
        rescue Exception
          rError = $!
        end
        if (rError == nil)
          # Then draw it
          lMaxY = lFunction.getBounds[3]
          if (@UnitDB == 1)
            lMaxY = (2**(lMaxY.to_f/6)).to_r
          end
          lMedianValue = ((2**(iInputData.Header.NbrBitsPerSample-1)-1)/lMaxY).to_i
          logInfo "Draw function with maximal ratio #{lMaxY.to_s('F')}, using median value #{lMedianValue}"
          # Take the median value as a fraction of the maximal value
          lFunction.draw(iInputData, oOutputData, 0, iInputData.NbrSamples-1, (@UnitDB == 1), lMedianValue)
        end

        return rError
      end

    end

  end

end
