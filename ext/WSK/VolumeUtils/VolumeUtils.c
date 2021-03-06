/**
 * Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
 * Licensed under the terms specified in LICENSE file. No warranty is provided.
 **/

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
  int idxLastPoint;
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

// Struct used to convey data among iterators in the drawVolumeFct method for piecewise linear functions
typedef struct {
  tFunction_PiecewiseLinear* fctData;
  int unitDB;
  int idxPreviousPoint;
  int idxNextPoint;
  int idxLastPoint;
  tSampleValue medianValue;
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
} tDrawVolumeFctStruct_PiecewiseLinear;

// Struct used to convey data among iterators in the MeasureLevel method
typedef struct {
  mpz_t* squareSums;
  tSampleValue* maxAbsValue;
  mpz_t tmpInt;
} tMeasureLevelStruct;

/**
 * Process a value read from an input buffer for the applyVolumeFct function in case of piecewise linear function.
 *
 * Parameters::
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tApplyVolumeFctStruct_PiecewiseLinear*</em>.
 * Return::
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
    // Switch to the next segment if we arrived at the end and it is the last one
    if ((iIdxSample == lPtrArgs->idxNextSegmentX) &&
        (lPtrArgs->idxNextPoint != lPtrArgs->idxLastPoint)) {
/*
      printf("[%lld] Changing segment (%lld reached) to [%d - %d] ([%lld - %lld])\n", iIdxSample, lPtrArgs->idxNextSegmentX, lPtrArgs->idxPreviousPoint+1, lPtrArgs->idxNextPoint+1, lPtrArgs->fctData->pointsX[lPtrArgs->idxPreviousPoint+1], lPtrArgs->fctData->pointsX[lPtrArgs->idxNextPoint+1]);
*/
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
 * Parameters::
 * * *iSelf* (_FFT_): Self
 * * *iValCFunction* (_Object_): The container of the C function (created with createCFunction)
 * * *iValInputBuffer* (_String_): The input buffer
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValNbrSamples* (_Integer_): Number of samples
 * * *iValIdxBufferFirstSample* (_Integer_): Index of the first buffer's sample in the input data
 * * *iValUnitDB* (_Boolean_): Are the units in DB scale ?
 * Return::
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
  char* lPtrRawBuffer = RSTRING_PTR(iValInputBuffer);
  int lBufferCharSize = RSTRING_LEN(iValInputBuffer);
  // Allocate the output buffer
  char* lPtrOutputBuffer = ALLOC_N(char, lBufferCharSize);

  // Call the relevant method based on the type
  switch (lPtrFct->fctType) {
    case FCTTYPE_PIECEWISE_LINEAR: ;
      // Create parameters to give the process
      tApplyVolumeFctStruct_PiecewiseLinear lProcessParams;
      lProcessParams.fctData = lPtrFct->fctData;
      lProcessParams.idxLastPoint = lProcessParams.fctData->nbrPoints-1;
      lProcessParams.unitDB = iUnitDB;
      // Find the segment containing iIdxBufferFirstSample
      lProcessParams.idxNextPoint = 0;
      while (lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint] <= iIdxBufferFirstSample) {
        ++lProcessParams.idxNextPoint;
      }
      lProcessParams.idxPreviousPoint = lProcessParams.idxNextPoint - 1;
      // Special case for the last segment
      if (lProcessParams.idxNextPoint == lProcessParams.idxLastPoint + 1) {
        --lProcessParams.idxNextPoint;
      }
/*
      printf("Apply on volume starts on sample %lld at segment [%d - %d] (%lld - %lld]).\n", iIdxBufferFirstSample, lProcessParams.idxPreviousPoint, lProcessParams.idxNextPoint, lProcessParams.fctData->pointsX[lProcessParams.idxPreviousPoint], lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]);
*/
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
      rb_funcall(iSelf, rb_intern("log_err"), 1, rb_str_new2(lLogMessage));
      break;
  }

  VALUE rValOutputBuffer = rb_str_new(lPtrOutputBuffer, lBufferCharSize);

  free(lPtrOutputBuffer);

  return rValOutputBuffer;
}

