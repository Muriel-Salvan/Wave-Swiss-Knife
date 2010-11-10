#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class ApplyVolumeFct

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

        lIdxBegin = readDuration(@Begin, iInputData.Header.SampleRate)
        lIdxEnd = readDuration(@End, iInputData.Header.SampleRate)
        if (lIdxEnd == -1)
          lIdxEnd = iInputData.NbrSamples - 1
        end
        if (lIdxEnd >= iInputData.NbrSamples)
          rError = RuntimeError.new("Transformation ends at #{lIdxEnd}, superceeding last sample (#{iInputData.NbrSamples-1})")
        else
          lFunction = WSK::Functions::Function.new
          begin
            lFunction.readFromFile(@FctFileName)
          rescue Exception
            rError = $!
          end
          if (rError == nil)
            # First, write samples before
            iInputData.eachRawBuffer(0, lIdxBegin-1) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
              oOutputData.pushRawBuffer(iInputRawBuffer)
            end
            # Then apply volume transformation
            lFunction.applyOnVolume(iInputData, oOutputData, lIdxBegin, lIdxEnd, (@UnitDB == 1))
            # Last, write samples after
            iInputData.eachRawBuffer(lIdxEnd+1) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
              oOutputData.pushRawBuffer(iInputRawBuffer)
            end
          end
        end

        return rError
      end

    end

  end

end