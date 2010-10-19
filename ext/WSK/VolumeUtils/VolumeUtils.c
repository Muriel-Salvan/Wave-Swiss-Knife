#include "ruby.h"
#include <math.h>
#include <stdio.h>
#include <CommonUtils.h>
#include <gmp.h>

// Struct used to convey data among iterators in the applyVolumeFct method for piecewise linear functions
typedef struct {
  tFunction_PiecewiseLinear* fctData;
  int unitDB;
  int idxPreviousPoint;
  int idxNextPoint;
  // Values used to cache segment computations
  // These must be refreshed each time idxPreviousPoint or idxNextPoint is set/changed.
  tSampleIndex idxPreviousPointX;
  tSampleIndex distWithNextX;
  long double idxPreviousPointY;
  long double distWithNextY;
  tSampleIndex idxNextSegmentX;
  // Values used to cache sample computations
  // These must be refreshed each time we change the current sample. They are the same for all the channels of the current sample.
  long double currentRatio;
} tApplyVolumeFctStruct_PiecewiseLinear;

// Struct used to convey data among iterators in the MeasureRMS method
typedef struct {
  mpz_t* squareSums;
  mpz_t tmpInt;
} tMeasureRMSStruct;

/**
 * Process a value read from an input buffer for the applyVolumeFct function in case of piecewise linear function.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tApplyVolumeFctStruct_PiecewiseLinear*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int volumeutils_processValue_applyVolumeFct_PiecewiseLinear(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tApplyVolumeFctStruct_PiecewiseLinear* lPtrArgs = (tApplyVolumeFctStruct_PiecewiseLinear*)iPtrArgs;

  // Change caches if needed
  if (iIdxChannel == 0) {
    if (iIdxSample == lPtrArgs->idxNextSegmentX) {
/*
      printf("[%lld] Changing segment (%lld reached) to [%d - %d] ([%lld - %lld])\n", iIdxSample, lPtrArgs->idxNextSegmentX, lPtrArgs->idxPreviousPoint+1, lPtrArgs->idxNextPoint+1, lPtrArgs->fctData->pointsX[lPtrArgs->idxPreviousPoint+1], lPtrArgs->fctData->pointsX[lPtrArgs->idxNextPoint+1]);
*/
      // Switch to the next segment
      ++lPtrArgs->idxNextPoint;
      ++lPtrArgs->idxPreviousPoint;
      // Compute next cache values
      lPtrArgs->idxPreviousPointX = lPtrArgs->fctData->pointsX[lPtrArgs->idxPreviousPoint];
      lPtrArgs->distWithNextX = lPtrArgs->fctData->pointsX[lPtrArgs->idxNextPoint]-lPtrArgs->idxPreviousPointX;
      lPtrArgs->idxPreviousPointY = lPtrArgs->fctData->pointsY[lPtrArgs->idxPreviousPoint];
      lPtrArgs->distWithNextY = lPtrArgs->fctData->pointsY[lPtrArgs->idxNextPoint]-lPtrArgs->idxPreviousPointY;
      lPtrArgs->idxNextSegmentX = lPtrArgs->fctData->pointsX[lPtrArgs->idxNextPoint]+1;
    }
    // Compute the ratio to apply
    if (lPtrArgs->unitDB == 1) {
      lPtrArgs->currentRatio = pow(2, (lPtrArgs->idxPreviousPointY+((iIdxSample-lPtrArgs->idxPreviousPointX)*lPtrArgs->distWithNextY)/lPtrArgs->distWithNextX)/6);
    } else {
      lPtrArgs->currentRatio = lPtrArgs->idxPreviousPointY+((iIdxSample-lPtrArgs->idxPreviousPointX)*lPtrArgs->distWithNextY)/lPtrArgs->distWithNextX;
    }
