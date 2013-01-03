/**
 * Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
 * Licensed under the terms specified in LICENSE file. No warranty is provided.
 **/

#include "ruby.h"
#include <CommonUtils.h>

// Struct used to convey data among iterators in the getNextSilentSample method
typedef struct {
  tSampleIndex* ptrIdxFirstSilentSample;
  tThresholdInfo* ptrSilenceThresholds;
  tSampleIndex* ptrIdxSilenceSample_Result;
  tSampleIndex minSilenceSamples;
  int nbrChannels;
} tFindSilentStruct;

// Struct used to convey data among iterators in the getFirstSampleBeyondThreshold method
typedef struct {
  tSampleIndex* ptrIdxSample_Result;
  tThresholdInfo* ptrThresholds;
  int nbrChannels;
} tFirstSampleBeyondThresholdStruct;

// Struct used to convey data among iterators in the getNextSilentInThresholds method
typedef struct {
  tSampleIndex* ptrIdxSample;
  tSampleIndex* ptrIdxFirstSilentSample;
  tThresholdInfo* ptrSilenceThresholds;
  tSampleIndex* ptrIdxSilenceSample_Result;
} tNextSilentInThresholdsStruct;

/**
 * Process a value read from an input buffer for the NextSilentSample function.
 *
 * Parameters::
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tFindSilentStruct*</em>.
 * Return::
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int silentutils_processValue(
  const tSampleValue iValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  int rResult = 0;

  // Interpret parameters
  tFindSilentStruct* lPtrVariables = (tFindSilentStruct*)iPtrArgs;

  if ((iValue < (lPtrVariables->ptrSilenceThresholds)[iIdxChannel].min) ||
      (iValue > (lPtrVariables->ptrSilenceThresholds)[iIdxChannel].max)) {
    // This value is not silent
    // If we were in silence that has not yet reached its minimal duration, cancel this last silence
    *(lPtrVariables->ptrIdxFirstSilentSample) = -1;
    // Don't even read other channels
    rResult = 2;
  } else {
    // This value is silent
    if ((*(lPtrVariables->ptrIdxFirstSilentSample)) == -1) {
      // This is the first silent value we have
      *(lPtrVariables->ptrIdxFirstSilentSample) = iIdxSample;
    }
    // Check if the minimal duration has been reached
    if (iIdxSample - (*(lPtrVariables->ptrIdxFirstSilentSample)) + 1 >= lPtrVariables->minSilenceSamples) {
      // We have found a silence according to thresholds.
      *(lPtrVariables->ptrIdxSilenceSample_Result) = *(lPtrVariables->ptrIdxFirstSilentSample);
      // Stop iterations
      rResult = 1;
    }
  }

  return rResult;
}

/**
 * Process a value read from an input buffer for the NextSilentSample function.
 * Do it in backwards search.
 *
 * Parameters::
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tFindSilentStruct*</em>.
 * Return::
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int silentutils_Reverse_processValue(
  const tSampleValue iValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  int rResult = 0;

  // Interpret parameters
  tFindSilentStruct* lPtrVariables = (tFindSilentStruct*)iPtrArgs;

  if ((iValue < (lPtrVariables->ptrSilenceThresholds)[iIdxChannel].min) ||
      (iValue > (lPtrVariables->ptrSilenceThresholds)[iIdxChannel].max)) {
    // This value is not silent
    // If we were in silence that has not yet reached its minimal duration, cancel this last silence
    *(lPtrVariables->ptrIdxFirstSilentSample) = -1;
    // Don't even read other channels
    rResult = 2;
  } else {
    // This value is silent
    if ((*(lPtrVariables->ptrIdxFirstSilentSample)) == -1) {
      // This is the first silent value we have
      *(lPtrVariables->ptrIdxFirstSilentSample) = iIdxSample;
    }
    // Check if the minimal duration has been reached
    if ((*(lPtrVariables->ptrIdxFirstSilentSample)) - iIdxSample + 1 >= lPtrVariables->minSilenceSamples) {
      // We have found a silence according to thresholds.
      *(lPtrVariables->ptrIdxSilenceSample_Result) = *(lPtrVariables->ptrIdxFirstSilentSample);
      // Stop iterations
      rResult = 1;
    }
  }

  return rResult;
}

/**
 * Code block called by getNextSilentSample in the each_raw_buffer loop.
 * This is meant to be used with rb_block_call.
 *
 * Parameters::
 * * *iYieldedObject* (_Object_): First parameter of iArgs
 * * *iValContextArgs* (<em>list<Object></em>): The context arguments:
 * ** *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * ** *iValData* (_DATA_): Data encapsulating the tNextSilentInThresholdsStruct that contains C variables to be modified
 * ** *iValMinSilenceSamples* (_Integer_): Minimal silence samples
 * ** *iValBackwardsSearch* (_Boolean_): Do we search backwards ?
 * * *iArgc* (_int_): Number of arguments in iArgs
 * * *iArgs* (_VALUE[]_): Array of arguments given by the yield call:
 * ** *iValInputRawBuffer* (_String_): The raw buffer
 * ** *iValNbrSamples* (_Integer_): The number of samples in this buffer
 * ** *iValNbrChannels* (_Integer_): The number of channels in this buffer
 */
