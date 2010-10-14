#include "ruby.h"
#include <math.h>
#include <stdio.h>
#include <CommonUtils.h>

// Struct used to convey data among iterators in the applyVolumeFct method for piecewise linear functions
typedef struct {
  tFunction_PiecewiseLinear* fctData;
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
    lPtrArgs->currentRatio = lPtrArgs->idxPreviousPointY+((iIdxSample-lPtrArgs->idxPreviousPointX)*lPtrArgs->distWithNextY)/lPtrArgs->distWithNextX;
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
  VALUE iValIdxBufferFirstSample) {

  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  tSampleIndex iIdxBufferFirstSample = FIX2LONG(iValIdxBufferFirstSample);
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
      lProcessParams.idxPreviousPoint = 0;
      lProcessParams.idxNextPoint = 1;
      // Compute first cache values
      lProcessParams.idxPreviousPointX = lProcessParams.fctData->pointsX[lProcessParams.idxPreviousPoint];
      lProcessParams.distWithNextX = lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]-lProcessParams.idxPreviousPointX;
      lProcessParams.idxPreviousPointY = lProcessParams.fctData->pointsY[lProcessParams.idxPreviousPoint];
      lProcessParams.distWithNextY = lProcessParams.fctData->pointsY[lProcessParams.idxNextPoint]-lProcessParams.idxPreviousPointY;
      lProcessParams.idxNextSegmentX = lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]+1;
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

// Initialize the module
void Init_VolumeUtils() {
  VALUE lWSKModule = rb_define_module("WSK");
  VALUE lVolumeUtilsModule = rb_define_module_under(lWSKModule, "VolumeUtils");
  VALUE lVolumeUtilsClass = rb_define_class_under(lVolumeUtilsModule, "VolumeUtils", rb_cObject);

  rb_define_method(lVolumeUtilsClass, "applyVolumeFct", volumeutils_applyVolumeFct, 6);
}
