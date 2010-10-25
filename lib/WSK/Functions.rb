require 'rational'

# Convert a float to a Rational
class Float

  # Convert to a Rational
  #
  # Return:
  # * _Rational_: Corresponding Rational
  def to_r
    rResult = nil

    if (self.nan?)
      rResult = Rational(0,0) # Div by zero error
    elsif (self.infinite?)
      rResult = Rational(self<0 ? -1 : 1,0) # Div by zero error
    else
      lSign, lExponent, lFloat = [self].pack("G").unpack("B*").first.unpack("AA11A52")
      lSign = (-1)**lSign.to_i
      lExponent = lExponent.to_i(2)
      if ((lExponent.nonzero?) and
          (lExponent<2047))
        rResult = Rational(lSign)*Rational(2)**(lExponent-1023)*Rational("1#{lFloat}".to_i(2),0x10000000000000)
      elsif (lExponent.zero?)
        rResult = Rational(lSign)*Rational(2)**(-1024)*Rational("0#{lFloat}".to_i(2),0x10000000000000)
      end
    end

    return rResult
  end

end

module WSK

  module Functions

    # Function type piecewise linear.
    # Here are the possible attributes used by this type:
    # *:MinValue* (_Rational_): Minimal value of the plots of the function [optional = Minimal value of points]
    # *:MaxValue* (_Rational_): Maximal value of the plots of the function [optional = Maximal value of points]
    # *:Points* (<em>map<Rational,Rational></em>): Coordinates of points indicating each linear part
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
        convertDataTypes
        optimize
      end

      # Read a function from the volume of an input data
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *iIdxBeginSample* (_Integer_): Index of the first sample beginning the volume reading
      # * *iIdxEndSample* (_Integer_): Index of the last sample ending the volume reading
      # * *iInterval* (_Integer_): The number of samples used as an interval in measuring the volume
      # * *iRMSRatio* (_Float_): The ratio of RMS measure vs Peak measure (0.0 = only peak, 1.0 = only RMS)
      def readFromInputVolume(iInputData, iIdxBeginSample, iIdxEndSample, iInterval, iRMSRatio)
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
          lChannelLevelValues = @VolumeUtils.measureLevel(lRawBuffer, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels, lIdxCurrentEndSample - lIdxCurrentSample + 1, iRMSRatio)
          # Combine the channel levels based on the RMS ratio also
          lMaxValue = Rational(0, 1)
          lRMSValue = Rational(0, 1)
          lChannelLevelValues.each do |iLevelValue|
            if (iLevelValue > lMaxValue)
              lMaxValue = iLevelValue
            end
            lRMSValue += iLevelValue*iLevelValue
          end
          lRMSValue = Math.sqrt(lRMSValue/lChannelLevelValues.size).to_r
          lLevelValue = lRMSValue*(iRMSRatio.to_r) + lMaxValue*(Rational(1)-iRMSRatio.to_r)
          # Complete the function
          if (@Function[:Points].empty?)
            # First points: add also the point 0
            @Function[:Points] = [ [ Rational(0, 1), lLevelValue] ]
          end
          # Add a point to the function in the middle of this interval
          lPointX = lIdxCurrentSample - iIdxBeginSample + Rational(lIdxCurrentEndSample - lIdxCurrentSample + 1, 2)
          @Function[:Points] << [lPointX, lLevelValue]
          # Increment the cursor
          lIdxCurrentSample = lIdxCurrentEndSample + 1
          if (lIdxCurrentSample == iIdxEndSample + 1)
            # The last point: add the ending one
            @Function[:Points] << [Rational(iIdxEndSample - iIdxBeginSample, 1), lLevelValue]
          end
          $stdout.write("#{(lIdxCurrentSample*100)/(iIdxEndSample - iIdxBeginSample + 1)} %\015")
          $stdout.flush
        end
        optimize
      end

      # Set directly a function from a hash
      #
      # Parameters:
      # * *iHashFunction* (<em>map<Symbol,Object></em>): The hashed function
      def set(iHashFunction)
        @Function = iHashFunction
        convertDataTypes
        optimize
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

      # Draw the function into a raw buffer
      #
      # Parameters:
      # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
      # * *oOutputData* (<em>WSK::Model::DirectStream</em>): The output data
      # * *iIdxBeginSample* (_Integer_): Index of the first sample beginning the volume transformation
      # * *iIdxEndSample* (_Integer_): Index of the last sample ending the volume transformation
      # * *iUnitDB* (_Boolean_): Are function values to be interpreted as DB units ?
      # * *iMedianValue* (_Integer_): Median value to draw function ratio of 1.
      def draw(iInputData, oOutputData, iIdxBeginSample, iIdxEndSample, iUnitDB, iMedianValue)
        prepareFunctionUtils
        lCFunction = @FunctionUtils.createCFunction(@Function, iIdxBeginSample, iIdxEndSample)
        lIdxBufferSample = iIdxBeginSample
        iInputData.eachRawBuffer(iIdxBeginSample, iIdxEndSample) do |iInputRawBuffer, iNbrSamples, iNbrChannels|
          prepareVolumeUtils
          oOutputData.pushRawBuffer(@VolumeUtils.drawVolumeFct(lCFunction, iInputRawBuffer, iInputData.Header.NbrBitsPerSample, iInputData.Header.NbrChannels, iNbrSamples, lIdxBufferSample, iUnitDB, iMedianValue))
          lIdxBufferSample += iNbrSamples
        end
      end

      # Divide values by a given factor
      #
      # Parameters:
      # * *iFactor* (_Rational_): Factor to divide by
      def divideBy(iFactor)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          @Function[:Points].each do |ioPoint|
            ioPoint[1] /= iFactor
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end

      # Convert the Y units in DB equivalent
      #
      # Parameters:
      # * *iMaxYValue* (_Rational_): Maximal Y value
      def convertToDB(iMaxYValue)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          # Prepare variables for log computations
          @Log2 = Math::log(2).to_r
          @LogMax = valueLog(iMaxYValue)
          @Function[:Points].each do |ioPoint|
            ioPoint[1] = valueVal2db_Internal(ioPoint[1])
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end
      
      # Round values to a given precision
      #
      # Parameters:
      # * *iPrecisionX* (_Rational_): The desired precision for X values (1000 will round to E-3)
      # * *iPrecisionY* (_Rational_): The desired precision for Y values (1000 will round to E-3)
      def roundToPrecision(iPrecisionX, iPrecisionY)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          @Function[:Points] = @Function[:Points].map do |iPoint|
            next [ (Rational((iPoint[0]*iPrecisionX).round, 1))/iPrecisionX, (Rational((iPoint[1]*iPrecisionY).round, 1))/iPrecisionY ]
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
        optimize
      end
      
      # Apply damping.
      #
      # Parameters:
      # * *iSlopeUp* (_Rational_): The maximal value of slope when increasing (should be > 0), or nil if none
      # * *iSlopeDown* (_Rational_): The minimal value of slope when decreasing (should be < 0), or nil if none
      def applyDamping(iSlopeUp, iSlopeDown)
        if ((iSlopeUp != nil) and
            (iSlopeUp <= 0))
          logErr "Upward slope (#{iSlopeUp}) has to be > 0"
        elsif ((iSlopeDown != nil) and
               (iSlopeDown >= 0))
          logErr "Downward slope (#{iSlopeDown}) has to be < 0"
        else
          case @Function[:FunctionType]
          when FCTTYPE_PIECEWISE_LINEAR
            # Keep the first point
            lNewPoints = [ @Function[:Points][0] ]
            lIdxSegment = 0
            while (lIdxSegment < @Function[:Points].size - 1)
              # Compute the slope of this segment
              #puts "lIdxSegment=#{lIdxSegment}/#{@Function[:Points].size} Points=[ [ #{sprintf('%.2f',@Function[:Points][lIdxSegment][0])}, #{sprintf('%.2f',@Function[:Points][lIdxSegment][1])} ], [ #{sprintf('%.2f',@Function[:Points][lIdxSegment+1][0])}, #{sprintf('%.2f',@Function[:Points][lIdxSegment+1][1])} ] ]"
              lSegmentSlope = (@Function[:Points][lIdxSegment+1][1]-@Function[:Points][lIdxSegment][1])/(@Function[:Points][lIdxSegment+1][0]-@Function[:Points][lIdxSegment][0])
              #puts "lIdxSegment=#{lIdxSegment}/#{@Function[:Points].size} Slope=#{sprintf('%.2f',lSegmentSlope)} (#{lSegmentSlope.precs.inspect})"
              if (((lSegmentSlope > 0) and
                   (iSlopeUp != nil) and
                   (lSegmentSlope > iSlopeUp)) or
                  ((lSegmentSlope < 0) and
                   (iSlopeDown != nil) and
                   (lSegmentSlope < iSlopeDown)))
                # Choose the correct damping slope depending on the direction
                lSlope = nil
                if (lSegmentSlope > 0)
                  lSlope = iSlopeUp
                else
                  lSlope = iSlopeDown
                end
                # We have to apply damping starting the beginning of this segment.
                # Find the next intersection between the damped segment and our function.
                # The abscisse of the intersection
                lIntersectX = nil
                # A constant for the next loop
                lDampedSegmentOffsetY = @Function[:Points][lIdxSegment][1] - @Function[:Points][lIdxSegment][0]*lSlope
                lIdxSegmentIntersect = lIdxSegment + 1
                while (lIdxSegmentIntersect < @Function[:Points].size - 1)
                  # Find if there is an intersection
                  lSegmentIntersectDistX = @Function[:Points][lIdxSegmentIntersect+1][0] - @Function[:Points][lIdxSegmentIntersect][0]
                  lSegmentIntersectDistY = @Function[:Points][lIdxSegmentIntersect+1][1] - @Function[:Points][lIdxSegmentIntersect][1]
                  lIntersectX = ((lDampedSegmentOffsetY - @Function[:Points][lIdxSegmentIntersect][1])*lSegmentIntersectDistX + @Function[:Points][lIdxSegmentIntersect][0]*lSegmentIntersectDistY)/(lSegmentIntersectDistY - lSlope*lSegmentIntersectDistX)
                  # Is lIntersectX among our range ?
                  if ((lIntersectX >= @Function[:Points][lIdxSegmentIntersect][0]) and
                      (lIntersectX <= @Function[:Points][lIdxSegmentIntersect+1][0]))
                    # We have an intersection in the segment beginning at point n. lIdxSegmentIntersect, exactly at abscisse lIntersectX.
                    break
                  else
                    # Erase it as we will test for it after the loop
                    lIntersectX = nil
                  end
                  lIdxSegmentIntersect += 1
                end
                # Here, lIdxSegmentIntersect can point to the last point if no intersection was found
                if (lIntersectX == nil)
                  # We could not find any intersection
                  # We consider adding a point following the damped slope till the end of the function
                  lIntersectX = @Function[:Points][-1][0]
                end
                # Add the intersecting point (could be the last one)
                lIntersectPoint = [ lIntersectX, (lIntersectX - @Function[:Points][lIdxSegment][0])*lSlope + @Function[:Points][lIdxSegment][1] ]
                #puts "lIntersectX=#{lIntersectX.to_f} @Function[:Points][lIdxSegment][0]=#{@Function[:Points][lIdxSegment][0].to_f} lSlope=#{lSlope.to_f} @Function[:Points][lIdxSegment][1]=#{@Function[:Points][lIdxSegment][1].to_f} lIntersectPoint[1]=#{lIntersectPoint[1].to_f}"
                lNewPoints << lIntersectPoint
                # Continue after this intersection (we create also the intersecting point on our old points by modifying them)
                @Function[:Points][lIdxSegmentIntersect] = lIntersectPoint
                lIdxSegment = lIdxSegmentIntersect
              else
                # The slope is ok, keep this segment as it is
                lNewPoints << @Function[:Points][lIdxSegment+1]
                lIdxSegment += 1
              end
            end
            # Replace our points with new ones
            @Function[:Points] = lNewPoints
          else
            logErr "Unknown function type: #{@Function[:FunctionType]}"
          end
        end
        optimize
      end

      # Invert the abscisses of a function
      def invertAbscisses
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          lNewPoints = []
          lMinMaxX = @Function[:Points][0][0] + @Function[:Points][-1][0]
          @Function[:Points].reverse_each do |iPoint|
            lNewPoints << [lMinMaxX - iPoint[0], iPoint[1]]
          end
          @Function[:Points] = lNewPoints
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end

      # Get the function bounds
      #
      # Return:
      # * _Rational_: Minimal X
      # * _Rational_: Minimal Y
      # * _Rational_: Maximal X
      # * _Rational_: Maximal Y
      def getBounds
        rMinX = nil
        rMinY = nil
        rMaxX = nil
        rMaxY = nil

        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          rMinX = @Function[:Points][0][0]
          rMaxX = @Function[:Points][-1][0]
          @Function[:Points].each do |iPoint|
            if (rMinY == nil)
              rMinY = iPoint[1]
              rMaxY = iPoint[1]
            else
              if (rMinY > iPoint[1])
                rMinY = iPoint[1]
              end
              if (rMaxY < iPoint[1])
                rMaxY = iPoint[1]
              end
            end
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end

        return rMinX, rMinY, rMaxX, rMaxY
      end

      # Write the function to a file
      #
      # Parameters:
      # * *iFileName* (_String_): File name to write
      # * *iParams* (<em>map<Symbol,Object></em>): Additional parameters [optional = {}]:
      # ** *:Floats* (_Boolean_): Do we write Float values ? [optional = false]
      def writeToFile(iFileName, iParams = {})
        lParams = {
          # Default value
          :Floats => false
        }.merge(iParams)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          require 'pp'
          lData = @Function
          if (lParams[:Floats])
            # Convert to Floats
            lData[:Points].map! do |iPoint|
              next [ iPoint[0].to_f, iPoint[1].to_f ]
            end
          end
          File.open(iFileName, 'w') do |oFile|
            oFile.write(lData.pretty_inspect)
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
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
              if (lBeginY == lMapPoints[-1][0])
                lIdxMapSegment = lMapPoints.size - 2
              else
                while (lBeginY >= lMapPoints[lIdxMapSegment+1][0])
                  lIdxMapSegment += 1
                end
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
                while (lEndY < lMapPoints[lIdxMapSegment][0])
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
        optimize
      end

      # Remove intermediate abscisses that are too close to each other
      #
      # Parameters:
      # * *iMinDistance* (_Rational_): Minimal distance for abscisses triplets to have
      def removeNoiseAbscisses(iMinDistance)
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          lNewPoints = [ @Function[:Points][0] ]
          lIdxPoint = 0
          while (lIdxPoint < @Function[:Points].size - 1)
            # Now we skip the next last point among iMinDistance range
            lPointX = @Function[:Points][lIdxPoint][0]
            lIdxOtherPoint = lIdxPoint + 1
            while ((lIdxOtherPoint < @Function[:Points].size) and
                   (@Function[:Points][lIdxOtherPoint][0] - lPointX < iMinDistance))
              lIdxOtherPoint += 1
            end
            # Either lIdxOtherPoint is beyond the end, or it points to the first point that is beyond iMinDistance
            # We add the previous point if it is not already ours
            if (lIdxOtherPoint-1 > lIdxPoint)
              lNewPoints << @Function[:Points][lIdxOtherPoint-1]
              # And we continue searching from this new added point
              lIdxPoint = lIdxOtherPoint-1
            else
              # It is our point, continue on to the next one
              lNewPoints << @Function[:Points][lIdxOtherPoint]
              lIdxPoint = lIdxOtherPoint
            end
          end
          @Function[:Points] = lNewPoints
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
        optimize
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
        optimize
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
        optimize
      end

      # Get the internal function data
      #
      # Return:
      # * <em>map<Symbol,Object></em>: The internal function data
      def functionData
        return @Function
      end

      # Compute the log of a function value.
      #
      # Parameters:
      # * *iValue* (_Rational_): The value
      def valueLog(iValue)
        return Math::log(iValue).to_r
      end
      
      # Compute a DB value out of a ratio using function values
      #
      # Parameters:
      # * *iValue* (_Rational_): The value
      # * *iMaxValue* (_Rational_): The maximal value
      # Return:
      # * _Rational_: Its corresponding db
      def valueVal2db(iValue, iMaxValue)
        @Log2 = Math::log(2).to_r
        @LogMax = valueLog(iMaxValue)
        
        return valueVal2db_Internal(iValue)
      end

      private

      # Optimize the function internal representation without modifying it.
      def optimize
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          # Join segments that have the same slope
          lNewPoints = [ @Function[:Points][0] ]
          lLastSlope = (@Function[:Points][1][1]-@Function[:Points][0][1])/(@Function[:Points][1][0]-@Function[:Points][0][0])
          lIdxSegment = 1
          while (lIdxSegment < @Function[:Points].size - 1)
            # Compute this segment's slope
            lSlope = (@Function[:Points][lIdxSegment+1][1]-@Function[:Points][lIdxSegment][1])/(@Function[:Points][lIdxSegment+1][0]-@Function[:Points][lIdxSegment][0])
            if (lLastSlope != lSlope)
              # We are changing slopes
              lNewPoints << @Function[:Points][lIdxSegment]
              lLastSlope = lSlope
            end
            lIdxSegment += 1
          end
          # Add last point
          lNewPoints << @Function[:Points][-1]
          # Change points
          @Function[:Points] = lNewPoints
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
        end
      end

      # Convert contained objects into the types used for function values
      def convertDataTypes
        case @Function[:FunctionType]
        when FCTTYPE_PIECEWISE_LINEAR
          @Function[:Points] = @Function[:Points].map do |iPoint|
            lNewPointX = nil
            lNewPointY = nil
            if (iPoint[0].is_a?(Rational))
              lNewPointX = iPoint[0]
            elsif (iPoint[0].is_a?(Float))
              lNewPointX = iPoint[0].to_r
            else
              lNewPointX = Rational(iPoint[0])
            end
            if (iPoint[1].is_a?(Rational))
              lNewPointY = iPoint[1]
            elsif (iPoint[1].is_a?(Float))
              lNewPointY = iPoint[1].to_r
            else
              lNewPointY = Rational(iPoint[1])
            end
            next [ lNewPointX, lNewPointY ]
          end
        else
          logErr "Unknown function type: #{@Function[:FunctionType]}"
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

      # Find abscisses of both functions and the corresponding Y values
      #
      # Parameters:
      # * *iOtherFunction* (_Function_): The other function
      # * *CodeBlock*: Code called for each point found:
      # ** *iX* (_Rational_): The corresponding abscisse (can be nil if none)
      # ** *iY* (_Rational_): The corresponding Y value for this function (can be nil if none)
      # ** *iOtherY* (_Rational_): The corresponding Y value for the other function
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

      # Convert a value to its db notation.
      # Operate on the function values numbers.
      # !!! Prerequisites: The following variables have to be set before calling this function
      # * @Log2: Contains log(2)
      # * @LogMax: Contains log(MaximalValue)
      #
      # Parameters:
      # * *iValue* (_Rational_): The value
      # Return:
      # * _Rational_: Its corresponding db
      def valueVal2db_Internal(iValue)
        if (iValue == 0)
          # -Infinity
          return -1.0/0.0
        else
          return -6*(@LogMax-valueLog(iValue.abs))/@Log2
        end
      end

    end

  end

end