static VALUE silentutils_blockEachRawBuffer(
  VALUE iYieldedObject,
  VALUE iValContextArgs,
  int iArgc,
  VALUE iArgs[]) {
  // Read arguments
  VALUE iValInputRawBuffer = iArgs[0];
  VALUE iValNbrSamples = iArgs[1];
  VALUE iValNbrChannels = iArgs[2];
  VALUE iValNbrBitsPerSample = rb_ary_entry(iValContextArgs, 0);
  VALUE iValData = rb_ary_entry(iValContextArgs, 1);
  VALUE iValMinSilenceSamples = rb_ary_entry(iValContextArgs, 2);
  VALUE iValBackwardsSearch = rb_ary_entry(iValContextArgs, 3);
  // Translate parameters in C types
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  tSampleIndex iMinSilenceSamples = FIX2LONG(iValMinSilenceSamples);
  // Get C pointers back from the data
  tNextSilentInThresholdsStruct* lPtrData;
  Data_Get_Struct(iValData, tNextSilentInThresholdsStruct, lPtrData);
  tSampleIndex* lPtrIdxSample = lPtrData->ptrIdxSample;
  tSampleIndex* lPtrIdxFirstSilentSample = lPtrData->ptrIdxFirstSilentSample;
  tThresholdInfo* lPtrSilenceThresholds = lPtrData->ptrSilenceThresholds;
  tSampleIndex* lPtrIdxSilenceSample_Result = lPtrData->ptrIdxSilenceSample_Result;

  // Get the real underlying raw buffer
  char* lPtrRawBuffer = RSTRING_PTR(iValInputRawBuffer);

  // Set variables to give to the process
  tFindSilentStruct lProcessVariables;
  lProcessVariables.ptrIdxFirstSilentSample = lPtrIdxFirstSilentSample;
  lProcessVariables.ptrSilenceThresholds = lPtrSilenceThresholds;
  lProcessVariables.ptrIdxSilenceSample_Result = lPtrIdxSilenceSample_Result;
  lProcessVariables.minSilenceSamples = iMinSilenceSamples;
  lProcessVariables.nbrChannels = iNbrChannels;

  // Iterate through the raw buffer
  if (iValBackwardsSearch == Qtrue) {
    commonutils_iterateReverseThroughRawBuffer(
      lPtrRawBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      *lPtrIdxSample,
      &silentutils_Reverse_processValue,
      &lProcessVariables
    );
  } else {
    commonutils_iterateThroughRawBuffer(
      lPtrRawBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      *lPtrIdxSample,
      &silentutils_processValue,
      &lProcessVariables
    );
  }

  // If the result was found in this raw buffer, stop parsing everything
  if (*lPtrIdxSilenceSample_Result != -1) {
    rb_iter_break();
  }

  // Modify the sample index
  if (iValBackwardsSearch == Qtrue) {
    (*lPtrIdxSample) -= iNbrSamples;
  } else {
    (*lPtrIdxSample) += iNbrSamples;
  }

  return Qnil;
}

