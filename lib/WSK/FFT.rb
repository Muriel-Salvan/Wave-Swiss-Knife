#--
# Copyright (c) 2009 - 2011 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  # Module including helper methods using FFT processes.
  # This module uses C methods declared in FFTUtils.
  module FFT

    # Frequencies used to compute FFT profiles.
    # !!! When changing these values, all fft.result files generated are invalidated
    FREQINDEX_FIRST = -59
    FREQINDEX_LAST = 79

    # Scale used to measure FFT values
    FFTDIST_MAX = 10000000000000

    # Frequency of the FFT samples to take (Hz)
    # !!! If changed, all fft.result files generated are invalidated
    FFTSAMPLE_FREQ = 10
    # Number of FFT buffers needed to detect a constant Moving Average.
    # !!! If changed, all fft.result files generated are invalidated
    FFTNBRSAMPLES_HISTORY = 5
    # Number of samples to prefetch from the disk when reading.
    # This should reflect the average number of FFT samples read when getNextFFTSample is invoked once.
    # !!! If changed, all fft.result files generated are invalidated
    FFT_SAMPLES_PREFETCH = 30
    # Added tolerance percentage of distance between the maximal history distance and the average silence distance
    FFTDISTANCE_MAX_HISTORY_TOLERANCE_PC = 20.0
    # Added tolerance percentage of distance between the average history distance and the average silence distance
    FFTDISTANCE_AVERAGE_HISTORY_TOLERANCE_PC = 0.0

    class FFTComputing

      # Constructor
      # The trigo cache is VERY useful when several FFT of the same length are computed.
      #
      # Parameters:
      # * *iUseTrigoCache* (_Boolean_): Do we use the trigonometric cache ?
      # * *iHeader* (<em>WSK::Model::Header</em>): Header of the data we will perform FFT on.
      def initialize(iUseTrigoCache, iHeader)
        @UseTrigoCache, @Header = iUseTrigoCache, iHeader
        require 'WSK/FFTUtils/FFTUtils'
        @FFTUtils = FFTUtils::FFTUtils.new
        # Initialize FFT utils objects
        @W = @FFTUtils.createWi(FREQINDEX_FIRST, FREQINDEX_LAST, @Header.SampleRate)
        @NbrFreq = FREQINDEX_LAST - FREQINDEX_FIRST + 1
        if (@UseTrigoCache)
          # Initialize the cache of trigonometric values if not done already
          if ((defined?(@@TrigoCacheSampleRate) == nil) or
              (@@TrigoCacheSampleRate != @Header.SampleRate))
            @@TrigoCacheSampleRate = @Header.SampleRate
            @@TrigoCache = @FFTUtils.initTrigoCache(@W, @NbrFreq, @Header.SampleRate/FFTSAMPLE_FREQ)
          end
        end
        # Initialize the cos and sin arrays
        resetData
      end

      # Reset the cos and sin arrays
      def resetData
        @SumCos = @FFTUtils.initSumArray(@NbrFreq, @Header.NbrChannels)
        @SumSin = @FFTUtils.initSumArray(@NbrFreq, @Header.NbrChannels)
        @NbrSamples = 0
      end

      # Add FFT coefficients based on a buffer
      #
      # Parameters:
      # * *iRawBuffer* (_String_): The raw buffer
      # * *iNbrSamples* (_Integer_): Number of samples to take from this buffer to compute the FFT
      def completeFFT(iRawBuffer, iNbrSamples)
        if (@UseTrigoCache)
          @FFTUtils.completeSumCosSin(iRawBuffer, @NbrSamples, @Header.NbrBitsPerSample, iNbrSamples, @Header.NbrChannels, @NbrFreq, nil, @@TrigoCache, @SumCos, @SumSin)
        else
          @FFTUtils.completeSumCosSin(iRawBuffer, @NbrSamples, @Header.NbrBitsPerSample, iNbrSamples, @Header.NbrChannels, @NbrFreq, @W, nil, @SumCos, @SumSin)
        end
        @NbrSamples += iNbrSamples
      end

      # Get the resulting FFT profile
      #
      # Return:
      # * <em>[Integer,Integer,list<list<Integer>></em>]: Number of bits per sample, number of samples, list of FFT coefficients, per frequency, per channel
      def getFFTProfile
        return [@Header.NbrBitsPerSample, @NbrSamples, @FFTUtils.computeFFT(@Header.NbrChannels, @NbrFreq, @SumCos, @SumSin)]
      end

    end

    # To be used if GMP library is absent.