/**
 * Process a value read from an input buffer for the drawVolumeFct function in case of piecewise linear function.
 *
 * Parameters::
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tApplyVolumeFctStruct_PiecewiseLinear*</em>.
 * Return::
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int volumeutils_processValue_drawVolumeFct_PiecewiseLinear(
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tDrawVolumeFctStruct_PiecewiseLinear* lPtrArgs = (tDrawVolumeFctStruct_PiecewiseLinear*)iPtrArgs;

  // Change caches if needed
  if (iIdxChannel == 0) {
    // Switch to the next segment if we arrived at the end and it is the last one
    if ((iIdxSample == lPtrArgs->idxNextSegmentX) &&
        (lPtrArgs->idxNextPoint != lPtrArgs->idxLastPoint)) {
/*
      printf("[%lld] Changing segment (%lld reached) to [%d - %d] ([%lld - %lld])\n", iIdxSample, lPtrArgs->idxNextSegmentX, lPtrArgs->idxPreviousPoint+1, lPtrArgs->idxNextPoint+1, lPtrArgs->fctData->pointsX[lPtrArgs->idxPreviousPoint+1], lPtrArgs->fctData->pointsX[lPtrArgs->idxNextPoint+1]);
*/
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
    if ((iIdxSample > 15) && (iIdxSample < 25)) {
      printf("[%lld] idxPreviousPoint=%d idxPreviousPointX=%lld idxPreviousPointY=%Lf idxNextPoint=%d distWithNextX=%lld distWithNextY=%Lf idxNextSegmentX=%lld idxLastPoint=%d currentRatio=%Lf\n", iIdxSample, lPtrArgs->idxPreviousPoint, lPtrArgs->idxPreviousPointX, lPtrArgs->idxPreviousPointY, lPtrArgs->idxNextPoint, lPtrArgs->distWithNextX, lPtrArgs->distWithNextY, lPtrArgs->idxNextSegmentX, lPtrArgs->idxLastPoint, lPtrArgs->currentRatio);
    }
*/
}

  // Write the correct value
  (*oPtrValue) = (lPtrArgs->medianValue)*(lPtrArgs->currentRatio);

  return 0;
}

/**
 * Draw a function on an output buffer.
 *
 * Parameters::
 * * *iSelf* (_FFT_): Self
 * * *iValCFunction* (_Object_): The container of the C function (created with createCFunction)
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValNbrSamples* (_Integer_): Number of samples
 * * *iValIdxBufferFirstSample* (_Integer_): Index of the first buffer's sample in the input data
 * * *iValUnitDB* (_Boolean_): Are the units in DB scale ?
 * * *iValMedianValue* (_Integer_): Sample value to take as the reference to draw the function
 * Return::
 * * _String_: Output buffer
 **/
