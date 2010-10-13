# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class ApplyVolumeFct

      include WSK::Common
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
        rError = nil

        lIdxBegin = readDuration(@Begin, iInputData.Header.SampleRate)
        lIdxEnd = readDuration(@End, iInputData.Header.SampleRate)
        if (lIdxEnd >= iInputData.NbrSamples)
          rError = RuntimeError.new("Transformation ends at #{lIdxEnd}, superceeding last sample (#{iInputData.NbrSamples-1})")
        else
          require 'WSK/VolumeUtils/VolumeUtils'
          lVolumeUtils = VolumeUtils::VolumeUtils.new
          # Create the C object corresponding to the function
          lStrFunction = nil
          # Read the function from the file
          if (File.exists?(@FctFileName))
            begin
              File.open(@FctFileName, 'r') do |iFile|
                lStrFunction = iFile.read
              end
            rescue Exception
              rError = $!
            end
          else
            rError = RuntimeError.new("Missing file #{@FctFileName}")
          end
          if (rError == nil)
            lFunction = nil
            begin
              lFunction = eval(lStrFunction)
            rescue Exception
              rError = RuntimeError.new("Invalid function specified in file #{@FctFileName}: #{$!}")
            end
            if (rError == nil)
              lCFunction = lVolumeUtils.createCFunction(lFunction, lIdxBegin, lIdxEnd)
              # First, write samples before
              iInputData.eachRawBuffer(0, lIdxBegin-1) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
                oOutputData.pushRawBuffer(iInputRawBuffer)
              end
              # Then apply volume transformation
              lIdxBufferSample = lIdxBegin
              iInputData.eachRawBuffer(lIdxBegin, lIdxEnd) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
                oOutputData.pushRawBuffer(lVolumeUtils.applyVolumeFct(lCFunction, iInputRawBuffer, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels, iNbrSamples, lIdxBufferSample))
                lIdxBufferSample += iNbrSamples
              end
              # Last, write samples after
              iInputData.eachRawBuffer(lIdxEnd+1) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
                oOutputData.pushRawBuffer(iInputRawBuffer)
              end
            end
          end
        end

        return rError
      end

    end

  end

end