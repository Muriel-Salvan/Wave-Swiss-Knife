# To change this template, choose Tools | Templates
# and open the template in the editor.

module WSK

  module Actions

    class Compare

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
        @NbrBitsPerSample = iInputData.Header.NbrBitsPerSample
        @NbrChannels = iInputData.Header.NbrChannels
        if (@GenMap == 1)
          # We want to generate the map
          @DistortionMap = [nil]*(2**@NbrBitsPerSample)
        else
          @DistortionMap = nil
        end
        # Measure the cumulative errors
        @CumulativeErrors = 0
        @MaxValue = 2**(@NbrBitsPerSample-1)-1
        @MinValue = -2**(@NbrBitsPerSample-1)
        # Get the second input file
        rError = accessInputWaveFile(@InputFileName2) do |iInputHeader2, iInputData2|
          # Loop on both files.
          # !!! We count on the same buffer size for both files.
          require 'WSK/ArithmUtils/ArithmUtils'
          @ArithmUtils = WSK::ArithmUtils::ArithmUtils.new
          # Initialize buffers
          lNbrSamplesProcessed = 0
          iInputData.eachRawBuffer do |iRawBuffer, iNbrSamples, iNbrChannels|
            break
          end
          lRawBuffer1, lNbrSamples1, lNbrChannels = iInputData.getCurrentRawBuffer
          iInputData2.eachRawBuffer do |iRawBuffer, iNbrSamples, iNbrChannels|
            break
          end
          lRawBuffer2, lNbrSamples2, lNbrChannels = iInputData2.getCurrentRawBuffer
          while ((lRawBuffer1 != nil) or
                 (lRawBuffer2 != nil))
            if (lRawBuffer1 == nil)
              oOutputData.pushRawBuffer(lRawBuffer2)
              lNbrSamplesProcessed += lNbrSamples2
            elsif (lRawBuffer2 == nil)
              computeInverseMap
              oOutputData.pushRawBuffer(@ArithmUtils.applyMap(@InverseMap, lRawBuffer1, @NbrBitsPerSample, lNbrSamples1))
              lNbrSamplesProcessed += lNbrSamples1
            elsif (lNbrSamples1 == lNbrSamples2)
              lOutputBuffer, lCumulativeErrors = @ArithmUtils.compareBuffers(
                lRawBuffer1,
                lRawBuffer2,
                @NbrBitsPerSample,
                @NbrChannels,
                lNbrSamples1,
                @Coeff,
                @DistortionMap
              )
              oOutputData.pushRawBuffer(lOutputBuffer)
              @CumulativeErrors += lCumulativeErrors
              lNbrSamplesProcessed += lNbrSamples1
            elsif (lNbrSamples1 > lNbrSamples2)
              lOutputBuffer, lCumulativeErrors = @ArithmUtils.compareBuffers(
                lRawBuffer1[0..lRawBuffer2.size-1],
                lRawBuffer2,
                @NbrBitsPerSample,
                @NbrChannels,
                lNbrSamples1,
                @Coeff,
                @DistortionMap
              )
              oOutputData.pushRawBuffer(lOutputBuffer)
              @CumulativeErrors += lCumulativeErrors
              # Write remaining buffer (-Buffer1)
              computeInverseMap
              oOutputData.pushRawBuffer(@ArithmUtils.applyMap(@InverseMap, lRawBuffer1[lRawBuffer2.size..-1], @NbrBitsPerSample, lNbrSamples2 - lNbrSamples1))
              # Buffer2 is finished
              lRawBuffer2 = nil
              lNbrSamplesProcessed += lNbrSamples1
            else
              lOutputBuffer, lCumulativeErrors = @ArithmUtils.compareBuffers(
                lRawBuffer1,
                lRawBuffer2[0..lRawBuffer1.size-1],
                @NbrBitsPerSample,
                @NbrChannels,
                lNbrSamples1,
                @Coeff,
                @DistortionMap
              )
              oOutputData.pushRawBuffer(lOutputBuffer)
              @CumulativeErrors += lCumulativeErrors
              # Write remaining buffer (Buffer2)
              oOutputData.pushRawBuffer(lRawBuffer2[lRawBuffer1.size..-1])
              # Buffer1 is finished
              lRawBuffer1 = nil
              lNbrSamplesProcessed += lNbrSamples2
            end
            # Read next buffers if they are not finished
            if (lRawBuffer1 != nil)
              iInputData.eachRawBuffer(lNbrSamplesProcessed) do |iRawBuffer, iNbrSamples, iNbrChannels|
                break
              end
              lRawBuffer1, lNbrSamples1, lNbrChannels = iInputData.getCurrentRawBuffer
            end
            if (lRawBuffer2 != nil)
              iInputData2.eachRawBuffer(lNbrSamplesProcessed) do |iRawBuffer, iNbrSamples, iNbrChannels|
                break
              end
              lRawBuffer2, lNbrSamples2, lNbrChannels = iInputData2.getCurrentRawBuffer
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
          lInvertMap = [nil]*(2**@NbrBitsPerSample)
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
        puts "Cumulative errors: #{@CumulativeErrors} (#{Float(@CumulativeErrors*100)/Float(iInputData.NbrSamples*(2**@NbrBitsPerSample))} %)"

        return rError
      end

      private

      # Compute the inverse map
      def computeInverseMap
        if (defined?(@InverseMap) == nil)
          # Compute the function that will perform inversion
          lMaxValue = 2**(@NbrBitsPerSample-1) - 1
          lMinValue = -2**(@NbrBitsPerSample-1)
          @InverseMap = @ArithmUtils.createMapFromFunctions(
            @NbrBitsPerSample,
            [ {
              :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
              :MinValue => lMinValue,
              :MaxValue => lMaxValue,
              :Points => {
                lMinValue => -lMinValue,
                lMaxValue => -lMaxValue
              }
            } ] * @NbrChannels
          )
        end
      end

    end

  end

end