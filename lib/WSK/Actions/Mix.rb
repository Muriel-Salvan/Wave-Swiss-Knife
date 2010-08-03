# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class Mix

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
        @NbrSamples = iInputData.NbrSamples
        
        # Decode the files list
        # list< [ String, Float ] >
        @LstFiles = []
        lLstParams = @MixFiles.split('|')
        if (lLstParams.size % 2 != 0)
          raise RuntimeError, 'Invalid mix parameters. Example: File1.wav|1|File2.wav|0.4'
        else
          (lLstParams.size/2).times do |iIdxFile|
            lFileName = lLstParams[iIdxFile*2]
            lCoeff = lLstParams[iIdxFile*2+1].to_f
            if (lCoeff == 0)
              logWarn "File #{lFileName} has a null coefficient. It won't be part of the mix."
            else
              # Check if the file exists
              if (File.exists?(lFileName))
                # Check the file's header
                lError = accessInputWaveFile(lFileName) do |iInputHeader2, iInputData2|
                  rSubError = nil
                  # Check that headers are the same
                  if (iInputHeader2 != iInputData.Header)
                    rSubError = RuntimeError.new("Mismatch headers with file #{lFileName}: First input file: #{iInputData.Header.inspect} Mix file: #{iInputHeader2.inspect}")
                  end
                  # OK, keep this file
                  @LstFiles << [ lFileName, lCoeff ]
                  if (iInputData2.NbrSamples > @NbrSamples)
                    @NbrSamples = iInputData2.NbrSamples
                  end
                  next rSubError
                end
                if (lError != nil)
                  raise lError
                end
              else
                raise RuntimeError, "Missing file: #{lFileName}"
              end
            end
          end
        end
        
        return @NbrSamples
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
        
        # Store the list of opened files, and initialize it with the input data (first file)
        # list< [ IO, InputData, Coeff, Buffer ] >
        lLstOpenedFiles = [ [ nil, iInputData, 1, nil ] ]
        @LstFiles.each do |iFileInfo|
          iFileName, iCoeff = iFileInfo
          lFileHandle = File.open(iFileName, 'rb')
          rError, lHeader, lInputData = getWaveFileAccesses(lFileHandle)
          if (rError == nil)
            lLstOpenedFiles << [ lFileHandle, lInputData, iCoeff, nil ]
          else
            break
          end
        end
        if (rError == nil)
          lMaxValue = 2**(iInputData.Header.NbrBitsPerSample-1)-1
          lMinValue = -2**(iInputData.Header.NbrBitsPerSample-1)
          # Loop until we meet the maximal number of samples
          # !!! We assume that buffers have the same size when read
          # Initialize buffers
          lNbrChannels = iInputData.Header.NbrChannels
          lNbrSamplesProcessed = 0
          lLstOpenedFiles.each do |ioFileInfo|
            lFileHandle, lInputData, lCoeff, lBuffer = ioFileInfo
            lInputData.getSampleData(0)
            lBuffer, lNbrSamples, lNbrChannels2 = lInputData.getCurrentBuffer
            ioFileInfo[3] = lBuffer
          end
          lNbrOpenedBuffers = lLstOpenedFiles.size
          while (lNbrOpenedBuffers > 0)
            # The resulting buffer
            # This is a buffer of float values
            lMixBuffer = nil
            lLstOpenedFiles.each do |ioFileInfo|
              lFileHandle, lInputData, lCoeff, lBuffer = ioFileInfo
              # If the file was already terminated, ignore it
              if (lBuffer != nil)
                if (lMixBuffer == nil)
                  lMixBuffer = lBuffer.map do |iValue|
                    next iValue*lCoeff
                  end
                else
                  # We first add the intersecting buffers
                  lIntersectingSize = (lMixBuffer.size < lBuffer.size) ? lMixBuffer.size : lBuffer.size
                  lIntersectingSize.times do |iIdxBuffer|
                    lMixBuffer[iIdxBuffer] += lBuffer[iIdxBuffer]*lCoeff
                  end
                  # Then we complete the mix buffer if needed
                  if (lMixBuffer.size < lBuffer.size)
                    lMixBuffer += lBuffer[lMixBuffer.size..-1].map do |iValue|
                      next iValue*lCoeff
                    end
                  end
                end
                # Set the next buffer of this file
                if (lNbrSamplesProcessed + lMixBuffer.size/lNbrChannels >= lInputData.NbrSamples)
                  ioFileInfo[3] = nil
                  lNbrOpenedBuffers -= 1
                else
                  # Read next Buffer
                  lInputData.getSampleData(lNbrSamplesProcessed + lMixBuffer.size/lNbrChannels)
                  lBuffer, lNbrSamples, lNbrChannels2 = lInputData.getCurrentBuffer
                  ioFileInfo[3] = lBuffer
                end
              end
            end
            # Round the mix buffer before writing it
            lIntMixBuffer = Array.new(lMixBuffer.size) do |iIdx|
              if (lMixBuffer[iIdx] > lMaxValue)
                logWarn "Exceeding maximal value: #{lMixBuffer[iIdx]}, set to #{lMaxValue}"
                next lMaxValue
              elsif (lMixBuffer[iIdx] < lMinValue)
                logWarn "Exceeding minimal value: #{lMixBuffer[iIdx]}, set to #{lMinValue}"
                next lMinValue
              else
                next lMixBuffer[iIdx].round
              end
            end
            oOutputData.pushBuffer(lIntMixBuffer)
            lNbrSamplesProcessed += lIntMixBuffer.size/lNbrChannels
          end
        end
        
        return rError
      end

    end

  end

end