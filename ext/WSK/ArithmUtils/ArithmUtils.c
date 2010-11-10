/**
 * Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
 * Licensed under the terms specified in LICENSE file. No warranty is provided.
 **/

#include "ruby.h"
#include <math.h>
#include <stdio.h>
#include <CommonUtils.h>
#include <gmp.h>

// Struct used to store a map
typedef struct {
  // Number of channels
  int nbrChannels;
  // Are there some values that can exceed the values range ? 0 = No 1 = Yes.
  int possibleExceedValues;
  // The map
  tSampleValue** map;
} tMap;

// Struct used to convey data among iterators in the applyMap method
typedef struct {
  unsigned int offsetIdxMap;
  tSampleValue** map;
} tApplyMapStruct;

// Struct used to store info about a buffer
typedef struct {
  // All buffers point on the same data at the beginning of the iterations
  unsigned char* buffer_8bits;
  signed short int* buffer_16bits;
  t24bits* buffer_24bits;
  tSampleIndex nbrBufferSamples;
  long double coeff;
} tBufferInfo;

// Struct used to convey data among iterators in the Mix method
typedef struct {
  tBufferInfo* lstBuffers;
  int nbrActiveBuffers;
  long double mainCoeff;
  // Temporary attributes
  long double tmpValue;
  int idxBuffer;
} tMixStruct;

// Struct used to convey data among iterators in the Compare method
typedef struct {
  unsigned char* buffer2_8bits;
  signed short int* buffer2_16bits;
  t24bits* buffer2_24bits;
  long double coeffDiff;
  tSampleValue* map;
  tSampleValue mapOffset;
  VALUE self;
  mpz_t cumulativeErrors;
} tCompareStruct;

/**
 * Free a map.
 * This method is called by Ruby GC.
 *
 * Parameters:
 * * *iPtrMap* (<em>void*</em>): The trigo cache to free (in fact a <em>tMap*</em>)
 */
static void arithmutils_freeMap(void* iPtrMap) {
  tMap* lPtrMap = (tMap*)iPtrMap;

  int lIdxChannel;
  for (lIdxChannel = 0; lIdxChannel < lPtrMap->nbrChannels; ++lIdxChannel) {
    // Free it
    free(lPtrMap->map[lIdxChannel]);
  }
  free(lPtrMap->map);
}

/**
 * Fill a channel map with a given function of type Piecewise Linear
 *
 * Parameters:
 * * *iNbrBitsPerSample* (<em>const int</em>): Number of bits per sample
 * * *oPtrChannelMap* (<em>int*</em>): The channel map to fill
 * * *iValFunction* (<em>map<Symbol,Object></em>): The function to apply
 * Return:
 * * _int_: Result code:
 * ** *0*: The map never exceeds limits
 * ** *1*: The map can exceed limits
 * ** *2*: An error occurred
 */