static VALUE volumeutils_drawVolumeFct(
  VALUE iSelf,
  VALUE iValCFunction,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrChannels,
  VALUE iValNbrSamples,
  VALUE iValIdxBufferFirstSample,
  VALUE iValUnitDB,
  VALUE iValMedianValue) {
  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  tSampleIndex iIdxBufferFirstSample = FIX2LONG(iValIdxBufferFirstSample);
  int iUnitDB = (iValUnitDB == Qtrue ? 1 : 0);
  tSampleValue iMedianValue = FIX2LONG(iValMedianValue);
  // Get the C function
  tFunction* lPtrFct;
  Data_Get_Struct(iValCFunction, tFunction, lPtrFct);
  int lBufferCharSize = (iNbrSamples*iNbrChannels*iNbrBitsPerSample)/8;
  // Allocate the output buffer
  char* lPtrOutputBuffer = ALLOC_N(char, lBufferCharSize);

  // Call the relevant method based on the type
  switch (lPtrFct->fctType) {
    case FCTTYPE_PIECEWISE_LINEAR: ;
      // Create parameters to give the process
      tDrawVolumeFctStruct_PiecewiseLinear lProcessParams;
      lProcessParams.fctData = lPtrFct->fctData;
      lProcessParams.medianValue = iMedianValue;
      lProcessParams.idxLastPoint = lProcessParams.fctData->nbrPoints-1;
      lProcessParams.unitDB = iUnitDB;
      // Find the segment containing iIdxBufferFirstSample
      lProcessParams.idxNextPoint = 0;
      while (lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint] <= iIdxBufferFirstSample) {
        ++lProcessParams.idxNextPoint;
      }
      // Special case for the last segment
      if (lProcessParams.idxNextPoint == lProcessParams.idxLastPoint + 1) {
        --lProcessParams.idxNextPoint;
      }
      lProcessParams.idxPreviousPoint = lProcessParams.idxNextPoint - 1;
      // Compute first cache values
      lProcessParams.idxPreviousPointX = lProcessParams.fctData->pointsX[lProcessParams.idxPreviousPoint];
      lProcessParams.distWithNextX = lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]-lProcessParams.idxPreviousPointX;
      lProcessParams.idxPreviousPointY = lProcessParams.fctData->pointsY[lProcessParams.idxPreviousPoint];
      lProcessParams.distWithNextY = lProcessParams.fctData->pointsY[lProcessParams.idxNextPoint]-lProcessParams.idxPreviousPointY;
      lProcessParams.idxNextSegmentX = lProcessParams.fctData->pointsX[lProcessParams.idxNextPoint]+1;
      // Iterate through the raw buffer
      commonutils_iterateThroughRawBufferOutputOnly(
        iSelf,
        lPtrOutputBuffer,
        iNbrBitsPerSample,
        iNbrChannels,
        iNbrSamples,
        iIdxBufferFirstSample,
        1,
        &volumeutils_processValue_drawVolumeFct_PiecewiseLinear,
        &lProcessParams
      );
      break;
    default: ; // The ; is here to make gcc compile: variables declarations are forbidden after a label.
      char lLogMessage[256];
      sprintf(lLogMessage, "Unknown function type %d", lPtrFct->fctType);
      rb_funcall(iSelf, rb_intern("log_err"), 1, rb_str_new2(lLogMessage));
      break;
  }

  VALUE rValOutputBuffer = rb_str_new(lPtrOutputBuffer, lBufferCharSize);

  free(lPtrOutputBuffer);

  return rValOutputBuffer;
}

/**
 * Process a value read from an input buffer for the MeasureLevel function.
 * Use the trigo cache.
 *
 * Parameters::
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMeasureLevelStruct*</em>.
 * Return::
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int volumeutils_processValue_MeasureLevel(
  const tSampleValue iValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  // Interpret parameters
  tMeasureLevelStruct* lPtrParams = (tMeasureLevelStruct*)iPtrArgs;

  // RMS computation
  mpz_set_si(lPtrParams->tmpInt, iValue);
  mpz_addmul(lPtrParams->squareSums[iIdxChannel], lPtrParams->tmpInt, lPtrParams->tmpInt);
  // Peak computation
  if (abs(iValue) > lPtrParams->maxAbsValue[iIdxChannel]) {
    lPtrParams->maxAbsValue[iIdxChannel] = abs(iValue);
  }


  return 0;
}

/**
 * Measure the Level values of a given raw buffer.
 *
 * Parameters::
 * * *iSelf* (_FFT_): Self
 * * *iValInputRawBuffer* (_String_): The input raw buffer
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValNbrSamples* (_Integer_): Number of samples
 * * *iValRMSRatio* (_Float_): Ratio of RMS measure vs Peak level measure
 * Return::
 * * <em>list<Integer></em>: List of integer values
 **/
