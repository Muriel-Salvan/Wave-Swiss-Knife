# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class NoiseGate

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
        # The bounds of the gating, per channel
        # list< [ Min, Max ] >
        lSilenceThresholds = nil
        if (@SilenceThreshold.split('|').size == 1)
          if (@SilenceThreshold.split(',').size == 1)
            lSilenceThresholds = [ [ -@SilenceThreshold.to_i, @SilenceThreshold.to_i ] ] * iInputData.Header.NbrChannels
          else
            lSilenceThresholds = [@SilenceThreshold.split(',').map { |iStrValue| iStrValue.to_i }] * iInputData.Header.NbrChannels
          end
        else
          lSilenceThresholds = []
          @SilenceThreshold.split('|').each do |iSilenceThresholdInfo|
            if (iSilenceThresholdInfo.split(',').size == 1)
              lSilenceThresholds << [ -iSilenceThresholdInfo.to_i, iSilenceThresholdInfo.to_i ]
            else
              lSilenceThresholds << iSilenceThresholdInfo.split(',').map { |iStrValue| iStrValue.to_i }
            end
          end
        end
        lAttackDuration = readDuration(@Attack, iInputData.Header.SampleRate)
        lReleaseDuration = readDuration(@Release, iInputData.Header.SampleRate)
        lSilenceDuration = readDuration(@SilenceMin, iInputData.Header.SampleRate)
        # Create a map of the non silent parts
        # list< [ Integer,                 Integer ] >
        # list< [ IdxBeginNonSilentSample, IdxEndNonSilentSample ] >
        lNonSilentParts = []
        # Current non silent begin sample (nil means we are parsing a silent part)
        # Integer
        lCurrentPart = nil
        # First silent sample of the current silent part
        # Integer
        lFirstSilentSample = nil
        lIdxSample = 0
        iInputData.eachBuffer do |iInputBuffer, iNbrSamples, iNbrChannels|
          lIdxBuffer = 0
          iNbrSamples.times do |iIdxBufferSample|
            lSilent = true
            iNbrChannels.times do |iIdxChannel|
              if ((iInputBuffer[lIdxBuffer] < lSilenceThresholds[iIdxChannel][0]) or
                  (iInputBuffer[lIdxBuffer] > lSilenceThresholds[iIdxChannel][1]))
                # This sample is not silent
                lSilent = false
                # Don't break, as we need to increase lIdxBuffer still
              end
              lIdxBuffer += 1
            end
            if (lSilent)
              # Silent
              if (lCurrentPart != nil)
                # We MAY be leaving a non-silent area if it lasts for at least lSilenceDuration samples silent
                if (lFirstSilentSample == nil)
                  # This is the first silent sample we have. Begin monitoring this silent part.
                  lFirstSilentSample = lIdxSample
                end
                # If current silent is greater than the silence duration, we close the previously non-silent part
                if ((lIdxSample - lFirstSilentSample + 1) >= lSilenceDuration)
                  lNonSilentParts << [ lCurrentPart, lFirstSilentSample - 1 ]
                  # We are definitely in a silent zone
                  lCurrentPart = nil
                  # Stop monitoring the silence
                  lFirstSilentSample = nil
                end
              end
            else
              # Not silent
              if (lCurrentPart == nil)
                # We enter a non silent area
                lCurrentPart = lIdxSample
              else
                # In the case we were monitoring a little silent sample, don't consider it anymore.
                lFirstSilentSample = nil
              end
            end
            lIdxSample += 1
          end
        end
        if (lCurrentPart != nil)
          # Close the last non-silent part
          if (lFirstSilentSample == nil)
            # The file ends with audio data
            lNonSilentParts << [ lCurrentPart, iInputData.NbrSamples-1 ]
          else
            # The file ends with a silence we were still monitoring (smaller than lSilenceMin)
            lNonSilentParts << [ lCurrentPart, lFirstSilentSample - 1 ]
          end
        end
        # Modify values according to FFT comparisons
        if (File.exists?(@NoiseFFTFileName))
          # Load the reference FFT profile
          lNoiseFFTProfile = nil
          File.open(@NoiseFFTFileName, 'rb') do |iFile|
            lNoiseFFTProfile = Marshal.load(iFile.read)
          end
          # Correct sample indexes
          lNonSilentParts.each_with_index do |ioNonSilentPartInfo, iIdx|
            iIdxBeginSample, iIdxEndSample = ioNonSilentPartInfo
            if (iIdx > 0)
              # Correct the beginning sample
              lPreviousEndSample = lNonSilentParts[iIdx-1][1]
              ioNonSilentPartInfo[0] = getPreviousFFTSample(iIdxBeginSample-1, lNoiseFFTProfile, iInputData, lPreviousEndSample+1) + 1
              if (ioNonSilentPartInfo[0] < iIdxBeginSample)
                logDebug "Moved back non-silent beginning sample from #{iIdxBeginSample} to #{ioNonSilentPartInfo[0]}"
              end
            end
            # Correct the ending sample
            lNextBeginSample = nil
            if (iIdx < lNonSilentParts.size - 1)
              lNextBeginSample = lNonSilentParts[iIdx+1][0]
            else
              lNextBeginSample = iInputData.NbrSamples
            end
            ioNonSilentPartInfo[1] = getNextFFTSample(iIdxEndSample+1, lNoiseFFTProfile, iInputData, lNextBeginSample-1) - 1
            if (ioNonSilentPartInfo[1] > iIdxEndSample)
              logDebug "Moved non-silent ending sample from #{iIdxEndSample} to #{ioNonSilentPartInfo[1]}"
            end
          end
          # Merge eventually contiguous parts
          lRealNonSilentParts = []
          lIdxBegin = lNonSilentParts[0][0]
          lNonSilentParts.each_with_index do |ioNonSilentPartInfo, iIdx|
            iIdxBeginSample, iIdxEndSample = ioNonSilentPartInfo
            if (iIdx < lNonSilentParts.size-1)
              if (lNonSilentParts[iIdx+1][0] - iIdxEndSample > lSilenceDuration + 1)
                # Not contiguous
                lRealNonSilentParts << [lIdxBegin, iIdxEndSample]
                lIdxBegin = lNonSilentParts[iIdx+1][0]
              end
            else
              # Last part
              lRealNonSilentParts << [lIdxBegin, iIdxEndSample]
            end
          end
          lNonSilentParts = lRealNonSilentParts
        else
          logErr "Missing file #{@NoiseFFTFileName}"
        end
        lStrNonSilentParts = lNonSilentParts.map { |iNonSilentInfo| "[#{iNonSilentInfo[0]/iInputData.Header.SampleRate}s - #{iNonSilentInfo[1]/iInputData.Header.SampleRate}s]" }
        logInfo "#{lNonSilentParts.size} non silent parts: #{lStrNonSilentParts[0..9].join(', ')}"
        lStrDbgNonSilentParts = lNonSilentParts.map { |iNonSilentInfo| "[#{iNonSilentInfo[0]} - #{iNonSilentInfo[1]}]" }
        logDebug "#{lNonSilentParts.size} non silent parts: #{lStrDbgNonSilentParts[0..9].join(', ')}"
        # Now we write the non-silent parts, spaced with nulled parts, with fadeins and fadeouts around.
        lNextSampleToWrite = 0
        lNonSilentParts.each do |iNonSilentInfo|
          iIdxBegin, iIdxEnd = iNonSilentInfo
          # Compute the fadein buffer
          lIdxBeginFadeIn = iIdxBegin - lAttackDuration
          if (lIdxBeginFadeIn < 0)
            lIdxBeginFadeIn = 0
          end
          # Write a blank buffer if needed
          if (lIdxBeginFadeIn > lNextSampleToWrite)
            logDebug "Write #{lIdxBeginFadeIn - lNextSampleToWrite} samples of silence"
            oOutputData.pushRawBuffer("\000" * (((lIdxBeginFadeIn - lNextSampleToWrite)*iInputData.Header.NbrChannels*iInputData.Header.NbrBitsPerSample)/8))
          end
          lBuffer = []
          lIdxFadeSample = 0
          lFadeInSize = iIdxBegin-lIdxBeginFadeIn
          iInputData.each(lIdxBeginFadeIn) do |iChannelValues|
            if (lIdxFadeSample == lFadeInSize)
              break
            end
            lBuffer.concat(iChannelValues.map { |iValue| (iValue*lIdxFadeSample)/lFadeInSize })
            lIdxFadeSample += 1
          end
          logDebug "Write #{lBuffer.size/iInputData.Header.NbrChannels} samples of fadein."
          oOutputData.pushBuffer(lBuffer)
          # Write the file
          logDebug "Write #{iIdxEnd-iIdxBegin+1} samples of audio."
          iInputData.eachRawBuffer(iIdxBegin, iIdxEnd) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
            oOutputData.pushRawBuffer(iInputRawBuffer)
          end
          # Write the fadeout buffer
          lIdxEndFadeOut = iIdxEnd + lReleaseDuration
          if (lIdxEndFadeOut >= iInputData.NbrSamples)
            lIdxEndFadeOut = iInputData.NbrSamples - 1
          end
          lBuffer = []
          lIdxFadeSample = 0
          lFadeOutSize = lIdxEndFadeOut-iIdxEnd
          iInputData.each(iIdxEnd+1) do |iChannelValues|
            if (lIdxFadeSample == lFadeOutSize)
              break
            end
            lBuffer.concat(iChannelValues.map { |iValue| (iValue*(lFadeOutSize-lIdxFadeSample))/lFadeOutSize })
            lIdxFadeSample += 1
          end
          logDebug "Write #{lBuffer.size/iInputData.Header.NbrChannels} samples of fadeout."
          oOutputData.pushBuffer(lBuffer)
          lNextSampleToWrite = lIdxEndFadeOut + 1
        end
        # If there is remaining silence, write it
        if (lNextSampleToWrite < iInputData.NbrSamples)
          logDebug "Write #{iInputData.NbrSamples - lNextSampleToWrite} samples of last silence"
          oOutputData.pushRawBuffer("\000" * (((iInputData.NbrSamples - lNextSampleToWrite)*iInputData.Header.NbrChannels*iInputData.Header.NbrBitsPerSample)/8))
        end

        return nil
      end

    end

  end

end
