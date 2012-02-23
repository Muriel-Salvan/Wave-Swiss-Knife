/**
 * Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
 * Licensed under the terms specified in LICENSE file. No warranty is provided.
 **/

#ifndef __COMMONUTILS_COMMONUTILS_H__
#define __COMMONUTILS_COMMONUTILS_H__

#include "ruby.h"

// Struct used to interpret raw buffers data of 24 bits
typedef struct {
  signed int value:24;
} t24bits;

// Type used to identify each sample value
typedef int tSampleValue;

// Type used to identify each sample index
typedef long long int tSampleIndex;

// Pointer to a function that can be called when parsing a raw buffer
typedef int(*tPtrFctProcess)(const tSampleValue, const tSampleIndex, const int, void*);
// Pointer to a function that can be called when parsing a raw buffer and writing another raw buffer
typedef int(*tPtrFctProcessOutput)(const tSampleValue, tSampleValue*, const tSampleIndex, const int, void*);
// Pointer to a function that can be called when writing a raw buffer
typedef int(*tPtrFctProcessOutputOnly)(tSampleValue*, const tSampleIndex, const int, void*);

// Struct containing data for a threshold information
typedef struct {
  tSampleValue min;
  tSampleValue max;
} tThresholdInfo;

// Function types, as defined in Functions.rb
#define FCTTYPE_PIECEWISE_LINEAR 0

// Function pointer for free
typedef void(*tPtrFctFree)(void*);

// Struct used to store piecewise linear function data
typedef struct {
  int nbrPoints;
  // The array of points coordinates, sorted by X value
  tSampleIndex* pointsX;
  long double* pointsY;
} tFunction_PiecewiseLinear;

// Struct used to store a function
typedef struct {
  // The function type
  int fctType;
  // The pointer to the free method (it will be called by the GC)
  tPtrFctFree freeFct;
  // The function object (should be a tFunction_Xxxx* type)
  void* fctData;
} tFunction;

/**
 * Invoke each_raw_buffer on an input data.
 * This is meant to be used with rb_iterate.
 *
 * Parameters::
 * * *iValArgs* (<em>list<Object></em>): List of arguments:
 * ** *iValInputData* (<em>WSK::Model::InputData</em>): The input data
 * ** *iValIdxBeginSample* (_Integer_): Index of the first sample to search from
 */
VALUE commonutils_callEachRawBuffer(
  VALUE iValArgs);

/**
 * Invoke each_reverse_raw_buffer on an input data.
 * This is meant to be used with rb_iterate.
 *
 * Parameters::
 * * *iValArgs* (<em>list<Object></em>): List of arguments:
 * ** *iValInputData* (<em>WSK::Model::InputData</em>): The input data
 * ** *iValIdxBeginSample* (_Integer_): Index of the first sample to search from
 */
VALUE commonutils_callEachReverseRawBuffer(
  VALUE iValArgs);

/**
 * Iterate through a raw buffer.
 *
 * Parameters::
 * * *iPtrRawBuffer* (<em>const char*</em>): The raw buffer
 * * *iNbrBitsPerSample* (<em>const int</em>): The number of bits per sample
 * * *iNbrChannels* (<em>const int</em>): The number of channels
 * * *iNbrSamples* (<em>const tSampleIndex</em>): The number of samples
 * * *iIdxOffsetSample* (<em>const tSampleIndex</em>): The base offset of samples to be counted and given to the processing method
 * * *iPtrProcessMethod* (<em>const tPtrFctProcess</em>): Pointer to the method to call for processing
 * * *iPtrArgs* (<em>void*</em>): Pointer to a user specific struct that will be given to the processing function
 */
void commonutils_iterateThroughRawBuffer(
  const char* iPtrRawBuffer,
  const int iNbrBitsPerSample,
  const int iNbrChannels,
  const tSampleIndex iNbrSamples,
  const tSampleIndex iIdxOffsetSample,
  const tPtrFctProcess iPtrProcessMethod,
  void* iPtrArgs);

