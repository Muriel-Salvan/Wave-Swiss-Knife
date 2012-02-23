#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module WSK

  module Maps

    # Apply map functions to an input data, writing into an output data
    #
    # Parameters::
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