static VALUE volumeutils_measureLevel(
  VALUE iSelf,
  VALUE iValInputRawBuffer,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrChannels,
  VALUE iValNbrSamples,
  VALUE iValRMSRatio) {
  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  double iRMSRatio = NUM2DBL(iValRMSRatio);
  // Get the input buffer
  char* lPtrRawBuffer = RSTRING_PTR(iValInputRawBuffer);

  // Allocate the array that will store the square sums
  mpz_t lSquareSums[iNbrChannels];
  // The array that will store the maximal absolute values
  tSampleValue lMaxAbsValues[iNbrChannels];
  // Initialize everything
  int lIdxChannel;
  for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
    mpz_init(lSquareSums[lIdxChannel]);
    lMaxAbsValues[lIdxChannel] = 0;
  }

  // Parse the data
  tMeasureLevelStruct lParams;
  lParams.squareSums = lSquareSums;
  lParams.maxAbsValue = lMaxAbsValues;
  mpz_init(lParams.tmpInt);
  commonutils_iterateThroughRawBuffer(
    lPtrRawBuffer,
    iNbrBitsPerSample,
    iNbrChannels,
    iNbrSamples,
    0,
    &volumeutils_processValue_MeasureLevel,
    &lParams
  );
  mpz_clear(lParams.tmpInt);

  // Build the resulting array
  VALUE lLevelValues[iNbrChannels];
  // Buffer that stores string representation of mpz_t for Ruby RBigNum
  char lStrValue[128];
  // Temporary variables needed
  mpf_t lRMSCoeff;
  mpf_t lPeakCoeff;
  mpf_t lRMSRatio;
  mpf_t lPeakRatio;
  mpz_t lLevel;
  mpf_init(lRMSCoeff);
  mpf_init(lPeakCoeff);
  mpf_init_set_d(lRMSRatio, iRMSRatio);
  mpf_init_set_d(lPeakRatio, 1.0-iRMSRatio);
  mpz_init(lLevel);
  for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
    // Finalize computing the RMS value using a float
    mpf_set_z(lRMSCoeff, lSquareSums[lIdxChannel]);
    mpf_div_ui(lRMSCoeff, lRMSCoeff, iNbrSamples);
    mpf_sqrt(lRMSCoeff, lRMSCoeff);
    // Mix RMS and Peak levels according to the ratio
    mpf_mul(lRMSCoeff, lRMSCoeff, lRMSRatio);
    mpf_set_ui(lPeakCoeff, lMaxAbsValues[lIdxChannel]);
    mpf_mul(lPeakCoeff, lPeakCoeff, lPeakRatio);
    // Use lRMSCoeff to contain the result
    mpf_add(lRMSCoeff, lRMSCoeff, lPeakCoeff);
    mpz_set_f(lLevel, lRMSCoeff);
    lLevelValues[lIdxChannel] = rb_cstr2inum(mpz_get_str(lStrValue, 16, lLevel), 16);
    mpz_clear(lSquareSums[lIdxChannel]);
  }
  mpz_clear(lLevel);
  mpf_clear(lPeakRatio);
  mpf_clear(lRMSRatio);
  mpf_clear(lPeakCoeff);
  mpf_clear(lRMSCoeff);

  return rb_ary_new4(iNbrChannels, lLevelValues);
}

// Initialize the module
void Init_VolumeUtils() {
  VALUE lWSKModule = rb_define_module("WSK");
  VALUE lVolumeUtilsModule = rb_define_module_under(lWSKModule, "VolumeUtils");
  VALUE lVolumeUtilsClass = rb_define_class_under(lVolumeUtilsModule, "VolumeUtils", rb_cObject);

  rb_define_method(lVolumeUtilsClass, "applyVolumeFct", volumeutils_applyVolumeFct, 7);
  rb_define_method(lVolumeUtilsClass, "drawVolumeFct", volumeutils_drawVolumeFct, 7);
  rb_define_method(lVolumeUtilsClass, "measureLevel", volumeutils_measureLevel, 5);
}