/*
    if ((iIdxSample > 26563930) && (iIdxSample < 26563940)) {
      printf("[%lld] idxPreviousPoint=%d idxPreviousPointX=%lld idxPreviousPointY=%Lf idxNextPoint=%d distWithNextX=%lld distWithNextY=%Lf idxNextSegmentX=%lld currentRatio=%Lf\n", iIdxSample, lPtrArgs->idxPreviousPoint, lPtrArgs->idxPreviousPointX, lPtrArgs->idxPreviousPointY, lPtrArgs->idxNextPoint, lPtrArgs->distWithNextX, lPtrArgs->distWithNextY, lPtrArgs->idxNextSegmentX, lPtrArgs->currentRatio);
    }
*/
  }

  // Write the correct value
  (*oPtrValue) = iValue*lPtrArgs->currentRatio;
  
  return 0;
}

/**
 * Apply a function on the volume of an input buffer, and outputs a result buffer.
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValCFunction* (_Object_): The container of the C function (created with createCFunction)
 * * *iValInputBuffer* (_String_): The input buffer
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValNbrSamples* (_Integer_): Number of samples
 * * *iValIdxBufferFirstSample* (_Integer_): Index of the first buffer's sample in the input data
 * * *iValUnitDB* (_Boolean_): Are the units in DB scale ?
 * Return:
 * * _String_: Output buffer
 **/
static VALUE volumeutils_applyVolumeFct(
  VALUE iSelf,
  VALUE iValCFunction,
  VALUE iValInputBuffer,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrChannels,
  VALUE iValNbrSamples,
  VALUE iValIdxBufferFirstSample,
  VALUE iValUnitDB) {
  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  tSampleIndex iIdxBufferFirstSample = FIX2LONG(iValIdxBufferFirstSample);
  int iUnitDB = (iValUnitDB == Qtrue ? 1 : 0);
  // Get the C function
  tFunction* lPtrFct;
  Data_Get_Struct(iValCFunction, tFunction, lPtrFct);
  // Get the input buffer
  char* lPtrRawBuffer = RSTRING(iValInputBuffer)->ptr;
  int lBufferCharSize = RSTRING(iValInputBuffer)->len;
  // Allocate the output buffer
  char* lPtrOutputBuffer = ALLOC_N(char, lBufferCharSize);

  // Call the relevant method based on the type
  switch (lPtrFct->fctType) {
    case FCTTYPE_PIECEWISE_LINEAR: ;
      // Create parameters to give the process
      tApplyVolumeFctStruct_PiecewiseLinear lProcessParams;
      lProcessParams.fctData = lPtrFct->fctData;
      // Find the segment containing iIdxBufferFirstSample
      lProcessParams.idxNextPoint = 0;
      while (lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint] <= iIdxBufferFirstSample) {
        ++lProcessParams.idxNextPoint;
      }
      lProcessParams.idxPreviousPoint = lProcessParams.idxNextPoint - 1;
/*
      printf("Apply on volume starts on sample %lld at segment [%d - %d] (%lld - %lld]).\n", iIdxBufferFirstSample, lProcessParams.idxPreviousPoint, lProcessParams.idxNextPoint, lProcessParams.fctData->pointsX[lProcessParams.idxPreviousPoint], lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]);
*/
      // Compute first cache values
      lProcessParams.idxPreviousPointX = lProcessParams.fctData->pointsX[lProcessParams.idxPreviousPoint];
      lProcessParams.distWithNextX = lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]-lProcessParams.idxPreviousPointX;
      lProcessParams.idxPreviousPointY = lProcessParams.fctData->pointsY[lProcessParams.idxPreviousPoint];
      lProcessParams.distWithNextY = lProcessParams.fctData->pointsY[lProcessParams.idxNextPoint]-lProcessParams.idxPreviousPointY;
      lProcessParams.idxNextSegmentX = lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]+1;
      lProcessParams.unitDB = iUnitDB;
      // Iterate through the raw buffer
      commonutils_iterateThroughRawBufferOutput(
        iSelf,
        lPtrRawBuffer,
        lPtrOutputBuffer,
        iNbrBitsPerSample,
        iNbrChannels,
        iNbrSamples,
        iIdxBufferFirstSample,
        1,
        &volumeutils_processValue_applyVolumeFct_PiecewiseLinear,
        &lProcessParams
      );
      break;
    default: ; // The ; is here to make gcc compile: variables declarations are forbidden after a label.
      char lLogMessage[256];
      sprintf(lLogMessage, "Unknown function type %d", lPtrFct->fctType);
      rb_funcall(iSelf, rb_intern("logErr"), 1, rb_str_new2(lLogMessage));
      break;
  }

  VALUE rValOutputBuffer = rb_str_new(lPtrOutputBuffer, lBufferCharSize);

  free(lPtrOutputBuffer);

  return rValOutputBuffer;
}