/**
 * Get the next silent sample from an input buffer
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValInputData* (<em>WSK::Model::InputData</em>): The input data
 * * *iValIdxStartSample* (_Integer_): Index of the first sample to search from
 * * *iValSilenceThresholds* (<em>list< [Integer,Integer] ></em>): The silence thresholds specifications
 * * *iValMinSilenceSamples* (_Integer_): Number of samples minimum to identify a silence
 * * *iValBackwardsSearch* (_Boolean_): Do we search backwards ?
 * Return::
 * * _Integer_: Index of the next silent sample, or nil if none
 **/
static VALUE silentutils_getNextSilentInThresholds(
  VALUE iSelf,
  VALUE iValInputData,
  VALUE iValIdxStartSample,
  VALUE iValSilenceThresholds,
  VALUE iValMinSilenceSamples,
  VALUE iValBackwardsSearch) {
  VALUE rValNextSilentSample = Qnil;

  // Translate parameters in C types
  tSampleIndex iIdxStartSample = FIX2LONG(iValIdxStartSample);

  // The cursor of samples. Set it to the first sample we start from searching.
  tSampleIndex lIdxSample = iIdxStartSample;
  // Read some info from the Header
  VALUE lValHeader = rb_funcall(iValInputData, rb_intern("Header"), 0);
  VALUE lValNbrBitsPerSample = rb_funcall(lValHeader, rb_intern("NbrBitsPerSample"), 0);
  VALUE lValNbrChannels = rb_funcall(lValHeader, rb_intern("NbrChannels"), 0);
  // Decode the thresholds
  int lNbrChannels = FIX2INT(lValNbrChannels);
  tThresholdInfo lSilenceThresholds[lNbrChannels];
  VALUE lTmpThresholds;
  int lIdxChannel;
  for(lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
    lTmpThresholds = rb_ary_entry(iValSilenceThresholds, lIdxChannel);
    lSilenceThresholds[lIdxChannel].min = FIX2INT(rb_ary_entry(lTmpThresholds, 0));
    lSilenceThresholds[lIdxChannel].max = FIX2INT(rb_ary_entry(lTmpThresholds, 1));
  }

  // Index of the first silent sample encountered while parsing.
  // Used to assert the minimal duration of the silence. -1 means we don't have one yet.
  tSampleIndex lIdxFirstSilentSample;
  // The result
  tSampleIndex lIdxSilenceSample_Result;

  // Encapsulate the data that will be used and modified by the iteration block
  tNextSilentInThresholdsStruct lData;
  lData.ptrIdxSample = &lIdxSample;
  lData.ptrIdxFirstSilentSample = &lIdxFirstSilentSample;
  lData.ptrSilenceThresholds = &lSilenceThresholds;
  lData.ptrIdxSilenceSample_Result = &lIdxSilenceSample_Result;
  VALUE lValData = Data_Wrap_Struct(rb_cObject, NULL, NULL, &lData);

  lIdxFirstSilentSample = -1;
  lIdxSilenceSample_Result = -1;

  // Parse the data, using thresholds matching only
  VALUE lEachArgs[1];
  lEachArgs[0] = LONG2FIX(lIdxSample);
  if (iValBackwardsSearch == Qtrue) {
    rb_block_call(
      iValInputData,
      rb_intern("each_reverse_raw_buffer"),
      1,
      lEachArgs,
      RUBY_METHOD_FUNC(silentutils_blockEachRawBuffer),
      rb_ary_new3(4,
        lValNbrBitsPerSample,
        lValData,
        iValMinSilenceSamples,
        iValBackwardsSearch)
    );
  } else {
    rb_block_call(
      iValInputData,
      rb_intern("each_raw_buffer"),
      1,
      lEachArgs,
      RUBY_METHOD_FUNC(silentutils_blockEachRawBuffer),
      rb_ary_new3(4,
        lValNbrBitsPerSample,
        lValData,
        iValMinSilenceSamples,
        iValBackwardsSearch)
    );
  }

  if (lIdxSilenceSample_Result != -1) {
    rValNextSilentSample = LONG2FIX(lIdxSilenceSample_Result);
  }

  return rValNextSilentSample;
}

