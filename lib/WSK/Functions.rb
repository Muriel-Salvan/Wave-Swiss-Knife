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
        # The underlying C function
        @CFunction = nil
        # The range for which the C function was instantiated
        @CFunction_Range = nil
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

      # Apply the function on the volume of a raw buffer
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (<em>WSK::Model::DirectStream</em>): The output data
      # * *iIdxBeginSample* (_Integer_): Index of the first sample beginning the volume transformation
      # * *iIdxEndSample* (_Integer_): Index of the last sample ending the volume transformation
      def applyOnVolume(iInputData, oOutputData, iIdxBeginSample, iIdxEndSample)
        prepareCFunction(iIdxBeginSample, iIdxEndSample)
        lIdxBufferSample = iIdxBeginSample
        iInputData.eachRawBuffer(iIdxBeginSample, iIdxEndSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          prepareVolumeUtils
          oOutputData.pushRawBuffer(@VolumeUtils.applyVolumeFct(@CFunction, iInputRawBuffer, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels, iNbrSamples, lIdxBufferSample))
          lIdxBufferSample += iNbrSamples
        end
      end

      private

      # Prepare the C function to be used.
      # This can be called several times.
      # It creates the C function translated into a given sample range, for optimized processing by C methods.
      #
      # Parameters:
      # * *iIdxBeginSample* (_Integer_): Index of the first sample that will begin the function
      # * *iIdxEndSample* (_Integer_): Index of the last sample that will end the function
      def prepareCFunction(iIdxBeginSample, iIdxEndSample)
        if ((@CFunction == nil) or
            (@CFunction_Range != [iIdxBeginSample, iIdxEndSample]))
          prepareFunctionUtils
          @CFunction = @FunctionUtils.createCFunction(@Function, iIdxBeginSample, iIdxEndSample)
          @CFunction_Range = [iIdxBeginSample, iIdxEndSample]
        end
      end

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
