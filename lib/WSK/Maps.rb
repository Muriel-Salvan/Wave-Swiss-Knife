module WSK

  module Maps

    # Function type piecewise linear.
    # Here are the possible attributes used by this type:
    # *:Scale* (_Integer_): Maximal value of the plots of the function
    # *:Points* (<em>map<Integer,Integer></em>): Coordinates of points indicating each linear part
    FCTTYPE_PIECEWISE_LINEAR = 0

    # Apply map functions to an input data, writing into an output data
    #
    # Parameters:
    # * *iInputData* (<em>WSK::Model::InputData</em>): The input data
    # * *oOutputData* (_Object_): The output data to fill
    # * *iFunctions* (<em>list<map<Symbol,Object>></em>): The functions to apply, per channel
    def applyMapFunctions(iInputData, oOutputData, iFunctions)
      require 'WSK/ArithmUtils/ArithmUtils'
      lArithmUtils = ArithmUtils::ArithmUtils.new
      # Create the map corresponding to the functions
      lMap = lArithmUtils.createMapFromFunctions(iInputData.Header.NbrBitsPerSample, iFunctions)
      # Apply the map
      iInputData.eachRawBuffer do |iInputRawBuffer, iNbrSamples, iNbrChannels|
        oOutputData.pushRawBuffer(lArithmUtils.applyMap(lMap, iInputRawBuffer, iInputData.Header.NbrBitsPerSample, iNbrSamples))
      end
    end

  end

end
