# To change this template, choose Tools | Templates
# and open the template in the editor.

require 'WSK/FFTUtils/FFTUtils'

module WSK

  module Actions

    class FFT

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
        return 0
      end
      
      # Execute
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (_Object_): The output data to fill
      # Return:
      # * _Exception_: An error, or nil if success
      def execute(iInputData, oOutputData)
        # Instantiate the C extension for FFT utils
        lFFTUtils = FFTUtils::FFTUtils.new
        # For each frequency index i, we have
        # Fi = Sum(t=0..N-1, Xt * cos( Wi * t ) )^2 + Sum(t=0..N-1, Xt * sin( Wi * t ) )^2
        # With N = Number of samples, Xt the sample number t, and Wi = -2*Pi*440*2^(i/12)/S, with S = sample rate
        # Compute the array of Wi
        lW = lFFTUtils.createWi(FREQINDEX_FIRST, FREQINDEX_LAST, iInputData.Header.SampleRate)
        lNbrFreq = FREQINDEX_LAST - FREQINDEX_FIRST + 1
        # Prepare the results of cos and sin sums
        lSumCos = lFFTUtils.initSumArray(lNbrFreq, iInputData.Header.NbrChannels)
        lSumSin = lFFTUtils.initSumArray(lNbrFreq, iInputData.Header.NbrChannels)
        # Parse the data
        lIdxSample = 0
        iInputData.eachRawBuffer do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          lFFTUtils.completeSumCosSin(iInputRawBuffer, lIdxSample, iInputData.Header.NbrBitsPerSample, iNbrSamples, iNbrChannels, lNbrFreq, lW, lSumCos, lSumSin)
          lIdxSample += iNbrSamples
          $stdout.write("#{(lIdxSample*100)/iInputData.NbrSamples} %\015")
          $stdout.flush
        end
        # Compute the result: FFT coeff, per channel, per frequency
        # list< list< Integer > >
        lF = lFFTUtils.computeFFT(iInputData.Header.NbrChannels, lNbrFreq, lSumCos, lSumSin)

        # Display results
        (FREQINDEX_FIRST..FREQINDEX_LAST).each_with_index do |iIdx, iIdxFreq|
          logDebug "[#{(440*(2**(iIdx/12.0))).round} Hz]: #{lF[iIdxFreq].join(', ')}"
        end
        # Write the result in a file
        File.open('fft.result', 'wb') do |oFile|
          oFile.write(Marshal.dump([iInputData.Header.NbrBitsPerSample, iInputData.NbrSamples, lF]))
        end

        return nil
      end

#      private
#
#      # Complete the cosinus et sinus sums to compute the FFT
#      #
#      # Parameters:
#      # * *iInputCBuffer* (_Array_): The input buffer
#      # * *iIdxSample* (_Integer_): The current sample index
#      # * *iNbrChannels* (_Integer_): The number of channels
#      # * *iW* (<em>list<Float></em>): The list of Wi indices, per frequency index
#      # * *ioSumCos* (<em>list<list<Float>></em>): The list of cosinus to complete
#      # * *ioSumSin* (<em>list<list<Float>></em>): The list of sinus to complete
#      def completeSumCosSin(iInputCBuffer, iIdxSample, iNbrChannels, iW, ioSumCos, ioSumSin)
#        lIdxChannel = 0
#        lIdxSample = iIdxSample
#        iInputCBuffer.each do |iValue|
#          iW.each_with_index do |iWValue, iIdxFreq|
#            lTrigoValue = iWValue*lIdxSample
#            ioSumCos[iIdxFreq][lIdxChannel] += iValue*Math.cos(lTrigoValue)
#            ioSumSin[iIdxFreq][lIdxChannel] += iValue*Math.sin(lTrigoValue)
#          end
#          lIdxChannel += 1
#          if (lIdxChannel == iNbrChannels)
#            lIdxChannel = 0
#            lIdxSample += 1
#          end
#        end
#      end
#
    end

  end

end