/**
 * Iterate through a raw buffer, and writes another raw buffer.
 *
 * Parameters::
 * * *iSelf* (_Object_): Object used to call log methods
 * * *iPtrRawBuffer* (<em>const char*</em>): The raw buffer
 * * *oPtrRawBufferOut* (<em>char*</em>): The raw buffer to write
 * * *iNbrBitsPerSample* (<em>const int</em>): The number of bits per sample
 * * *iNbrChannels* (<em>const int</em>): The number of channels
 * * *iNbrSamples* (<em>const tSampleIndex</em>): The number of samples
 * * *iIdxOffsetSample* (<em>const tSampleIndex</em>): The base offset of samples to be counted and given to the processing method
 * * *iNeedCheck* (<em>const int</em>): Do we need checking output value ranges ? 0 = no, 1 = yes
 * * *iPtrProcessMethod* (<em>const tPtrFctProcessOutput</em>): Pointer to the method to call for processing
 * * *iPtrArgs* (<em>void*</em>): Pointer to a user specific struct that will be given to the processing function
 */
void commonutils_iterateThroughRawBufferOutput(
  VALUE iSelf,
  const char* iPtrRawBuffer,
  char* oPtrRawBufferOut,
  const int iNbrBitsPerSample,
  const int iNbrChannels,
  const tSampleIndex iNbrSamples,
  const tSampleIndex iIdxOffsetSample,
  const int iNeedCheck,
  const tPtrFctProcessOutput iPtrProcessMethod,
  void* iPtrArgs);

/**
 * Iterate through an output raw buffer only, without input raw buffer.
 *
 * Parameters::
 * * *iSelf* (_Object_): Object used to call log methods
 * * *oPtrRawBufferOut* (<em>char*</em>): The raw buffer to write
 * * *iNbrBitsPerSample* (<em>const int</em>): The number of bits per sample
 * * *iNbrChannels* (<em>const int</em>): The number of channels
 * * *iNbrSamples* (<em>const tSampleIndex</em>): The number of samples
 * * *iIdxOffsetSample* (<em>const tSampleIndex</em>): The base offset of samples to be counted and given to the processing method
 * * *iNeedCheck* (<em>const int</em>): Do we need checking output value ranges ? 0 = no, 1 = yes
 * * *iPtrProcessMethod* (<em>const tPtrFctProcessOutputOnly</em>): Pointer to the method to call for processing
 * * *iPtrArgs* (<em>void*</em>): Pointer to a user specific struct that will be given to the processing function
 */
void commonutils_iterateThroughRawBufferOutputOnly(
  VALUE iSelf,
  char* oPtrRawBufferOut,
  const int iNbrBitsPerSample,
  const int iNbrChannels,
  const tSampleIndex iNbrSamples,
  const tSampleIndex iIdxOffsetSample,
  const int iNeedCheck,
  const tPtrFctProcessOutputOnly iPtrProcessMethod,
  void* iPtrArgs);

/**
 * Iterate through a raw buffer in reverse mode.
 *
 * Parameters::
 * * *iPtrRawBuffer* (<em>const char*</em>): The raw buffer
 * * *iNbrBitsPerSample* (<em>const int</em>): The number of bits per sample
 * * *iNbrChannels* (<em>const int</em>): The number of channels
 * * *iNbrSamples* (<em>const tSampleIndex</em>): The number of samples
 * * *iIdxOffsetSample* (<em>const tSampleIndex</em>): The base offset of samples to be counted and given to the processing method
 * * *iPtrProcessMethod* (<em>const tPtrFctProcess</em>): Pointer to the method to call for processing
 * * *iPtrArgs* (<em>void*</em>): Pointer to a user specific struct that will be given to the processing function
 */
void commonutils_iterateReverseThroughRawBuffer(
  const char* iPtrRawBuffer,
  const int iNbrBitsPerSample,
  const int iNbrChannels,
  const tSampleIndex iNbrSamples,
  const tSampleIndex iIdxOffsetSample,
  const tPtrFctProcess iPtrProcessMethod,
  void* iPtrArgs);

#endif
