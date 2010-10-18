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

      include WSK::Common

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

      # Set directly a function from a hash
      #
      # Parameters:
      # * *iHashFunction* (<em>map<Symbol,Object></em>): The hashed function
      def set(iHashFunction)
        @Function = iHashFunction
      end

      # Apply the function on the volume of a raw buffer
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (<em>WSK::Model::DirectStream</em>): The output data
      # * *iIdxBeginSample* (_Integer_): Index of the first sample beginning the volume transformation
      # * *iIdxEndSample* (_Integer_): Index of the last sample ending the volume transformation
      # * *iUnitDB* (_Boolean_): Are function values to be interpreted as DB units ?
      def applyOnVolume(iInputData, oOutputData, iIdxBeginSample, iIdxEndSample, iUnitDB)
        prepareFunctionUtils
        lCFunction = @FunctionUtils.createCFunction(@Function, iIdxBeginSample, iIdxEndSample)
        lIdxBufferSample = iIdxBeginSample
        iInputData.eachRawBuffer(iIdxBeginSample, iIdxEndSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          prepareVolumeUtils
          oOutputData.pushRawBuffer(@VolumeUtils.applyVolumeFct(lCFunction, iInputRawBuffer, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels, iNbrSamples, lIdxBufferSample, iUnitDB))
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

      # Convert the units in DB equivalent
      def convertToDB
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          @Function[:Points].each do |ioPoint|
            ioPoint[1], lPC = val2db(ioPoint[1])
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

      # Apply a mapping function to this function.
      #
      # Parameters:
      # * *iMapFunction* (_Function_): The mapping function
      def applyMapFunction(iMapFunction)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          case iMapFunction.functionData[:FunctionType]
          when FCTTYPE_PIECEWISE_LINEAR
            # Both functions are piecewise linear
            # Algorithm:
            # * For each segment of our function:
            # ** We look at the segments from the map function.
            # ** For each found segment:
            # *** We find at which abscisses this segment will change values
            # *** We change the sub-segment between those abscisses
            lPoints = @Function[:Points]
            lMapPoints = iMapFunction.functionData[:Points]
            lNewPoints = []
            lIdxSegment = 0
            while (lIdxSegment < lPoints.size-1)
              lBeginX = lPoints[lIdxSegment][0]
              lBeginY = lPoints[lIdxSegment][1]
              lEndX = lPoints[lIdxSegment+1][0]
              lEndY = lPoints[lIdxSegment+1][1]
              # The direction in which we are going to look for the map segments
              lIncMapSegment = nil
              if (lEndY >= lBeginY)
                lIncMapSegment = true
              else
                lIncMapSegment = false
              end
              # Find the map function's segment containing the beginning of our segment
              lIdxMapSegment = 0
              while (lBeginY >= lMapPoints[lIdxMapSegment+1][0])
                lIdxMapSegment += 1
              end
              # Compute the new value of our segment beginning
              lNewBeginY = lMapPoints[lIdxMapSegment][1] + ((lMapPoints[lIdxMapSegment+1][1]-lMapPoints[lIdxMapSegment][1])*(lBeginY-lMapPoints[lIdxMapSegment][0]))/(lMapPoints[lIdxMapSegment+1][0]-lMapPoints[lIdxMapSegment][0])
              lNewPoints << [ lBeginX, lNewBeginY ]
              # Get the next map segments unless we reach our segment's end
              # !!! Find the next map segment according to the direction
              if (lIncMapSegment)
                while (lEndY > lMapPoints[lIdxMapSegment+1][0])
                  # We have a new map segment to consider in our segment
                  # Find the absciss at which our Y coordinates get the value lMapPoints[lIdxMapSegment+1][0]
                  lNewSegmentX = lBeginX + ((lEndX-lBeginX)*(lMapPoints[lIdxMapSegment+1][0] - lBeginY))/(lEndY-lBeginY)
                  lNewPoints << [ lNewSegmentX, lMapPoints[lIdxMapSegment+1][1] ]
                  lIdxMapSegment += 1
                end
                # Our segment ends before next map segment
              else
                while (lEndY <= lMapPoints[lIdxMapSegment][0])
                  # We have a new map segment to consider in our segment
                  # Find the absciss at which our Y coordinates get the value lMapPoints[lIdxMapSegment][0]
                  lNewSegmentX = lBeginX + ((lEndX-lBeginX)*(lMapPoints[lIdxMapSegment][0] - lBeginY))/(lEndY-lBeginY)
                  lNewPoints << [ lNewSegmentX, lMapPoints[lIdxMapSegment][1] ]
                  lIdxMapSegment -= 1
                end
                # Our segment ends before previous map segment
              end
              # Write the segment end if it is the last one (otherwise it will be written by the next iteration)
              if (lIdxSegment == lPoints.size-2)
                lNewEndY = lMapPoints[lIdxMapSegment][1] + ((lMapPoints[lIdxMapSegment+1][1]-lMapPoints[lIdxMapSegment][1])*(lEndY-lMapPoints[lIdxMapSegment][0]))/(lMapPoints[lIdxMapSegment+1][0]-lMapPoints[lIdxMapSegment][0])
                lNewPoints << [ lEndX, lNewEndY ]
              end
              lIdxSegment += 1
            end
            # Replace with new points
            @Function[:Points] = lNewPoints
          else
            logErr "Unknown function type: #{@Function[:FunctionType]}"
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end

      # Substract a function to this function
      #
      # Parameters:
      # * *iSubFunction* (_Function_): The function to substract
      def substractFunction(iSubFunction)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          case iSubFunction.functionData[:FunctionType]
          when FCTTYPE_PIECEWISE_LINEAR
            lNewPoints = []
            unionXWithFunction_PiecewiseLinear(iSubFunction) do |iX, iY, iOtherY|
              if (iY == nil)
                lNewPoints << [ iX, -iOtherY ]
              elsif (iOtherY == nil)
                lNewPoints << [ iX, iY ]
              else
                lNewPoints << [ iX, iY - iOtherY ]
              end
            end
            # Replace with new points
            @Function[:Points] = lNewPoints
          else
            logErr "Unknown function type: #{@Function[:FunctionType]}"
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end

      # Divide this function by another function
      #
      # Parameters:
      # * *iDivFunction* (_Function_): The function that divides
      def divideByFunction(iDivFunction)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          case iDivFunction.functionData[:FunctionType]
          when FCTTYPE_PIECEWISE_LINEAR
            lNewPoints = []
            unionXWithFunction_PiecewiseLinear(iDivFunction) do |iX, iY, iOtherY|
              if (iY == nil)
                lNewPoints << [ iX, 0 ]
              elsif (iOtherY == nil)
                lNewPoints << [ iX, 0 ]
              else
                lNewPoints << [ iX, iY / iOtherY ]
              end
            end
            # Replace with new points
            @Function[:Points] = lNewPoints
          else
            logErr "Unknown function type: #{@Function[:FunctionType]}"
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end

      # Get the internal function data
      #
      # Return:
      # * <em>map<Symbol,Object></em>: The internal function data
      def functionData
        return @Function
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

      # Find abscisses of both functions and the corresponding Y values
      #
      # Parameters:
      # * *iOtherFunction* (_Function_): The other function
      # * *CodeBlock*: Code called for each point found:
      # ** *iX* (_Integer_): The corresponding abscisse (can be nil if none)
      # ** *iY* (_Float_): The corresponding Y value for this function (can be nil if none)
      # ** *iOtherY* (_Float_): The corresponding Y value for the other function
      def unionXWithFunction_PiecewiseLinear(iOtherFunction)
        lPoints = @Function[:Points]
        lOtherPoints = iOtherFunction.functionData[:Points]
        # Get all the abscisses sorted
        lXList = (lPoints.map { |iPoint| next iPoint[0] } + lOtherPoints.map { |iPoint| next iPoint[0] }).sort.uniq
        # Read segments abscisse by abscisse
        lIdxSegment = 0
        lIdxOtherSegment = 0
        lXList.each do |iX|
          if (lPoints[lIdxSegment] == nil)
            # No abscisse on lPoints for this iX
            # Forcefully we have lOtherPoints[lIdxOtherSegment][0] == iX
            yield(iX, nil, lOtherPoints[lIdxOtherSegment][1])
            lIdxOtherSegment += 1
          elsif (lOtherPoints[lIdxOtherSegment] == nil)
            # No abscisse on lOtherPoints for this iX
            # Forcefully we have lPoints[lIdxSegment][0] == iX
            yield(iX, lPoints[lIdxSegment][1], nil)
            lIdxSegment += 1
          elsif (lPoints[lIdxSegment][0] == iX)
            # lPoints has this abscisse
            if (lOtherPoints[lIdxOtherSegment][0] == iX)
              # If both functions have a point here, it's easy.
              yield(iX, lPoints[lIdxSegment][1], lOtherPoints[lIdxOtherSegment][1])
              lIdxOtherSegment += 1
            else
              # Compute the Y value for the other function
              yield(iX, lPoints[lIdxSegment][1], lOtherPoints[lIdxOtherSegment-1][1] + ((lOtherPoints[lIdxOtherSegment][1] - lOtherPoints[lIdxOtherSegment-1][1])*(iX - lOtherPoints[lIdxOtherSegment-1][0]))/(lOtherPoints[lIdxOtherSegment][0] - lOtherPoints[lIdxOtherSegment-1][0]))
            end
            lIdxSegment += 1
          else
            # We have forcefully lOtherPoints[lIdxOtherSegment][0] == iX
            # Compute the Y value for this function
            yield(iX, lPoints[lIdxSegment-1][1] + ((lPoints[lIdxSegment][1] - lPoints[lIdxSegment-1][1])*(iX - lPoints[lIdxSegment-1][0]))/(lPoints[lIdxSegment][0] - lPoints[lIdxSegment-1][0]), lOtherPoints[lIdxOtherSegment][1])
            lIdxOtherSegment += 1
          end
        end
      end

    end

  end

end
