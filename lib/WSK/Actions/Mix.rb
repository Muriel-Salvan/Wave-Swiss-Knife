#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

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
        # list< [ IO, InputData, Coeff, Buffer, NbrSamplesInBuffer ] >
        lLstOpenedFiles = [ [ nil, iInputData, 1.0, nil, nil ] ]
        @LstFiles.each do |iFileInfo|
          iFileName, iCoeff = iFileInfo
          lFileHandle = File.open(iFileName, 'rb')
          rError, lHeader, lInputData = getWaveFileAccesses(lFileHandle)
          if (rError == nil)
            lLstOpenedFiles << [ lFileHandle, lInputData, iCoeff, nil, nil ]
          else
            break
          end
        end
        if (rError == nil)
          require 'WSK/ArithmUtils/ArithmUtils'
          lArithmUtils = WSK::ArithmUtils::ArithmUtils.new
          # Loop until we meet the maximal number of samples
          # !!! We assume that buffers have the same size when read
          # Initialize buffers
          lLstOpenedFiles.each do |ioFileInfo|
            lFileHandle, lInputData, lCoeff, lBuffer = ioFileInfo
            lInputData.eachRawBuffer do |iRawBuffer, iNbrSamples, iNbrChannels|
              break
            end
            lRawBuffer, lNbrSamples, lNbrChannels2 = lInputData.getCurrentRawBuffer
            ioFileInfo[3] = lRawBuffer
            ioFileInfo[4] = lNbrSamples
          end
          # Sort the list based on the number of samples of each file.
          # This is a prerequisite of the C function mixing.
          lLstOpenedFiles.sort! do |iOF1, iOF2|
            next (iOF2[1].NbrSamples <=> iOF1[1].NbrSamples)
          end
          lLstRemainingOpenedFiles = lLstOpenedFiles.clone
          lNbrSamplesProcessed = 0
          while (!lLstRemainingOpenedFiles.empty?)
            # Mix all buffers
            lMixRawBuffer, lNbrSamplesWritten = lArithmUtils.mixBuffers(lLstRemainingOpenedFiles, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels)
            # Remove the ones that don't have data anymore
            lLstRemainingOpenedFiles.delete_if do |ioFileInfo|
              lFileHandle, lInputData, lCoeff, lRawBuffer = ioFileInfo
              rToBeDeleted = false
              # Set the next buffer of this file
              if (lNbrSamplesProcessed + lNbrSamplesWritten >= lInputData.NbrSamples)
                # Close the handle if it is not the main input
                if (lFileHandle != nil)
                  lFileHandle.close
                end
                rToBeDeleted = true
              else
                # Read next Buffer
                lInputData.eachRawBuffer(lNbrSamplesProcessed + lNbrSamplesWritten) do |iRawBuffer, iNbrSamples, iNbrChannels|
                  break
                end
                lRawBuffer, lNbrSamples, lNbrChannels2 = lInputData.getCurrentRawBuffer
                ioFileInfo[3] = lRawBuffer
                ioFileInfo[4] = lNbrSamples
              end
              next rToBeDeleted
            end
            oOutputData.pushRawBuffer(lMixRawBuffer)
            lNbrSamplesProcessed += lNbrSamplesWritten
          end
        end
        
        return rError
      end

    end

  end

end