#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class VolumeProfile

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
        return 0
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
          lFunction.read_from_input_volume(iInputData, lIdxBegin, lIdxEnd, lInterval, @RMSRatio)
          # Normalize the volume function on a [-1..1] scale
          lFunction.divide_by(Rational(2)**(iInputData.Header.NbrBitsPerSample-1))
          _, lMinY, _, lMaxY = lFunction.get_bounds
          lDBMinY = lFunction.value_val_2_db(lMinY, Rational(1))
          lDBMaxY = lFunction.value_val_2_db(lMaxY, Rational(1))
          log_info "Dynamic range: [#{sprintf('%.2f',lMinY)} - #{sprintf('%.2f',lMaxY)}] ([#{sprintf('%.2f',lDBMinY)}db - #{sprintf('%.2f',lDBMaxY)}db] = #{sprintf('%.2f',lDBMaxY-lDBMinY)}db)"
          lFunction.write_to_file(@FctFileName)
        end

        return rError
      end

    end

  end

end
