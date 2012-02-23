#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Actions

    class Analyze

      include WSK::Common

      # Get the number of samples that will be written.
      # This is called before execute, as it is needed to write the output file.
      # It is possible to give a majoration: it will be padded with silence.
      #
      # Parameters::
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # Return::
      # * _Integer_: The number of samples to be written
      def getNbrSamples(iInputData)
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
        lMaxValue = 2**(iInputData.Header.NbrBitsPerSample-1)-1
        lMinValue = 2**(iInputData.Header.NbrBitsPerSample-1)

        # Require C extension
        require 'WSK/AnalyzeUtils/AnalyzeUtils'
        lAnalyzeUtils = AnalyzeUtils::AnalyzeUtils.new
        # Initialize computing arrays
        lCMaxValues = lAnalyzeUtils.init64bitsArray(iInputData.Header.NbrChannels, 0);
        lCMinValues = lAnalyzeUtils.init64bitsArray(iInputData.Header.NbrChannels, lMinValue);
        lCSumValues = lAnalyzeUtils.init64bitsArray(iInputData.Header.NbrChannels, 0);
        lCAbsSumValues = lAnalyzeUtils.init64bitsArray(iInputData.Header.NbrChannels, 0);
        lCSquareSumValues = lAnalyzeUtils.init128bitsArray(iInputData.Header.NbrChannels);
        # Gather data
        lNbrSamplesProcessed = 0
        iInputData.eachRawBuffer do |iRawBuffer, iNbrSamples, iNbrChannels|
          lAnalyzeUtils.completeAnalyze(iRawBuffer, iInputData.Header.NbrBitsPerSample, iNbrSamples, iNbrChannels, lCMaxValues, lCMinValues, lCSumValues, lCAbsSumValues, lCSquareSumValues)
          lNbrSamplesProcessed += iNbrSamples
          $stdout.write("#{(lNbrSamplesProcessed*100)/iInputData.NbrSamples} %\015")
          $stdout.flush
        end
        # Get the Ruby arrays from the C ones
        lMaxValues = lAnalyzeUtils.getRuby64bitsArray(lCMaxValues, iInputData.Header.NbrChannels);
        lMinValues = lAnalyzeUtils.getRuby64bitsArray(lCMinValues, iInputData.Header.NbrChannels);
        lSumValues = lAnalyzeUtils.getRuby64bitsArray(lCSumValues, iInputData.Header.NbrChannels);
        lAbsSumValues = lAnalyzeUtils.getRuby64bitsArray(lCAbsSumValues, iInputData.Header.NbrChannels);
        lSquareSumValues = lAnalyzeUtils.getRuby128bitsArray(lCSquareSumValues, iInputData.Header.NbrChannels);
        # Compute values in DB scale also
        lDBMinValues = []
        lMinValues.each do |iValue|
          lDBMinValues << val2db(iValue, lMinValue)[0]
        end
        lDBMaxValues = []
        lMaxValues.each do |iValue|
          lDBMaxValues << val2db(iValue, lMaxValue)[0]
        end
        lMoyValues = []
        lDBMoyValues = []
        lSumValues.each do |iValue|
          lMoyValue = Float(iValue)/Float(iInputData.NbrSamples)
          lMoyValues << lMoyValue
          lDBMoyValues << val2db(lMoyValue, lMinValue)[0]
        end
        lAbsMoyValues = []
        lDBAbsMoyValues = []
        lAbsSumValues.each do |iValue|
          lAbsMoyValue = Float(iValue)/Float(iInputData.NbrSamples)
          lAbsMoyValues << lAbsMoyValue
          lDBAbsMoyValues << val2db(lAbsMoyValue, lMinValue)[0]
        end
        lAbsMaxValues = []
        lDBAbsMaxValues = []
        lMinValues.each_with_index do |iValue, iIdx|
          lAbsMinValue = iValue.abs
          lAbsMaxValue = lMaxValues[iIdx].abs
          lAbsMax = nil
          if (lAbsMinValue > lAbsMaxValue)
            lAbsMax = lAbsMinValue
          else
            lAbsMax = lAbsMaxValue
          end
          lAbsMaxValues << lAbsMax
          lDBAbsMaxValues << val2db(lAbsMax, lMinValue)[0]
        end
        lAbsMaxValue = lAbsMaxValues.sort[-1]
        lAbsMaxValueDB, lAbsMaxValuePC = val2db(lAbsMaxValue, lMinValue)
        lAbsMoyValue = 0
        lAbsMoyValues.each do |iValue|
          lAbsMoyValue += iValue
        end
        lAbsMoyValue /= lAbsMoyValues.size
        lAbsMoyValueDB, lAbsMoyValuePC = val2db(lAbsMoyValue, lMinValue)
        lRMSValues = []
        lDBRMSValues = []
        lSquareSumValues.each do |iValue|
          lRMSValue = Math.sqrt(iValue/iInputData.NbrSamples).round
          lRMSValues << lRMSValue
          lDBRMSValues << val2db(lRMSValue, lMinValue)[0]
        end
        lResult = {
          :MinValues => lMinValues,
          :MaxValues => lMaxValues,
          :MoyValues => lMoyValues,
          :DBMinValues => lDBMinValues,
          :DBMaxValues => lDBMaxValues,
          :DBMoyValues => lDBMoyValues,
          :AbsMaxValues => lAbsMaxValues,
          :AbsMoyValues => lAbsMoyValues,
          :DBAbsMaxValues => lDBAbsMaxValues,
          :DBAbsMoyValues => lDBAbsMoyValues,
          :SampleRate => iInputData.Header.SampleRate,
          :SampleSize => iInputData.Header.NbrBitsPerSample,
          :NbrChannels => iInputData.Header.NbrChannels,
          :DataRate => ((iInputData.Header.NbrChannels*iInputData.Header.NbrBitsPerSample)/8)*iInputData.Header.SampleRate,
          :NbrDataSamples => iInputData.NbrSamples,
          :DataLength => Float(iInputData.NbrSamples)/Float(iInputData.Header.SampleRate),
          :AbsMaxValue => lAbsMaxValue,
          :DBAbsMaxValue => lAbsMaxValueDB,
          :PCAbsMaxValue => lAbsMaxValuePC,
          :AbsMoyValue => lAbsMoyValue,
          :DBAbsMoyValue => lAbsMoyValueDB,
          :PCAbsMoyValue => lAbsMoyValuePC,
          :MaxPossibleValue => lMaxValue,
          :MinPossibleValue => lMinValue,
          :RMSValues => lRMSValues,
          :DBRMSValues => lDBRMSValues
        }
        # Display
        log_info "Min values: #{lResult[:MinValues].join(', ')}"
        log_info "Min values (db): #{lResult[:DBMinValues].join(', ')}"
        log_info "Max values: #{lResult[:MaxValues].join(', ')}"
        log_info "Max values (db): #{lResult[:DBMaxValues].join(', ')}"
        log_info "Moy values (DC offset): #{lResult[:MoyValues].join(', ')}"
        log_info "Moy values (DC offset) (db): #{lResult[:DBMoyValues].join(', ')}"
        log_info "RMS values: #{lResult[:RMSValues].join(', ')}"
        log_info "RMS values (db): #{lResult[:DBRMSValues].join(', ')}"
        log_info "Abs Max values: #{lResult[:AbsMaxValues].join(', ')}"
        log_info "Abs Max values (db): #{lResult[:DBAbsMaxValues].join(', ')}"
        log_info "Abs Moy values: #{lResult[:AbsMoyValues].join(', ')}"
        log_info "Abs Moy values (db): #{lResult[:DBAbsMoyValues].join(', ')}"
        log_info ''
        log_info 'Header:'
        log_info "Sample rate: #{lResult[:SampleRate]}"
        log_info "Sample size (bits): #{lResult[:SampleSize]}"
        log_info "Number of channels: #{lResult[:NbrChannels]}"
        log_info "Data rate: #{lResult[:DataRate]} bytes/sec"
        log_info ''
        log_info 'Data:'
        log_info "Number of data samples: #{lResult[:NbrDataSamples]} (#{lResult[:DataLength]} secs)"
        log_info "Maximal absolute value: #{lResult[:AbsMaxValue]} (#{lResult[:DBAbsMaxValue]} db) (#{lResult[:PCAbsMaxValue]} %)"
        log_info "Mean absolute value: #{lResult[:AbsMoyValue]} (#{lResult[:DBAbsMoyValue]} db) (#{lResult[:PCAbsMoyValue]} %)"
        # Write a result file
        File.open('analyze.result', 'wb') do |oFile|
          oFile.write(Marshal.dump(lResult))
        end

        return nil
      end

    end

  end

end
