# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class Compare

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
        rNbrSamples = iInputData.NbrSamples

        # Get the second input file
        lError = accessInputWaveFile(@InputFileName2) do |iInputHeader2, iInputData2|
          rSubError = nil
          # First check that headers are the same
          if (iInputHeader2 != iInputData.Header)
            rSubError = RuntimeError.new("Mismatch headers: First input file: #{iInputData.Header.inspect} Second input file: #{iInputHeader2.inspect}")
          end
          # Then we will return the maximal samples
          if (iInputData2.NbrSamples > iInputData.NbrSamples)
            logWarn "Second file has more samples (#{iInputData2.NbrSamples} > #{iInputData.NbrSamples})."
            rNbrSamples = iInputData2.NbrSamples
          elsif (iInputData2.NbrSamples < iInputData.NbrSamples)
            logWarn "Second file has less samples (#{iInputData2.NbrSamples} < #{iInputData.NbrSamples})."
          else
            logInfo 'Files have the same number of samples.'
          end
          next rSubError
        end
        if (lError != nil)
          raise lError
        end

        return rNbrSamples
      end

      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        if (@GenMap == 1)
          # We want to generate the map
          @DistortionMap = [nil]*(2**(iInputData.Header.NbrBitsPerSample))
        else
          @DistortionMap = nil
        end
        # Measure the cumulative errors
        @CumulativeErrors = 0
        @MaxValue = 2**(iInputData.Header.NbrBitsPerSample-1)-1
        @MinValue = -2**(iInputData.Header.NbrBitsPerSample-1)
        # Get the second input file
        rError = accessInputWaveFile(@InputFileName2) do |iInputHeader2, iInputData2|
          # Loop on both files.
          # !!! We count on the same buffer size for both files.
          # Initialize buffers
          lNbrSamplesProcessed = 0
          iInputData.getSampleData(0)
          iInputData2.getSampleData(0)
          lBuffer1, lNbrSamples1, lNbrChannels = iInputData.getCurrentBuffer
          lBuffer2, lNbrSamples2, lNbrChannels = iInputData2.getCurrentBuffer
          while ((lBuffer1 != nil) or
                 (lBuffer2 != nil))
            # Compute the differing buffer
            lDiffBuffer = nil
            if (lBuffer2 == nil)
              # Just write the first file
              lDiffBuffer = lBuffer1.map do |iValue|
                next processDiff(iValue, 0)
              end
              lNbrSamplesProcessed += lNbrSamples1
            elsif (lBuffer1 == nil)
              # Just write the second file, opposite
              lDiffBuffer = lBuffer2.map do |iValue|
                next processDiff(0, iValue)
              end
              lNbrSamplesProcessed += lNbrSamples2
            elsif (lNbrSamples1 == lNbrSamples2)
              lDiffBuffer = []
              lBuffer1.each_with_index do |iValue, iIdx|
                lDiffBuffer << processDiff(iValue, lBuffer2[iIdx])
              end
              lNbrSamplesProcessed += lNbrSamples1
            elsif (lNbrSamples1 < lNbrSamples2)
              # Up to lNbrSamples1, write the difference
              lDiffBuffer = []
              lBuffer1.each_with_index do |iValue, iIdx|
                lDiffBuffer << processDiff(iValue, lBuffer2[iIdx])
              end
              # Then write input2 opposite
              lDiffBuffer += lBuffer2[lBuffer1.size..-1].map do |iValue|
                next processDiff(0, iValue)
              end
              lNbrSamplesProcessed += lNbrSamples2
            else
              # Up to lNbrSamples2, write the difference
              lDiffBuffer = []
              lBuffer2.each_with_index do |iValue, iIdx|
                lDiffBuffer << processDiff(lBuffer1[iIdx], iValue)
              end
              # Then write input1
              lDiffBuffer += lBuffer1[lBuffer2.size..-1].map do |iValue|
                next processDiff(iValue, 0)
              end
              lNbrSamplesProcessed += lNbrSamples1
            end
            oOutputData.pushBuffer(lDiffBuffer)
            if (lNbrSamplesProcessed >= iInputData.NbrSamples)
              lBuffer1 = nil
            else
              # Read next Buffer1
              iInputData.getSampleData(lNbrSamplesProcessed)
              lBuffer1, lNbrSamples1, lNbrChannels = iInputData.getCurrentBuffer
            end
            if (lNbrSamplesProcessed >= iInputData2.NbrSamples)
              lBuffer2 = nil
            else
              # Read next Buffer2
              iInputData2.getSampleData(lNbrSamplesProcessed)
              lBuffer2, lNbrSamples2, lNbrChannels = iInputData2.getCurrentBuffer
            end
          end
        end
        if (@DistortionMap != nil)
          # Write the distortion map
          logInfo 'Generate distortion map in distortion.diffmap'
          File.open('distortion.diffmap', 'wb') do |oFile|
            oFile.write(Marshal.dump(@DistortionMap))
          end
          logInfo 'Generate invert map in invert.map'
          # We want to spot the values that are missing, and the duplicate values
          lInvertMap = [nil]*(2**(iInputData.Header.NbrBitsPerSample))
          (@MinValue .. @MaxValue).each do |iValue|
            if (@DistortionMap[iValue] == nil)
              logWarn "Value #{iValue} was not part of the input file"
            else
              lRecordedValue = iValue + @DistortionMap[iValue]
              if (lInvertMap[lRecordedValue] == nil)
                lInvertMap[lRecordedValue] = iValue
              else
                if (iValue.abs < lInvertMap[lRecordedValue].abs)
                  logWarn "Recorded value #{lRecordedValue} is used for both input values #{iValue} and #{lInvertMap[lRecordedValue]}. Setting it to #{iValue}."
                  lInvertMap[lRecordedValue] = iValue
                else
                  logWarn "Recorded value #{lRecordedValue} is used for both input values #{iValue} and #{lInvertMap[lRecordedValue]}. Keeping it to #{lInvertMap[lRecordedValue]}."
                end
              end
            end
          end
          (@MinValue .. @MaxValue).each do |iValue|
            if (lInvertMap[iValue] == nil)
              logWarn "Missing value that has never been recorded: #{iValue}"
            end
          end
          File.open('invert.map', 'wb') do |oFile|
            oFile.write(Marshal.dump(lInvertMap))
          end
        end
        lNormalizedErrors = @CumulativeErrors/@Coeff
        puts "Cumulative errors: #{lNormalizedErrors} (#{Float(lNormalizedErrors*100)/Float(iInputData.NbrSamples*(2**iInputData.Header.NbrBitsPerSample))} %)"

        return rError
      end

      private

      # Process a difference value, and return the difference to consider for real (in the bounds with the coefficient)
      #
      # Parameters:
      # * *iValue1* (_Integer_): The first value
      # * *iValue2* (_Integer_): The second value
      # Return:
      # * _Integer_: The value to consider
      def processDiff(iValue1, iValue2)
        rNewDiff = (iValue1-iValue2)*@Coeff

        if (rNewDiff > @MaxValue)
          logWarn "Exceeding maximal value: #{rNewDiff}, set to #{@MaxValue}"
          rNewDiff = @MaxValue
        elsif (rNewDiff < @MinValue)
          logWarn "Exceeding minimal value: #{rNewDiff}, set to #{@MinValue}"
          rNewDiff = @MinValue
        end
        if (rNewDiff != 0)
          @CumulativeErrors += rNewDiff.abs
        end
        if (@DistortionMap != nil)
          if (@DistortionMap[iValue2] == nil)
            @DistortionMap[iValue2] = rNewDiff
          elsif (@DistortionMap[iValue2] != rNewDiff)
            logWarn "Distortion for input value #{iValue2} was found both #{@DistortionMap[iValue2]} and #{rNewDiff}"
          end
        end

        return rNewDiff
      end

    end

  end

end