static int arithmutils_fillMap_PiecewiseLinear(
  const int iNbrBitsPerSample,
  int* oPtrChannelMap,
  VALUE iValFunction) {
  int rResultCode = 0;

  // Read points in a sorted list of couples [x,y]
  VALUE lValSortedPoints = rb_funcall(rb_funcall(rb_hash_aref(iValFunction, ID2SYM(rb_intern("Points"))), rb_intern("to_a"), 0), rb_intern("sort"), 0);
  int lNbrPoints = RARRAY(lValSortedPoints)->len;
  // Read the scale min and max values
  long long int lMinScale = FIX2INT(rb_hash_aref(iValFunction, ID2SYM(rb_intern("MinValue"))));
  long long int lMaxScale = FIX2INT(rb_hash_aref(iValFunction, ID2SYM(rb_intern("MaxValue"))));
  long long int lDiffScale = lMaxScale - lMinScale;
  
  // Compute the limits
  long long int lMaxValue = (1 << (iNbrBitsPerSample-1)) - 1;
  long long int lMinValue = -(1 << (iNbrBitsPerSample-1));
  long long int lDiffValue = lMaxValue - lMinValue;
  int lIdxMapOffset = 1 << (iNbrBitsPerSample-1);

  // Variables to be used in loops
  int lIdxPoint;
  VALUE lValPreviousPoint;
  long double lPreviousPointX;
  long double lPreviousPointY;
  VALUE lValNextPoint;
  long double lNextPointX;
  long double lNextPointY;
  long double lDiffX;
  long double lDiffY;
  int lIdxValue;
  long long int lNewValue;

  // Loop on each points pair
  for (lIdxPoint = 0; lIdxPoint < lNbrPoints-1; ++lIdxPoint) {
    // Compute coordinates at the scale
    lValPreviousPoint = rb_ary_entry(lValSortedPoints, lIdxPoint);
    lPreviousPointX = lMinValue + (lDiffValue*(FIX2LONG(rb_ary_entry(lValPreviousPoint, 0)) - lMinScale))/lDiffScale;
    lPreviousPointY = lMinValue + (lDiffValue*(FIX2LONG(rb_ary_entry(lValPreviousPoint, 1)) - lMinScale))/lDiffScale;
    lValNextPoint = rb_ary_entry(lValSortedPoints, lIdxPoint+1);
    lNextPointX = lMinValue + (lDiffValue*(FIX2LONG(rb_ary_entry(lValNextPoint, 0)) - lMinScale))/lDiffScale;
    lNextPointY = lMinValue + (lDiffValue*(FIX2LONG(rb_ary_entry(lValNextPoint, 1)) - lMinScale))/lDiffScale;
    lDiffX = lNextPointX - lPreviousPointX;
    lDiffY = lNextPointY - lPreviousPointY;
/*
    printf("NOSCALE lPreviousPoint=%ld,%ld lNextPoint=%ld,%ld\n", FIX2LONG(rb_ary_entry(lValPreviousPoint, 0)), FIX2LONG(rb_ary_entry(lValPreviousPoint, 1)), FIX2LONG(rb_ary_entry(lValNextPoint, 0)), FIX2LONG(rb_ary_entry(lValNextPoint, 1)));
    printf("NOSCALE lMinScale=%lld lDiffScale=%lld\n", lMinScale, lDiffScale);
    printf("lPreviousPoint=%Lf,%Lf lNextPoint=%Lf,%Lf\n", lPreviousPointX, lPreviousPointY, lNextPointX, lNextPointY);
    printf("lMinValue=%lld lDiffValue=%lld\n", lMinValue, lDiffValue);
*/
    // Fill the part of the channel map between these 2 points
    for (lIdxValue = lPreviousPointX; lIdxValue <= lNextPointX; ++lIdxValue) {
      lNewValue = lPreviousPointY + round((lDiffY*(((long double)lIdxValue) - lPreviousPointX))/lDiffX);
/*
      if (abs(lIdxValue) <= 10) {
        printf("lIdxValue=%d lNewValue=%lld\n", lIdxValue, lNewValue);
      }
*/
      if ((lNewValue > lMaxValue) ||
          (lNewValue < lMinValue)) {
        rResultCode = 1;
      }
      oPtrChannelMap[lIdxValue+lIdxMapOffset] = lNewValue;
    }
  }

  return rResultCode;
}

/**
 * Fill a channel map with a given function
 *
 * Parameters:
 * * *iSelf* (_Object_): Calling object
 * * *iNbrBitsPerSample* (<em>const int</em>): Number of bits per sample
 * * *oPtrChannelMap* (<em>int*</em>): The channel map to fill
 * * *iValFunction* (<em>map<Symbol,Object></em>): The function to apply
 * Return:
 * * _int_: Result code:
 * ** *0*: The map never exceeds limits
 * ** *1*: The map can exceed limits
 * ** *2*: An error occurred
 */