/**
 * Process a value read from an input buffer for the NextSilentSample function.
 *
 * Parameters::
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact an <em>tFirstSampleBeyondThresholdStruct*</em>.
 * Return::
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int silentutils_sbt_processValue(
  const tSampleValue iValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  int rResult = 0;

  // Interpret parameters
  tFirstSampleBeyondThresholdStruct* lPtrVariables = (tFirstSampleBeyondThresholdStruct*)iPtrArgs;

  if ((iValue < (lPtrVariables->ptrThresholds)[iIdxChannel].min) ||
      (iValue > (lPtrVariables->ptrThresholds)[iIdxChannel].max)) {
    // This value is not silent
    rResult = 1;
    *(lPtrVariables->ptrIdxSample_Result) = iIdxSample;
  }

  return rResult;
}

/**
 * Get the sample index that exceeds a threshold in a raw buffer.
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValRawBuffer* (_String_): The raw buffer
 * * *iValThresholds* (<em>list< [Integer,Integer] ></em>): The thresholds
 * * *iValNbrBitsPerSample* (_Integer_): Number of bits per sample
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValNbrSamples* (_Integer_): Number of samples
 * * *iValLastSample* (_Boolean_): Are we looking for the last sample beyond threshold ?
 * Return::
 * * _Integer_: Index of the first sample exceeding thresholds, or nil if none
 */
static VALUE silentutils_getSampleBeyondThresholds(
  VALUE iSelf,
  VALUE iValRawBuffer,
  VALUE iValThresholds,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrChannels,
  VALUE iValNbrSamples,
  VALUE iValLastSample) {
  VALUE rValIdxFirstSample = Qnil;

  // Translate parameters in C types
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  // Get the underlying char*
  char* lPtrRawBuffer = RSTRING_PTR(iValRawBuffer);
  // Decode the thresholds
  tThresholdInfo lThresholds[iNbrChannels];
  VALUE lTmpThresholds;
  int lIdxChannel;
  for(lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
    lTmpThresholds = rb_ary_entry(iValThresholds, lIdxChannel);
    lThresholds[lIdxChannel].min = FIX2INT(rb_ary_entry(lTmpThresholds, 0));
    lThresholds[lIdxChannel].max = FIX2INT(rb_ary_entry(lTmpThresholds, 1));
  }
  // Set variables to give to the process
  tSampleIndex lIdxSampleOut = -1;
  tFirstSampleBeyondThresholdStruct lProcessVariables;
  lProcessVariables.ptrThresholds = &lThresholds[0];
  lProcessVariables.ptrIdxSample_Result = &lIdxSampleOut;
  lProcessVariables.nbrChannels = iNbrChannels;

  // Parse the buffer
  if (iValLastSample == Qtrue) {
    commonutils_iterateReverseThroughRawBuffer(
      lPtrRawBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      iNbrSamples-1,
      &silentutils_sbt_processValue,
      &lProcessVariables
    );
  } else {
    commonutils_iterateThroughRawBuffer(
      lPtrRawBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      0,
      &silentutils_sbt_processValue,
      &lProcessVariables
    );
  }
  if (lIdxSampleOut != -1) {
    rValIdxFirstSample = LONG2FIX(lIdxSampleOut);
  }

  return rValIdxFirstSample;
}

// Initialize the module
void Init_SilentUtils() {
  VALUE lWSKModule = rb_define_module("WSK");
  VALUE lSilentUtilsModule = rb_define_module_under(lWSKModule, "SilentUtils");
  VALUE lSilentUtilsClass = rb_define_class_under(lSilentUtilsModule, "SilentUtils", rb_cObject);

  rb_define_method(lSilentUtilsClass, "getNextSilentInThresholds", silentutils_getNextSilentInThresholds, 5);
  rb_define_method(lSilentUtilsClass, "getSampleBeyondThresholds", silentutils_getSampleBeyondThresholds, 6);
}
