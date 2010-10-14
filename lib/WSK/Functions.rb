module WSK

  module Functions

    # Function type piecewise linear.
    # Here are the possible attributes used by this type:
    # *:MinValue* (_Integer_): Minimal value of the plots of the function [optional = Minimal value of points]
    # *:MaxValue* (_Integer_): Maximal value of the plots of the function [optional = Maximal value of points]
    # *:Points* (<em>map<Integer,Integer></em>): Coordinates of points indicating each linear part
    FCTTYPE_PIECEWISE_LINEAR = 0

    # Class implementing a mathematical function that can then be used in many contexts
    class Function

      # Constructor
      def initialize
        # The underlying Ruby function
        @Function = nil
        # The C libraries
        @FunctionUtils = nil
        @VolumeUtils = nil
      end

      # Read from a file
      #
      # Parameters:
      # * *iFileName* (_String_): File name
      def readFromFile(iFileName)
        lStrFunction = nil
        if (File.exists?(iFileName))
          File.open(iFileName, 'r') do |iFile|
            lStrFunction = iFile.read
          end
        else
          raise RuntimeError.new("Missing file #{iFileName} to load function.")
        end
        begin
          @Function = eval(lStrFunction)
        rescue Exception
          raise RuntimeError.new("Invalid function specified in file #{iFileName}: #{$!}")
        end
      end

      # Read a function from the volume of an input data
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *iIdxBeginSample* (_Integer_): Index of the first sample beginning the volume reading
      # * *iIdxEndSample* (_Integer_): Index of the last sample ending the volume reading
      # * *iInterval* (_Integer_): The number of samples used as an interval in measuring the volume
      def readFromInputVolume(iInputData, iIdxBeginSample, iIdxEndSample, iInterval)
        @Function = {
          :FunctionType => FCTTYPE_PIECEWISE_LINEAR,
          :Points => []
        }
        # Profile
        prepareVolumeUtils
        lIdxCurrentSample = iIdxBeginSample
        while (lIdxCurrentSample <= iIdxEndSample)
          lIdxCurrentEndSample = lIdxCurrentSample + iInterval - 1
          if (lIdxCurrentEndSample > iIdxEndSample)
            lIdxCurrentEndSample = iIdxEndSample
          end
          lRawBuffer = ''
          iInputData.eachRawBuffer(lIdxCurrentSample, lIdxCurrentEndSample, :NbrSamplesPrefetch => iIdxEndSample-lIdxCurrentSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
            lRawBuffer += iInputRawBuffer
          end
          # Profile this buffer
          lRMSValues = @VolumeUtils.measureRMS(lRawBuffer, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels, lIdxCurrentEndSample - lIdxCurrentSample + 1)
          lRMSMoyValue = 0
          lRMSValues.each do |iRMSValue|
            lRMSMoyValue += iRMSValue
          end
          lRMSMoyValue /= lRMSValues.size
          # Complete the function
          if (@Function[:Points].empty?)
            # First points: add also the point 0
            @Function[:Points] = [ [0, lRMSMoyValue] ]
          end
          # Add a point to the function in the middle of this interval
          lPointX = lIdxCurrentSample - iIdxBeginSample + (lIdxCurrentEndSample - lIdxCurrentSample + 1)/2
          @Function[:Points] << [lPointX, lRMSMoyValue]
          # Increment the cursor
          lIdxCurrentSample = lIdxCurrentEndSample + 1
          if (lIdxCurrentSample == iIdxEndSample + 1)
            # The last point: add the ending one
            @Function[:Points] << [iIdxEndSample - iIdxBeginSample, lRMSMoyValue]
          end
          $stdout.write("#{(lIdxCurrentSample*100)/(iIdxEndSample - iIdxBeginSample + 1)} %\015")
          $stdout.flush
        end
      end

      # Apply the function on the volume of a raw buffer
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (<em>WSK::Model::DirectStream</em>): The output data
      # * *iIdxBeginSample* (_Integer_): Index of the first sample beginning the volume transformation
      # * *iIdxEndSample* (_Integer_): Index of the last sample ending the volume transformation
      def applyOnVolume(iInputData, oOutputData, iIdxBeginSample, iIdxEndSample)
        prepareFunctionUtils
        lCFunction = @FunctionUtils.createCFunction(@Function, iIdxBeginSample, iIdxEndSample)
        lIdxBufferSample = iIdxBeginSample
        iInputData.eachRawBuffer(iIdxBeginSample, iIdxEndSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          prepareVolumeUtils
          oOutputData.pushRawBuffer(@VolumeUtils.applyVolumeFct(lCFunction, iInputRawBuffer, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels, iNbrSamples, lIdxBufferSample))
          lIdxBufferSample += iNbrSamples
        end
      end

      # Divide values by a given factor
      #
      # Parameters:
      # * *iFactor* (_Integer_): Factor to divide by
      def divideBy(iFactor)
        lFloatFactor = iFactor.to_f
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          @Function[:Points].each do |ioPoint|
            ioPoint[1] /= lFloatFactor
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end

      # Write the function to a file
      #
      # Parameters:
      # * *iFileName* (_String_): File name to write
      def writeToFile(iFileName)
        require 'pp'
        File.open(iFileName, 'w') do |oFile|
          oFile.write(@Function.pretty_inspect)
        end
      end

      private

      # Prepare the Function utils C library.
      # This can be called several times.
      def prepareFunctionUtils
        if (@FunctionUtils == nil)
          require 'WSK/FunctionUtils/FunctionUtils'
          @FunctionUtils = WSK::FunctionUtils::FunctionUtils.new
        end
      end

      # Prepare the Volume utils C library.
      # This can be called several times.
      def prepareVolumeUtils
        if (@VolumeUtils == nil)
          require 'WSK/VolumeUtils/VolumeUtils'
          @VolumeUtils = WSK::VolumeUtils::VolumeUtils.new
        end
      end

    end

  end

end