static int arithmutils_fillMapWithFunction(
  VALUE iSelf,
  const int iNbrBitsPerSample,
  int* oPtrChannelMap,
  VALUE iValFunction) {
  int rResultCode = 0;

  // Retrieve the function type
  int lFunctionType = FIX2INT(rb_hash_aref(iValFunction, ID2SYM(rb_intern("FunctionType"))));
  // Call the relevant method based on the type
  switch (lFunctionType) {
    case FCTTYPE_PIECEWISE_LINEAR:
      rResultCode = arithmutils_fillMap_PiecewiseLinear(iNbrBitsPerSample, oPtrChannelMap, iValFunction);
      break;
    default: ; // The ; is here to make gcc compile: variables declarations are forbidden after a label.
      char lLogMessage[256];
      sprintf(lLogMessage, "Unknown function type %d", lFunctionType);
      rb_funcall(iSelf, rb_intern("logWarn"), 1, rb_str_new2(lLogMessage));
      rResultCode = 2;
      break;
  }

  return rResultCode;
}

/**
 * Create a map from a list of functions.
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValFunctions* (<em>list<map<Symbol,Object>></em>): List of functions, per channel
 * Return:
 * * _Object_: Container of the map
 **/
static VALUE arithmutils_createMapFromFunctions(
  VALUE iSelf,
  VALUE iValNbrBitsPerSample,
  VALUE iValFunctions) {
  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int lNbrChannels = RARRAY(iValFunctions)->len;

  int lIdxChannel;
  int* lPtrChannelMap;
  int lNbrDifferentValues = 1 << iNbrBitsPerSample;
  // The map
  tMap* lPtrMap = ALLOC(tMap);
  lPtrMap->nbrChannels = lNbrChannels;
  lPtrMap->possibleExceedValues = 0;
  lPtrMap->map = ALLOC_N(int*, lNbrChannels);
  for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
    lPtrChannelMap = ALLOC_N(int, lNbrDifferentValues);
    if (arithmutils_fillMapWithFunction(iSelf, iNbrBitsPerSample, lPtrChannelMap, rb_ary_entry(iValFunctions, lIdxChannel)) == 1) {
      lPtrMap->possibleExceedValues = 1;
    }
    lPtrMap->map[lIdxChannel] = lPtrChannelMap;
  }

  return Data_Wrap_Struct(rb_cObject, NULL, arithmutils_freeMap, lPtrMap);
}

/**
 * Process a value read from an input buffer for the applyMap function.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tApplyMapStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int arithmutils_processValue_applyMap(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {

  (*oPtrValue) = ((tApplyMapStruct*)iPtrArgs)->map[iIdxChannel][iValue + ((tApplyMapStruct*)iPtrArgs)->offsetIdxMap];

  return 0;
}

/**
 * Apply a map on an input buffer, and outputs a result buffer.
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValMap* (_Object_): The container of the map
 * * *iValInputBuffer* (_String_): The input buffer
 * * *iValNbrSamples* (_Integer_): Number of samples from the buffer
 * Return:
 * * _String_: Output buffer
 **/
static VALUE arithmutils_applyMap(
  VALUE iSelf,
  VALUE iValMap,
  VALUE iValInputBuffer,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrSamples) {
  // Translate Ruby objects
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  // Get the map
  tMap* lPtrMap;
  Data_Get_Struct(iValMap, tMap, lPtrMap);

  // Get the input buffer
  char* lPtrRawBuffer = RSTRING(iValInputBuffer)->ptr;
  int lBufferCharSize = RSTRING(iValInputBuffer)->len;
  // Allocate the output buffer
  char* lPtrOutputBuffer = ALLOC_N(char, lBufferCharSize);

  // Create parameters to give the process
  tApplyMapStruct lProcessParams;
  lProcessParams.offsetIdxMap = 1 << (iNbrBitsPerSample-1);
  lProcessParams.map = lPtrMap->map;

  // Iterate through the raw buffer
  commonutils_iterateThroughRawBufferOutput(
    iSelf,
    lPtrRawBuffer,
    lPtrOutputBuffer,
    iNbrBitsPerSample,
    lPtrMap->nbrChannels,
    iNbrSamples,
    0,
    lPtrMap->possibleExceedValues,
    &arithmutils_processValue_applyMap,
    &lProcessParams
  );

  VALUE rValOutputBuffer = rb_str_new(lPtrOutputBuffer, lBufferCharSize);

  free(lPtrOutputBuffer);

  return rValOutputBuffer;
}

