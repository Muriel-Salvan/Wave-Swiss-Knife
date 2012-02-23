#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class Multiply

      include WSK::Maps

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
        rError = nil

        lCoeff = nil
        lMatch = @Coeff.match(/^(.*)db$/)
        if (lMatch == nil)
          lMatch = @Coeff.match(/^(\d*)\/(\d*)$/)
          if (lMatch == nil)
            log_err "Incorrect coefficient: #{@Coeff} is not in the form X/Y or in the form Xdb"
            rError = RuntimeError.new("Incorrect coefficient: #{@Coeff} is not in the form X/Y or in the form Xdb")
          else
            lNum, lDenom = lMatch[1..2].map { |iStrValue| iStrValue.to_i }
            lCoeff = Rational(lNum, lDenom)
          end
        else
          lCoeff = 2**(lMatch[1].to_f/6)
        end

        if (rError == nil)
          lMaxValue = 2**(iInputData.Header.NbrBitsPerSample-1) - 1
          lMinValue = -2**(iInputData.Header.NbrBitsPerSample-1)
          lFunction = {
            :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
            :MinValue => lMinValue,
            :MaxValue => lMaxValue,
            :Points => {
              lMinValue => (lMinValue*lCoeff).to_i,
              lMaxValue => (lMaxValue*lCoeff).to_i
            }
          }
          apply_map_functions(iInputData, oOutputData, [lFunction]*iInputData.Header.NbrChannels)
        end

        return rError
      end

    end

  end

end
