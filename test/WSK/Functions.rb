module WSKTest

  class Functions < ::Test::Unit::TestCase

    include WSKTest::Common
    include WSK::Common

    # Test that functions can be read from files
    def testReadFromFile
      lFunction = WSK::Functions::Function.new
      lFunction.readFromFile("#{getFilesDir}/Functions/Simple.fct.rb")
      assert_equal( {
        :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
        :Points => [
          [0, 0],
          [1, 2],
          [2, 1]
        ] }, lFunction.functionData)
    end

    # Test that functions can be set directly
    def testSet
      lFunction = WSK::Functions::Function.new
      lFunction.set( {
        :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
        :Points => [
          [0, 0],
          [1, 2],
          [2, 1]
        ] } )
      assert_equal( {
        :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
        :Points => [
          [0, 0],
          [1, 2],
          [2, 1]
        ] }, lFunction.functionData)
    end

    # Test that functions are optimized correctly
    def testSetOptimized
      lFunction = WSK::Functions::Function.new
      lFunction.set( {
        :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
        :Points => [
          [0, 0],
          [1, 1],
          [2, 2]
        ] } )
      assert_equal( {
        :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
        :Points => [
          [0, 0],
          [2, 2]
        ] }, lFunction.functionData)
    end

    # Test that we correctly read peak input volume
    def testReadInput_Peak
      genWave( {
        :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
        :Points => [
          [0, 0],
          [10, 20],
          [20, 10]
        ]
      } ) do |iWaveFileName|
        accessInputWaveFile(iWaveFileName) do |iHeader, iInputData|
          lFunction = WSK::Functions::Function.new
          lFunction.readFromInputVolume(iInputData, 0, 20, 1, 0)
          assert_equal( {
            :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
            :Points => [
              [0, 0],
              [10, 32760],
              [20, 16380]
            ] }, lFunction.functionData)
        end
      end
    end

    # Test that we correctly approximate peak input volume with intervals
    def testReadInput_PeakAverage
      genWave( {
        :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
        :Points => [
          [0, 0],
          [10, 20],
          [20, 10]
        ]
      } ) do |iWaveFileName|
        accessInputWaveFile(iWaveFileName) do |iHeader, iInputData|
          lFunction = WSK::Functions::Function.new
          lFunction.readFromInputVolume(iInputData, 0, 20, 5, 0)
          assert_equal( {
            :FunctionType => WSK::Functions::FCTTYPE_PIECEWISE_LINEAR,
            :Points => [
              [0, 13104],
              [2.5, 13104],
              [7.5, 29484],
              [12.5, 32760],
              [17.5, 24570],
              [20, 16380]
            ] }, lFunction.functionData)
        end
      end
    end

  end

end