/**
 * Process a value read from an input buffer for the mix function.
 * Optimized for 8 bits samples.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMixStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int arithmutils_processValue_mix_8bits(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tMixStruct* lPtrParams = (tMixStruct*)iPtrArgs;

  if (lPtrParams->nbrActiveBuffers > 0) {
    // Check if we hit the limit of the last active buffer (the one having the least samples)
    if (iIdxSample == lPtrParams->lstBuffers[lPtrParams->nbrActiveBuffers-1].nbrBufferSamples) {
      // We have to check the buffers that are to be removed
      lPtrParams->idxBuffer = lPtrParams->nbrActiveBuffers-1;
      while ((lPtrParams->idxBuffer >= 0) &&
             (lPtrParams->lstBuffers[lPtrParams->idxBuffer].nbrBufferSamples == iIdxSample )) {
        --lPtrParams->nbrActiveBuffers;
        --lPtrParams->idxBuffer;
      }
    }
    // We have to mix several buffers
    lPtrParams->tmpValue = ((long double)iValue)*lPtrParams->mainCoeff;
    for (lPtrParams->idxBuffer = 0; lPtrParams->idxBuffer < lPtrParams->nbrActiveBuffers; ++lPtrParams->idxBuffer) {
      lPtrParams->tmpValue += (((long double)*(lPtrParams->lstBuffers[lPtrParams->idxBuffer].buffer_8bits))-128)*lPtrParams->lstBuffers[lPtrParams->idxBuffer].coeff;
      ++lPtrParams->lstBuffers[lPtrParams->idxBuffer].buffer_8bits;
    }
    // Export the result
    (*oPtrValue) = round(lPtrParams->tmpValue);
  } else {
    // There is only the main buffer remaining
    (*oPtrValue) = round(((long double)iValue)*lPtrParams->mainCoeff);
  }

  return 0;
}

/**
 * Process a value read from an input buffer for the mix function.
 * Optimized for 16 bits samples.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMixStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int arithmutils_processValue_mix_16bits(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tMixStruct* lPtrParams = (tMixStruct*)iPtrArgs;

  if (lPtrParams->nbrActiveBuffers > 0) {
    // Check if we hit the limit of the last active buffer (the one having the least samples)
    if (iIdxSample == lPtrParams->lstBuffers[lPtrParams->nbrActiveBuffers-1].nbrBufferSamples) {
      // We have to check the buffers that are to be removed
      lPtrParams->idxBuffer = lPtrParams->nbrActiveBuffers-1;
      while ((lPtrParams->idxBuffer >= 0) &&
             (lPtrParams->lstBuffers[lPtrParams->idxBuffer].nbrBufferSamples == iIdxSample )) {
        --lPtrParams->nbrActiveBuffers;
        --lPtrParams->idxBuffer;
      }
    }
    // We have to mix several buffers
    lPtrParams->tmpValue = ((long double)iValue)*lPtrParams->mainCoeff;
    for (lPtrParams->idxBuffer = 0; lPtrParams->idxBuffer < lPtrParams->nbrActiveBuffers; ++lPtrParams->idxBuffer) {
      lPtrParams->tmpValue += ((long double)*(lPtrParams->lstBuffers[lPtrParams->idxBuffer].buffer_16bits))*lPtrParams->lstBuffers[lPtrParams->idxBuffer].coeff;
      ++lPtrParams->lstBuffers[lPtrParams->idxBuffer].buffer_16bits;
    }
    // Export the result
    (*oPtrValue) = round(lPtrParams->tmpValue);
  } else {
    // There is only the main buffer remaining
    (*oPtrValue) = round(((long double)iValue)*lPtrParams->mainCoeff);
  }

  return 0;
}

/**
 * Process a value read from an input buffer for the mix function.
 * Optimized for 8 bits samples.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMixStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int arithmutils_processValue_mix_24bits(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tMixStruct* lPtrParams = (tMixStruct*)iPtrArgs;

  if (lPtrParams->nbrActiveBuffers > 0) {
    // Check if we hit the limit of the last active buffer (the one having the least samples)
    if (iIdxSample == lPtrParams->lstBuffers[lPtrParams->nbrActiveBuffers-1].nbrBufferSamples) {
      // We have to check the buffers that are to be removed
      lPtrParams->idxBuffer = lPtrParams->nbrActiveBuffers-1;
      while ((lPtrParams->idxBuffer >= 0) &&
             (lPtrParams->lstBuffers[lPtrParams->idxBuffer].nbrBufferSamples == iIdxSample )) {
        --lPtrParams->nbrActiveBuffers;
        --lPtrParams->idxBuffer;
      }
    }
    // We have to mix several buffers
    lPtrParams->tmpValue = ((long double)iValue)*lPtrParams->mainCoeff;
    for (lPtrParams->idxBuffer = 0; lPtrParams->idxBuffer < lPtrParams->nbrActiveBuffers; ++lPtrParams->idxBuffer) {
      lPtrParams->tmpValue += ((long double)(lPtrParams->lstBuffers[lPtrParams->idxBuffer].buffer_24bits->value))*lPtrParams->lstBuffers[lPtrParams->idxBuffer].coeff;
      lPtrParams->lstBuffers[lPtrParams->idxBuffer].buffer_24bits = (t24bits*)(((int)lPtrParams->lstBuffers[lPtrParams->idxBuffer].buffer_24bits)+3);
    }
    // Export the result
    (*oPtrValue) = round(lPtrParams->tmpValue);
  } else {
    // There is only the main buffer remaining
    (*oPtrValue) = round(((long double)iValue)*lPtrParams->mainCoeff);
  }

  return 0;
}

/**
 * Mix a list of buffers.
 * Prerequisite: The list of buffers have to be sorted, from the one having the more samples to the one having the less.
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValBuffers* (<em>list<list<Object>></em>): The list of buffers and their associated info (see Mix.rb for details)
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * Return:
 * * _String_: Output buffer
 * * _Integer_: Number of samples written
 **/