#    # Compare 2 FFT profiles and measure their distance.
#    # Here is an FFT profile structure:
#    # [ Integer,          Integer,    list<list<Integer>> ]
#    # [ NbrBitsPerSample, NbrSamples, FFTValues ]
#    # FFTValues are declined per channel, per frequency index.
#    # Bits per sample and number of samples are taken into account to relatively compare the profiles.
#    #
#    # Parameters:
#    # * *iProfile1* (<em>[Integer,Integer,list<list<Integer>>]</em>): Profile 1
#    # * *iProfile2* (<em>[Integer,Integer,list<list<Integer>>]</em>): Profile 2
#    # Return:
#    # * _Integer_: Distance (Profile 2 - Profile 1). The scale is given by FFTDIST_MAX.
#    def distFFTProfiles(iProfile1, iProfile2)
#      # Return the max of the distances of each frequency coefficient
#      rMaxDist = 0.0
#
#      iNbrBitsPerSample1, iNbrSamples1, iFFT1 = iProfile1
#      iNbrBitsPerSample2, iNbrSamples2, iFFT2 = iProfile2
#
#      # Each value is limited by the maximum value of 2*(NbrSamples*MaxAbsValue)^2
#      lMaxFFTValue1 = Float(2*((iNbrSamples1*(2**(iNbrBitsPerSample1-1)))**2))
#      lMaxFFTValue2 = Float(2*((iNbrSamples2*(2**(iNbrBitsPerSample2-1)))**2))
#      iFFT1.each_with_index do |iFFT1ChannelValues, iIdxFreq|
#        iFFT2ChannelValues = iFFT2[iIdxFreq]
#        iFFT1ChannelValues.each_with_index do |iFFT1Value, iIdxChannel|
#          iFFT2Value = iFFT2ChannelValues[iIdxChannel]
#          # Compute iFFT2Value - iFFT1Value, on a scale of FFTDIST_MAX
#          lDist = iFFT2Value/lMaxFFTValue2 - iFFT1Value/lMaxFFTValue1
##          logDebug "[Freq #{iIdxFreq}] [Ch #{iIdxChannel}] - Distance = #{lDist}"
#          if (lDist > rMaxDist)
#            rMaxDist = lDist
#          end
#        end
#      end
#
#      return (rMaxDist*FFTDIST_MAX).to_i
#    end

    # Get the next sample that has an FFT buffer similar to a given FFT profile
    #
    # Parameters:
    # * *iIdxFirstSample* (_Integer_): First sample we are trying from
    # * *iFFTProfile* (<em>[Integer,Integer,list<list<Integer>>]</em>): The FFT profile
    # * *iInputData* (_InputData_): The input data to read
    # * *iMaxFFTDistance* (_Integer_): Maximal acceptable distance with the FFT. Above this distance we don't consider averaging.
    # * *iThresholds* (<em>list<[Integer,Integer]></em>): The thresholds that should contain the signal we are evaluating.
    # * *iBackwardsSearch* (_Boolean_): Do we search backwards ?
    # * *iIdxLastPossibleSample* (_Integer_): Index of the sample marking the limit of the search
    # Return:
    # * _Integer_: Meaning of the given sample:
    # ** *0*: The sample has been found correctly and returned
    # ** *1*: The sample could not be found because thresholds were hit: the first sample hitting the thresholds is returned
    # ** *2*: The sample could not be found because the limit of search was hit before. The returned sample can be ignored.
    # * _Integer_: Index of the sample (can be 1 after the end)
    def getNextFFTSample(iIdxFirstSample, iFFTProfile, iInputData, iMaxFFTDistance, iThresholds, iBackwardsSearch, iIdxLastPossibleSample)
      rResultCode = 0
      rCurrentSample = iIdxFirstSample

      if (iBackwardsSearch)
        logDebug "== Looking for the previous sample matching FFT before #{iIdxFirstSample}, with a limit on sample #{iIdxLastPossibleSample} and a FFT distance of #{iMaxFFTDistance} ..."
      else
        logDebug "== Looking for the next sample matching FFT after #{iIdxFirstSample}, with a limit on sample #{iIdxLastPossibleSample} and a FFT distance of #{iMaxFFTDistance} ..."
      end

      # Object that will create the FFT
      lFFTComputing = FFTComputing.new(true, iInputData.Header)
      # Create the C FFT Profile
      lFFTUtils = FFTUtils::FFTUtils.new
      lReferenceFFTProfile = lFFTUtils.createCFFTProfile(iFFTProfile)
      # Historical values of FFT diffs to know when it is stable
      # This is the implementation of the Moving Average algorithm.
      # We are just interested in the difference of 2 different Moving Averages. Therefore comparing the oldest history value with the new one is enough.
      # Cycling buffer of size FFTNBRSAMPLES_HISTORY
      # list< Integer >
      lHistory = []
      lIdxOldestHistory = 0
      # The sum of all the history entries: used to compare with the maximal average distance
      lSumHistory = 0
      lSumMaxFFTDistance = (iMaxFFTDistance*FFTNBRSAMPLES_HISTORY*(1+FFTDISTANCE_AVERAGE_HISTORY_TOLERANCE_PC/100)).to_i
      lMaxHistoryFFTDistance = (iMaxFFTDistance*(1+FFTDISTANCE_MAX_HISTORY_TOLERANCE_PC/100)).to_i
      lContinueSearching = nil
      if (iBackwardsSearch)
        lContinueSearching = (rCurrentSample >= iIdxLastPossibleSample)
      else
        lContinueSearching = (rCurrentSample <= iIdxLastPossibleSample)
      end
      while (lContinueSearching)
        # Compute the number of samples needed to have a valid FFT.
        # Modify this number if it exceeds the range we have
        lNbrSamplesFFTMax = iInputData.Header.SampleRate/FFTSAMPLE_FREQ
        lIdxBeginFFTSample = nil
        lIdxEndFFTSample = nil
        if (iBackwardsSearch)
          lIdxBeginFFTSample = rCurrentSample-lNbrSamplesFFTMax+1
          lIdxEndFFTSample = rCurrentSample
          if (lIdxBeginFFTSample <= iIdxLastPossibleSample-1)
            lIdxBeginFFTSample = iIdxLastPossibleSample
          end
        else
          lIdxBeginFFTSample = rCurrentSample
          lIdxEndFFTSample = rCurrentSample+lNbrSamplesFFTMax-1
          if (lIdxEndFFTSample >= iIdxLastPossibleSample+1)
            lIdxEndFFTSample = iIdxLastPossibleSample
          end
        end
        lNbrSamplesFFT = lIdxEndFFTSample-lIdxBeginFFTSample+1
        # Load an FFT buffer of this
        lFFTBuffer = ''
        lIdxCurrentSample = rCurrentSample
        if (iBackwardsSearch)
          iInputData.eachReverseRawBuffer(lIdxBeginFFTSample, lIdxEndFFTSample, :NbrSamplesPrefetch => lNbrSamplesFFTMax*FFT_SAMPLES_PREFETCH ) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
            # First, check that we are still in the thresholds
            lIdxBufferSampleOut = getSampleBeyondThresholds(iInputRawBuffer, iThresholds, iInputData.Header.NbrBitsPerSample, iNbrChannels, iNbrSamples, iBackwardsSearch)
            if (lIdxBufferSampleOut != nil)
              # Cancel this FFT search: the signal is out of the thresholds
              rCurrentSample = lIdxCurrentSample-iNbrSamples+1+lIdxBufferSampleOut
              rResultCode = 1
              break
            end
            lFFTBuffer.insert(0, iInputRawBuffer)
            lIdxCurrentSample -= iNbrSamples
          end
        else
          iInputData.eachRawBuffer(lIdxBeginFFTSample, lIdxEndFFTSample, :NbrSamplesPrefetch => lNbrSamplesFFTMax*FFT_SAMPLES_PREFETCH) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
            # First, check that we are still in the thresholds
            lIdxBufferSampleOut = getSampleBeyondThresholds(iInputRawBuffer, iThresholds, iInputData.Header.NbrBitsPerSample, iNbrChannels, iNbrSamples, iBackwardsSearch)
            if (lIdxBufferSampleOut != nil)
              # Cancel this FFT search: the signal is out of the thresholds
              rCurrentSample = lIdxCurrentSample+lIdxBufferSampleOut
              rResultCode = 1
              break
            end
            lFFTBuffer.concat(iInputRawBuffer)
            lIdxCurrentSample += iNbrSamples
          end
        end
        if (rResultCode == 1)
          lContinueSearching = false
        else
          # Compute its FFT profile
          lFFTComputing.resetData
          lFFTComputing.completeFFT(lFFTBuffer, lNbrSamplesFFT)
          lDist = lFFTUtils.distFFTProfiles(lReferenceFFTProfile, lFFTUtils.createCFFTProfile(lFFTComputing.getFFTProfile), FFTDIST_MAX).abs
          lHistoryMaxDistance = lHistory.sort[-1]
          logDebug "FFT distance computed with FFT sample [#{lIdxBeginFFTSample} - #{lIdxEndFFTSample}]: #{lDist}. Sum of history: #{lSumHistory} <? #{lSumMaxFFTDistance}. Max distance of history: #{lHistoryMaxDistance} <? #{lMaxHistoryFFTDistance}"
          # Detect if the Moving Average is going up and is below the maximal distance
          if ((lHistory.size == FFTNBRSAMPLES_HISTORY) and
              (lSumHistory < lSumMaxFFTDistance) and
              (lHistoryMaxDistance < lMaxHistoryFFTDistance) and
              (lHistory[lIdxOldestHistory] < lDist))
            # We got it
            lContinueSearching = false
          else
            # Check next FFT sample
            if (iBackwardsSearch)
              rCurrentSample = lIdxBeginFFTSample - 1
              lContinueSearching = (rCurrentSample >= iIdxLastPossibleSample)
            else
              rCurrentSample = lIdxEndFFTSample + 1
              lContinueSearching = (rCurrentSample <= iIdxLastPossibleSample)
            end
            if (lContinueSearching)
              # Update the history with the new diff
              if (lHistory[lIdxOldestHistory] == nil)
                lSumHistory += lDist
              else
                lSumHistory += lDist - lHistory[lIdxOldestHistory]
              end
              lHistory[lIdxOldestHistory] = lDist
              lIdxOldestHistory += 1
              if (lIdxOldestHistory == FFTNBRSAMPLES_HISTORY)
                lIdxOldestHistory = 0
              end
            end
          end
        end
      end
      if ((rResultCode == 0) and
          (((iBackwardsSearch) and
            (rCurrentSample == iIdxLastPossibleSample-1)) or
           ((!iBackwardsSearch) and
            (rCurrentSample == iIdxLastPossibleSample+1))))
        # Limit was hit
        rResultCode = 2
      end

      case rResultCode
      when 0
        if (iBackwardsSearch)
          logDebug "== Previous sample matching FFT before #{iIdxFirstSample} was found at #{rCurrentSample}."
        else
          logDebug "== Next sample matching FFT after #{iIdxFirstSample} was found at #{rCurrentSample}."
        end
      when 1
        if (iBackwardsSearch)
          logDebug "== Previous sample matching FFT before #{iIdxFirstSample} could not be found because a sample exceeded thresholds meanwhile: #{rCurrentSample}."
        else
          logDebug "== Next sample matching FFT after #{iIdxFirstSample} could not be found because a sample exceeded thresholds meanwhile: #{rCurrentSample}."
        end
      when 2
        if (iBackwardsSearch)
          logDebug "== Previous sample matching FFT before #{iIdxFirstSample} could not be found before hitting limit of #{iIdxLastPossibleSample}."
        else
          logDebug "== Next sample matching FFT after #{iIdxFirstSample} could not be found before hitting limit of #{iIdxLastPossibleSample}."
        end
      else
        logErr "Unknown result code: #{rResultCode}"
      end

      return rResultCode, rCurrentSample
    end

    # Get the next silent sample from an input data
    #
    # Parameters:
    # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
    # * *iIdxStartSample* (_Integer_): Index of the first sample to search from
    # * *iSilenceThresholds* (<em>list<[Integer,Integer]></em>): The silence thresholds specifications
    # * *iMinSilenceSamples* (_Integer_): Number of samples minimum to identify a silence
    # * *iSilenceFFTProfile* (<em>[Integer,Integer,list<list<Integer>>]</em>): The silence FFT profile, or nil if none
    # * *iMaxFFTDistance* (_Integer_): Max distance to consider with the FFT (ignored and can be nil if no FFT).
    # * *iBackwardsSearch* (_Boolean_): Do we make a backwards search ?
    # Return:
    # * _Integer_: Index of the next silent sample, or nil if none
    # * _Integer_: Silence length (computed only if FFT profile was provided)
    # * _Integer_: Index of the next sample after the silence that is beyond thresholds (computed only if FFT profile was provided)
    def getNextSilentSample(iInputData, iIdxStartSample, iSilenceThresholds, iMinSilenceSamples, iSilenceFFTProfile, iMaxFFTDistance, iBackwardsSearch)
      rNextSilentSample = nil
      rSilenceLength = nil
      rNextSignalAboveThresholds = nil

      if (iBackwardsSearch)
        logDebug "=== Looking for the previous silent sample before #{iIdxStartSample}, of minimal length #{iMinSilenceSamples} ..."
      else
        logDebug "=== Looking for the next silent sample after #{iIdxStartSample}, of minimal length #{iMinSilenceSamples} ..."
      end
      
      lIdxSearchSample = iIdxStartSample
      lContinueSearching = true
      while (lContinueSearching)
        # We search starting at lIdxSearchSample
        lContinueSearching = false
        # First find using thresholds only
        require 'WSK/SilentUtils/SilentUtils'
        rNextSilentSample = SilentUtils::SilentUtils.new.getNextSilentInThresholds(iInputData, lIdxSearchSample, iSilenceThresholds, iMinSilenceSamples, iBackwardsSearch)
        if (rNextSilentSample == nil)
          logDebug("Thresholds matching did not find any silence starting at sample #{iIdxStartSample}.")
        else
          logDebug("Thresholds matching found a silence starting at sample #{iIdxStartSample}, beginning at sample #{rNextSilentSample}.")
          # If we want to use FFT to have a better result, do it here
          if (iSilenceFFTProfile != nil)
            # Check FFT
            if (iBackwardsSearch)
              lFFTResultCode, lIdxFFTSample = getNextFFTSample(rNextSilentSample, iSilenceFFTProfile, iInputData, iMaxFFTDistance, iSilenceThresholds, iBackwardsSearch, 0)
            else
              lFFTResultCode, lIdxFFTSample = getNextFFTSample(rNextSilentSample, iSilenceFFTProfile, iInputData, iMaxFFTDistance, iSilenceThresholds, iBackwardsSearch, iInputData.NbrSamples-1)
            end
            case lFFTResultCode
            when 0
              # Check that the silence lasts at least iMinSilenceSamples
              lIdxNextSignal = nil
              lIdxNextSignalAboveThresholds = nil
              lSilenceLength = nil
              if (iBackwardsSearch)
                lIdxNextSignal, lIdxNextSignalAboveThresholds = getNextNonSilentSample(iInputData, lIdxFFTSample-1, iSilenceThresholds, iSilenceFFTProfile, iMaxFFTDistance, iBackwardsSearch)
                if (lIdxNextSignal == nil)
                  # No signal was found further.
                  lSilenceLength = lIdxFFTSample
                else
                  lSilenceLength = lIdxFFTSample - lIdxNextSignal - 1
                end
              else
                lIdxNextSignal, lIdxNextSignalAboveThresholds = getNextNonSilentSample(iInputData, lIdxFFTSample+1, iSilenceThresholds, iSilenceFFTProfile, iMaxFFTDistance, iBackwardsSearch)
                if (lIdxNextSignal == nil)
                  # No signal was found further.
                  lSilenceLength = iInputData.NbrSamples - 1 - lIdxFFTSample
                else
                  lSilenceLength = lIdxNextSignal - 1 - lIdxFFTSample
                end
              end
              if (lSilenceLength >= iMinSilenceSamples)
                # We found the real one
                logDebug("FFT matching found a silence starting at sample #{rNextSilentSample}, beginning at sample #{lIdxFFTSample}.")
                rNextSilentSample = lIdxFFTSample
                rSilenceLength = lSilenceLength
                rNextSignalAboveThresholds = lIdxNextSignalAboveThresholds
              elsif (lIdxNextSignal == nil)
                # We arrived at the end. The silence is not long enough.
                logDebug("FFT matching found a silence starting at sample #{rNextSilentSample}, beginning at sample #{lIdxFFTSample}, but its length (#{lSilenceLength}) is too small (minimum required is #{iMinSilenceSamples}). End of file reached.")
                rNextSilentSample = nil
              else
                # We have to continue
                logDebug("FFT matching found a silence starting at sample #{rNextSilentSample}, beginning at sample #{lIdxFFTSample}, but its length (#{lSilenceLength}) is too small (minimum required is #{iMinSilenceSamples}). Looking further.")
                lIdxSearchSample = lIdxNextSignalAboveThresholds
                lContinueSearching = true
                rNextSilentSample = nil
              end
            when 1
              # We have to search further, begin with thresholds matching
              logWarn("FFT matching found a new signal beyond thresholds starting at sample #{rNextSilentSample}, beginning at sample #{lIdxFFTSample}. Maybe clip ?")
              if (iBackwardsSearch)
                lIdxSearchSample = lIdxFFTSample - 1
              else
                lIdxSearchSample = lIdxFFTSample + 1
              end
              lContinueSearching = true
              rNextSilentSample = nil
            when 2
              logDebug("FFT matching could not find a silence starting at sample #{rNextSilentSample}.")
              rNextSilentSample = nil
            else
              raise RuntimeError.new("Unknown result code: #{lFFTResultCode}")
            end
          end
        end
      end

      if (iBackwardsSearch)
        logDebug "=== Previous silent sample before #{iIdxStartSample} was found at #{rNextSilentSample} with a length of #{rSilenceLength}, and a signal before it above thresholds at #{rNextSignalAboveThresholds}."
      else
        logDebug "=== Next silent sample after #{iIdxStartSample} was found at #{rNextSilentSample} with a length of #{rSilenceLength}, and an signal after it above thresholds at #{rNextSignalAboveThresholds}."
      end

      return rNextSilentSample, rSilenceLength, rNextSignalAboveThresholds
    end

    # Get the next non silent sample from an input data
    #
    # Parameters:
    # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
    # * *iIdxStartSample* (_Integer_): Index of the first sample to search from
    # * *iSilenceThresholds* (<em>list<[Integer,Integer]></em>): The silence thresholds specifications
    # * *iSilenceFFTProfile* (<em>[Integer,Integer,list<list<Integer>>]</em>): The silence FFT profile, or nil if none
    # * *iMaxFFTDistance* (_Integer_): Max distance to consider with the FFT (ignored and can be nil if no FFT).
    # * *iBackwardsSearch* (_Boolean_): Do we search backwards ?
    # Return:
    # * _Integer_: Index of the next non silent sample, or nil if none
    # * _Integer_: Index of the next sample getting above thresholds, or nil if none
    def getNextNonSilentSample(iInputData, iIdxStartSample, iSilenceThresholds, iSilenceFFTProfile, iMaxFFTDistance, iBackwardsSearch)
      rIdxSampleOut = nil
      rIdxSampleOutThresholds = nil
      
      if (iBackwardsSearch)
        logDebug "=== Looking for the previous signal sample before #{iIdxStartSample} ..."
      else
        logDebug "=== Looking for the next signal sample after #{iIdxStartSample} ..."
      end

      # Find the next sample getting out of the silence thresholds
      lIdxCurrentSample = iIdxStartSample
      if (iBackwardsSearch)
        iInputData.eachReverseRawBuffer(0, iIdxStartSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          lIdxBufferSampleOut = getSampleBeyondThresholds(iInputRawBuffer, iSilenceThresholds, iInputData.Header.NbrBitsPerSample, iNbrChannels, iNbrSamples, iBackwardsSearch)
          if (lIdxBufferSampleOut != nil)
            # We found it
            rIdxSampleOutThresholds = lIdxCurrentSample-iNbrSamples+1+lIdxBufferSampleOut
            break
          end
          lIdxCurrentSample -= iNbrSamples
        end
      else
        iInputData.eachRawBuffer(iIdxStartSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          lIdxBufferSampleOut = getSampleBeyondThresholds(iInputRawBuffer, iSilenceThresholds, iInputData.Header.NbrBitsPerSample, iNbrChannels, iNbrSamples, iBackwardsSearch)
          if (lIdxBufferSampleOut != nil)
            # We found it
            rIdxSampleOutThresholds = lIdxCurrentSample+lIdxBufferSampleOut
            break
          end
          lIdxCurrentSample += iNbrSamples
        end
      end
      if (rIdxSampleOutThresholds == nil)
        logDebug("Thresholds matching did not find any signal starting at sample #{iIdxStartSample}.")
      else
        logDebug("Thresholds matching found a signal starting at sample #{iIdxStartSample}, beginning at sample #{rIdxSampleOutThresholds}.")
        # If we want to use FFT to have a better result, do it here
        if (iSilenceFFTProfile == nil)
          rIdxSampleOut = rIdxSampleOutThresholds
        else
          # Check FFT
          # We search in the reverse direction to find the silence, knowing that we can't have a sample getting past our initial search sample
          lFFTResultCode = nil
          lIdxFFTSample = nil
          if (iBackwardsSearch)
            lFFTResultCode, lIdxFFTSample = getNextFFTSample(rIdxSampleOutThresholds+1, iSilenceFFTProfile, iInputData, iMaxFFTDistance, iSilenceThresholds, false, iIdxStartSample)
          else
            lFFTResultCode, lIdxFFTSample = getNextFFTSample(rIdxSampleOutThresholds-1, iSilenceFFTProfile, iInputData, iMaxFFTDistance, iSilenceThresholds, true, iIdxStartSample)
          end
          case lFFTResultCode
          when 0
            # We found the real one
            logDebug("FFT matching found a silence starting at sample #{rIdxSampleOutThresholds}, beginning at sample #{lIdxFFTSample}.")
            rIdxSampleOut = lIdxFFTSample
          when 1
            # Here is a bug
            logErr("FFT matching found a new signal beyond thresholds starting at sample #{rIdxSampleOutThresholds}, beginning at sample #{lIdxFFTSample}. This should never happen here: the previous search using thresholds should have already returned this sample.")
            raise RuntimeError.new("FFT matching found a new signal beyond thresholds starting at sample #{rIdxSampleOutThresholds}, beginning at sample #{lIdxFFTSample}. This should never happen here: the previous search using thresholds should have already returned this sample.")
          when 2
            logDebug("FFT matching could not find a silence starting at sample #{rIdxSampleOutThresholds}. This means that the signal is present from the start.")
            rIdxSampleOut = iIdxStartSample
          else
            raise RuntimeError.new("Unknown result code: #{lFFTResultCode}")
          end
        end
      end

      if (iBackwardsSearch)
        logDebug "=== Previous signal sample before #{iIdxStartSample} was found at #{rIdxSampleOut}, with a sample beyond thresholds at #{rIdxSampleOutThresholds}."
      else
        logDebug "=== Next signal sample after #{iIdxStartSample} was found at #{rIdxSampleOut}, with a sample beyond thresholds at #{rIdxSampleOutThresholds}."
      end

      return rIdxSampleOut, rIdxSampleOutThresholds
    end

    # Get the sample index that exceeds a threshold in a raw buffer.
    #
    # Parameters:
    # * *iRawBuffer* (_String_): The raw buffer
    # * *iThresholds* (<em>list<[Integer,Integer]></em>): The thresholds
    # * *iNbrBitsPerSample* (_Integer_): Number of bits per sample
    # * *iNbrChannels* (_Integer_): Number of channels
    # * *iNbrSamples* (_Integer_): Number of samples
    # * *iLastSample* (_Boolean_): Are we looking for the last sample ?
    # Return:
    # * _Integer_: Index of the first sample exceeding thresholds, or nil if none
    def getSampleBeyondThresholds(iRawBuffer, iThresholds, iNbrBitsPerSample, iNbrChannels, iNbrSamples, iLastSample)
      require 'WSK/SilentUtils/SilentUtils'
      return SilentUtils::SilentUtils.new.getSampleBeyondThresholds(iRawBuffer, iThresholds, iNbrBitsPerSample, iNbrChannels, iNbrSamples, iLastSample)
    end

  end

end