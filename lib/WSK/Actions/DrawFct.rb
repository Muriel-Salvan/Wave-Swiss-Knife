#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class DrawFct

      include WSK::Common
      include WSK::Functions

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return::
      # * _Integer_: The number of samples to be written
      def get_nbr_samples(iInputData)
        @Function = WSK::Functions::Function.new
        @Function.read_from_file(@FctFileName)
        lMinX, _, lMaxX, _ = @Function.get_bounds
        @NbrSamplesOut = lMaxX.to_i-lMinX.to_i+1

        return @NbrSamplesOut
      end

      # Execute
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return::
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        rError = nil

        # Then draw it
        lMaxY = @Function.get_bounds[3]
        if (@UnitDB == 1)
          lMaxY = (2**(lMaxY.to_f/6)).to_r
        end
        lMedianValue = ((2**(iInputData.Header.NbrBitsPerSample-1)-1)/lMaxY).to_i
        log_info "Draw function with maximal ratio #{lMaxY.to_f}, using median value #{lMedianValue}"
        # Take the median value as a fraction of the maximal value
        @Function.draw(iInputData, oOutputData, 0, @NbrSamplesOut-1, (@UnitDB == 1), lMedianValue)

        return rError
      end

    end

  end

end