static VALUE arithmutils_mixBuffers(
  VALUE iSelf,
  VALUE iValBuffers,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrChannels) {
  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int iNbrChannels = FIX2INT(iValNbrChannels);

  // Create the list of additional buffers to consider
  // This list is sorted from the one having the most samples to the one having the least samples
  int lNbrBuffers = RARRAY(iValBuffers)->len;
  tBufferInfo lPtrAdditionalBuffers[lNbrBuffers-1];
  int lIdxBuffer;
  VALUE lValBufferInfo;
  char* lPtrBuffer;
  for (lIdxBuffer = 0; lIdxBuffer < lNbrBuffers-1 ; ++lIdxBuffer) {
    lValBufferInfo = rb_ary_entry(iValBuffers, lIdxBuffer+1);
    lPtrBuffer = RSTRING(rb_ary_entry(lValBufferInfo, 3))->ptr;
    lPtrAdditionalBuffers[lIdxBuffer].coeff = NUM2DBL(rb_ary_entry(lValBufferInfo, 2));
    lPtrAdditionalBuffers[lIdxBuffer].buffer_8bits = (unsigned char*)lPtrBuffer;
    lPtrAdditionalBuffers[lIdxBuffer].buffer_16bits = (signed short int*)lPtrBuffer;
    lPtrAdditionalBuffers[lIdxBuffer].buffer_24bits = (t24bits*)lPtrBuffer;
    lPtrAdditionalBuffers[lIdxBuffer].nbrBufferSamples = FIX2INT(rb_ary_entry(lValBufferInfo, 4));
  }

  // Get the first buffer: the one that has the most samples
  VALUE lValFirstBufferInfo = rb_ary_entry(iValBuffers, 0);
  VALUE lValFirstBuffer = rb_ary_entry(lValFirstBufferInfo, 3);
  char* lPtrFirstBuffer = RSTRING(lValFirstBuffer)->ptr;
  int lBufferCharSize = RSTRING(lValFirstBuffer)->len;
  tSampleIndex lNbrSamples = FIX2INT(rb_ary_entry(lValFirstBufferInfo, 4));

  // Allocate the output buffer
  char* lPtrOutputBuffer = ALLOC_N(char, lBufferCharSize);

  // Create variables to give to the iteration
  tMixStruct lProcessParams;
  lProcessParams.lstBuffers = lPtrAdditionalBuffers;
  lProcessParams.nbrActiveBuffers = lNbrBuffers - 1;
  lProcessParams.mainCoeff = NUM2DBL(rb_ary_entry(lValFirstBufferInfo, 2));

  // Iterate through the raw buffer
  if (iNbrBitsPerSample == 8) {
    commonutils_iterateThroughRawBufferOutput(
      iSelf,
      lPtrFirstBuffer,
      lPtrOutputBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      lNbrSamples,
      0,
      1,
      &arithmutils_processValue_mix_8bits,
      &lProcessParams
    );
  } else if (iNbrBitsPerSample == 16) {
    commonutils_iterateThroughRawBufferOutput(
      iSelf,
      lPtrFirstBuffer,
      lPtrOutputBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      lNbrSamples,
      0,
      1,
      &arithmutils_processValue_mix_16bits,
      &lProcessParams
    );
  } else {
    // If it is not 24 bits, the method will throw an exception. So we are safe.
    commonutils_iterateThroughRawBufferOutput(
      iSelf,
      lPtrFirstBuffer,
      lPtrOutputBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      lNbrSamples,
      0,
      1,
      &arithmutils_processValue_mix_24bits,
      &lProcessParams
    );
  }

  VALUE rValOutputBuffer = rb_str_new(lPtrOutputBuffer, lBufferCharSize);

  free(lPtrOutputBuffer);

  return rb_ary_new3(2, rValOutputBuffer, LONG2FIX(lNbrSamples));
}