/**
 * Process a value read from an input buffer for the MeasureRMS function.
 * Use the trigo cache.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMeasureRMSStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int volumeutils_processValue_MeasureRMS(
  const tSampleValue iValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  // Interpret parameters
  tMeasureRMSStruct* lPtrParams = (tMeasureRMSStruct*)iPtrArgs;

  mpz_set_si(lPtrParams->tmpInt, iValue);
  mpz_addmul(lPtrParams->squareSums[iIdxChannel], lPtrParams->tmpInt, lPtrParams->tmpInt);

  return 0;
}

/**
 * Measure the RMS values of a given raw buffer.
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValInputRawBuffer* (_String_): The input raw buffer
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValNbrSamples* (_Integer_): Number of samples
 * Return:
 * * <em>list<Integer></em>: List of integer values
 **/
static VALUE volumeutils_measureRMS(
  VALUE iSelf,
  VALUE iValInputRawBuffer,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrChannels,
  VALUE iValNbrSamples) {
  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  // Get the input buffer
  char* lPtrRawBuffer = RSTRING(iValInputRawBuffer)->ptr;

  // Allocate the array that will store the square sums
  mpz_t lSquareSums[iNbrChannels];
  int lIdxChannel;
  for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
    mpz_init(lSquareSums[lIdxChannel]);
  }

  // Parse the data
  tMeasureRMSStruct lParams;
  lParams.squareSums = lSquareSums;
  mpz_init(lParams.tmpInt);
  commonutils_iterateThroughRawBuffer(
    lPtrRawBuffer,
    iNbrBitsPerSample,
    iNbrChannels,
    iNbrSamples,
    0,
    &volumeutils_processValue_MeasureRMS,
    &lParams
  );
  mpz_clear(lParams.tmpInt);

  // Build the resulting array
  VALUE lRMSValues[iNbrChannels];
  // Buffer that stores string representation of mpz_t for Ruby RBigNum
  char lStrValue[128];
  for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
    mpz_cdiv_q_ui(lSquareSums[lIdxChannel], lSquareSums[lIdxChannel], iNbrSamples);
    mpz_sqrt(lSquareSums[lIdxChannel], lSquareSums[lIdxChannel]);
    lRMSValues[lIdxChannel] = rb_cstr2inum(mpz_get_str(lStrValue, 16, lSquareSums[lIdxChannel]), 16);
    mpz_clear(lSquareSums[lIdxChannel]);
  }

  return rb_ary_new4(iNbrChannels, lRMSValues);
}

// Initialize the module
void Init_VolumeUtils() {
  VALUE lWSKModule = rb_define_module("WSK");
  VALUE lVolumeUtilsModule = rb_define_module_under(lWSKModule, "VolumeUtils");
  VALUE lVolumeUtilsClass = rb_define_class_under(lVolumeUtilsModule, "VolumeUtils", rb_cObject);

  rb_define_method(lVolumeUtilsClass, "applyVolumeFct", volumeutils_applyVolumeFct, 7);
  rb_define_method(lVolumeUtilsClass, "measureRMS", volumeutils_measureRMS, 4);
}
