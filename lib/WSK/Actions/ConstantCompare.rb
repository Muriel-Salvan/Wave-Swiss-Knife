#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class ConstantCompare

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
        if (iInputData.NbrSamples != @NbrSamples)
          log_err "Input data has #{iInputData.NbrSamples} samples. It should be #{@NbrSamples}"
        end
        lRawSample = iInputData.Header.getEncodedString([@Value]*iInputData.Header.NbrChannels)
        lCompareBuffer = nil
        lNbrSamplesProcessed = 0
        iInputData.each_raw_buffer do |iRawBuffer, iNbrSamples, iNbrChannels|
          if ((lCompareBuffer == nil) or
              (lCompareBuffer.size != iRawBuffer.size))
            # Create the comparison buffer
            lCompareBuffer = lRawSample*iNbrSamples
          end
          if (lCompareBuffer != iRawBuffer)
            log_err "Differences found between samples #{lNbrSamplesProcessed} and #{lNbrSamplesProcessed+iNbrSamples-1}"
          end
          lNbrSamplesProcessed += iNbrSamples
          $stdout.write("#{(lNbrSamplesProcessed*100)/iInputData.NbrSamples} %\015")
          $stdout.flush
        end

        return nil
      end

    end

  end

end