// The value that represents nil in the maps
static tSampleValue gImpossibleValue;
static ID gID_logWarn;

/**
 * Process a value read from an input buffer for the compare function.
 * Optimized for 8 bits samples.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMixStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int arithmutils_processValue_compare_8bits(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tCompareStruct* lPtrParams = (tCompareStruct*)iPtrArgs;

  tSampleValue lValue2 = (*lPtrParams->buffer2_8bits)-128;
  if (lPtrParams->map != NULL) {
    // Complete the map
    if (lPtrParams->map[lPtrParams->mapOffset+iValue] == gImpossibleValue) {
      lPtrParams->map[lPtrParams->mapOffset+iValue] = lValue2;
    } else if (lPtrParams->map[lPtrParams->mapOffset+iValue] != lValue2) {
      char lMessage[256];
      sprintf(lMessage, "Distortion for input value %d was found both %d and %d", iValue, lPtrParams->map[lPtrParams->mapOffset+iValue], lValue2);
      rb_funcall(lPtrParams->self, gID_logWarn, 1, rb_str_new2(lMessage));
    }
  }
  *oPtrValue = (tSampleValue)(((long double)(lValue2-iValue))*lPtrParams->coeffDiff);
  mpz_add_ui(lPtrParams->cumulativeErrors, lPtrParams->cumulativeErrors, abs(lValue2-iValue));
  ++lPtrParams->buffer2_8bits;

  return 0;
}

/**
 * Process a value read from an input buffer for the compare function.
 * Optimized for 16 bits samples.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMixStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int arithmutils_processValue_compare_16bits(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tCompareStruct* lPtrParams = (tCompareStruct*)iPtrArgs;

  tSampleValue lValue2 = *lPtrParams->buffer2_16bits;
  if (lPtrParams->map != NULL) {
    // Complete the map
    if (lPtrParams->map[lPtrParams->mapOffset+iValue] == gImpossibleValue) {
      lPtrParams->map[lPtrParams->mapOffset+iValue] = lValue2;
    } else if (lPtrParams->map[lPtrParams->mapOffset+iValue] != lValue2) {
      char lMessage[256];
      sprintf(lMessage, "Distortion for input value %d was found both %d and %d", iValue, lPtrParams->map[lPtrParams->mapOffset+iValue], lValue2);
      rb_funcall(lPtrParams->self, gID_logWarn, 1, rb_str_new2(lMessage));
    }
  }
  *oPtrValue = (tSampleValue)(((long double)(lValue2-iValue))*lPtrParams->coeffDiff);
  mpz_add_ui(lPtrParams->cumulativeErrors, lPtrParams->cumulativeErrors, abs(lValue2-iValue));
  ++lPtrParams->buffer2_16bits;

  return 0;
}

/**
 * Process a value read from an input buffer for the compare function.
 * Optimized for 8 bits samples.
 *
 * Parameters:
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tMixStruct*</em>.
 * Return:
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int arithmutils_processValue_compare_24bits(
  const tSampleValue iValue,
  tSampleValue* oPtrValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  tCompareStruct* lPtrParams = (tCompareStruct*)iPtrArgs;

  tSampleValue lValue2 = lPtrParams->buffer2_24bits->value;
  if (lPtrParams->map != NULL) {
    // Complete the map
    if (lPtrParams->map[lPtrParams->mapOffset+iValue] == gImpossibleValue) {
      lPtrParams->map[lPtrParams->mapOffset+iValue] = lValue2;
    } else if (lPtrParams->map[lPtrParams->mapOffset+iValue] != lValue2) {
      char lMessage[256];
      sprintf(lMessage, "Distortion for input value %d was found both %d and %d", iValue, lPtrParams->map[lPtrParams->mapOffset+iValue], lValue2);
      rb_funcall(lPtrParams->self, gID_logWarn, 1, rb_str_new2(lMessage));
    }
  }
  *oPtrValue = (tSampleValue)(((long double)(lValue2-iValue))*lPtrParams->coeffDiff);
  mpz_add_ui(lPtrParams->cumulativeErrors, lPtrParams->cumulativeErrors, abs(lValue2-iValue));
  lPtrParams->buffer2_24bits = (t24bits*)(((int)lPtrParams->buffer2_24bits)+3);

  return 0;
}

/**
 * Get a Ruby integer based on an MPZ storing an integer value.
 *
 * Parameters:
 * * *iMPZ* (<em>mpz_t</em>): The mpz to read
 * Return:
 * * _Integer_: The Ruby integer
 */
