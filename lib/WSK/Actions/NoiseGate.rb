#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class NoiseGate

      include WSK::Common
      include WSK::FFT

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
        lSilenceThresholds = readThresholds(@SilenceThreshold, iInputData.Header.NbrChannels)
        lAttackDuration = readDuration(@Attack, iInputData.Header.SampleRate)
        lReleaseDuration = readDuration(@Release, iInputData.Header.SampleRate)
        lSilenceDuration = readDuration(@SilenceMin, iInputData.Header.SampleRate)
        lNoiseFFTMaxDistance, lNoiseFFTProfile = readFFTProfile(@NoiseFFTFileName)
        # Create a map of the non silent parts
        # list< [ Integer,                 Integer ] >
        # list< [ IdxBeginNonSilentSample, IdxEndNonSilentSample ] >
        lNonSilentParts = []
        lIdxSample = 0
        while (lIdxSample != nil)
          lIdxNextSilence, lSilenceLength, lIdxNextBeyondThresholds = getNextSilentSample(iInputData, lIdxSample, lSilenceThresholds, lSilenceDuration, lNoiseFFTProfile, lNoiseFFTMaxDistance, false)
          if (lIdxNextSilence == nil)
            lNonSilentParts << [lIdxSample, iInputData.NbrSamples-1]
          else
            lNonSilentParts << [lIdxSample, lIdxNextSilence-1]
          end
          lIdxSample = lIdxNextBeyondThresholds
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
          lFadeInSize = iIdxBegin-lIdxBeginFadeIn
          if (lFadeInSize > 0)
            lBuffer = []
            lIdxFadeSample = 0
            iInputData.each(lIdxBeginFadeIn) do |iChannelValues|
              if (lIdxFadeSample == lFadeInSize)
                break
              end
              lBuffer.concat(iChannelValues.map { |iValue| (iValue*lIdxFadeSample)/lFadeInSize })
              lIdxFadeSample += 1
            end
            logDebug "Write #{lBuffer.size/iInputData.Header.NbrChannels} samples of fadein."
            oOutputData.pushBuffer(lBuffer)
          else
            logDebug 'Ignore empty fadein.'
          end
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
          lFadeOutSize = lIdxEndFadeOut-iIdxEnd
          if (lFadeOutSize > 0)
            lBuffer = []
            lIdxFadeSample = 0
            iInputData.each(iIdxEnd+1) do |iChannelValues|
              if (lIdxFadeSample == lFadeOutSize)
                break
              end
              lBuffer.concat(iChannelValues.map { |iValue| (iValue*(lFadeOutSize-lIdxFadeSample))/lFadeOutSize })
              lIdxFadeSample += 1
            end
            logDebug "Write #{lBuffer.size/iInputData.Header.NbrChannels} samples of fadeout."
            oOutputData.pushBuffer(lBuffer)
          else
            logDebug 'Ignore empty fadeout.'
          end
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