#define MAX_NUMBER_DIGITS 256
VALUE mpz2RubyInt(
  mpz_t iMPZ) {
  // The buffer where it will be written
  char lStrNumber[MAX_NUMBER_DIGITS];
  mpz_get_str(lStrNumber, 16, iMPZ);

  return rb_cstr2inum(lStrNumber, 16);
}

/**
 * Compare 2 buffers.
 * Write the difference in an output buffer (Buffer2 - Buffer1).
 * Buffers must have the same size.
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValBuffer1* (<em>_String_</em>): First buffer
 * * *iValBuffer2* (<em>_String_</em>): Second buffer
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValNbrSamples* (_Integer_): Number of samples in buffers
 * * *iValCoeffDiff* (_Float_): The coefficient to apply on the differences written to the output
 * * *ioValMap* (</em>list<Integer></em>): Map of differences in sample values (can be nil if we don't want to compute it)
 * Return:
 * * _String_: Output buffer
 * * _Integer_: Cumulative errors in this buffer
 **/
static VALUE arithmutils_compareBuffers(
  VALUE iSelf,
  VALUE iValBuffer1,
  VALUE iValBuffer2,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrChannels,
  VALUE iValNbrSamples,
  VALUE iValCoeffDiff,
  VALUE ioValMap) {
  // Translate Ruby objects
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  int iNbrSamples = FIX2INT(iValNbrSamples);
  long double iCoeffDiff = NUM2DBL(iValCoeffDiff);
  char* lPtrBuffer1 = RSTRING(iValBuffer1)->ptr;
  char* lPtrBuffer2 = RSTRING(iValBuffer2)->ptr;
  int lBufferCharSize = RSTRING(iValBuffer1)->len;
  int lNbrSampleValues = 0;
  // Allocate the output buffer
  char* lPtrOutputBuffer = ALLOC_N(char, lBufferCharSize);

  // Create variables to give to the iteration
  tCompareStruct lProcessParams;
  lProcessParams.coeffDiff = iCoeffDiff;
  lProcessParams.self = iSelf;
  if (ioValMap == Qnil) {
    lProcessParams.map = NULL;
  } else {
    // Create the internal map
    // Define the impossible value
    gImpossibleValue = pow(2, iNbrBitsPerSample-1) + 1;
    lNbrSampleValues = RARRAY(ioValMap)->len;
    tSampleValue lMap[lNbrSampleValues];
    VALUE lValMapValue;
    int lIdxSampleValue;
    for (lIdxSampleValue = 0; lIdxSampleValue < lNbrSampleValues; ++lIdxSampleValue) {
      lValMapValue = rb_ary_entry(ioValMap, lIdxSampleValue);
      if (lValMapValue == Qnil) {
        lMap[lIdxSampleValue] = gImpossibleValue;
      } else {
        lMap[lIdxSampleValue] = FIX2LONG(lValMapValue);
      }
    }
    lProcessParams.map = lMap;
    lProcessParams.mapOffset = pow(2, iNbrBitsPerSample-1);
  }
  lProcessParams.buffer2_8bits = (unsigned char*)lPtrBuffer2;
  lProcessParams.buffer2_16bits = (signed short int*)lPtrBuffer2;
  lProcessParams.buffer2_24bits = (t24bits*)lPtrBuffer2;
  mpz_init(lProcessParams.cumulativeErrors);

  // Iterate through the raw buffer
  if (iNbrBitsPerSample == 8) {
    commonutils_iterateThroughRawBufferOutput(
      iSelf,
      lPtrBuffer1,
      lPtrOutputBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      0,
      1,
      &arithmutils_processValue_compare_8bits,
      &lProcessParams
    );
  } else if (iNbrBitsPerSample == 16) {
    commonutils_iterateThroughRawBufferOutput(
      iSelf,
      lPtrBuffer1,
      lPtrOutputBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      0,
      1,
      &arithmutils_processValue_compare_16bits,
      &lProcessParams
    );
  } else {
    // If it is not 24 bits, the method will throw an exception. So we are safe.
    commonutils_iterateThroughRawBufferOutput(
      iSelf,
      lPtrBuffer1,
      lPtrOutputBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      0,
      1,
      &arithmutils_processValue_compare_24bits,
      &lProcessParams
    );
  }

  if (lProcessParams.map != NULL) {
    // Modify the array in parameter
    int lIdxSampleValue;
    for (lIdxSampleValue = 0; lIdxSampleValue < lNbrSampleValues; ++lIdxSampleValue) {
      if (lProcessParams.map[lIdxSampleValue] == gImpossibleValue) {
        rb_ary_store(ioValMap, lIdxSampleValue, Qnil);
      } else {
        rb_ary_store(ioValMap, lIdxSampleValue, LONG2FIX(lProcessParams.map[lIdxSampleValue]));
      }
    }
  }
  VALUE rValCumulativeErrors = mpz2RubyInt(lProcessParams.cumulativeErrors);
  mpz_clear(lProcessParams.cumulativeErrors);

  VALUE rValOutputBuffer = rb_str_new(lPtrOutputBuffer, lBufferCharSize);

  free(lPtrOutputBuffer);

  return rb_ary_new3(2, rValOutputBuffer, rValCumulativeErrors);
}

// Initialize the module
void Init_ArithmUtils() {
  VALUE lWSKModule = rb_define_module("WSK");
  VALUE lArithmUtilsModule = rb_define_module_under(lWSKModule, "ArithmUtils");
  VALUE lArithmUtilsClass = rb_define_class_under(lArithmUtilsModule, "ArithmUtils", rb_cObject);

  rb_define_method(lArithmUtilsClass, "createMapFromFunctions", arithmutils_createMapFromFunctions, 2);
  rb_define_method(lArithmUtilsClass, "applyMap", arithmutils_applyMap, 4);
  rb_define_method(lArithmUtilsClass, "mixBuffers", arithmutils_mixBuffers, 3);
  rb_define_method(lArithmUtilsClass, "compareBuffers", arithmutils_compareBuffers, 7);
  gID_logWarn = rb_intern("logWarn");
}
