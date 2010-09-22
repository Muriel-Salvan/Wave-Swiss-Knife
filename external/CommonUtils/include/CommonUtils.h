#ifndef __COMMONUTILS_COMMONUTILS_H__
#define __COMMONUTILS_COMMONUTILS_H__

#include "ruby.h"

// Struct used to interpret raw buffers data of 24 bits
typedef struct {
  signed int value:24;
} t24bits;

// Type used to identify each sample value
typedef long long int tSampleValue;

// Pointer to a function that can be called when parsing a raw buffer
typedef int(*tPtrFctProcess)(const tSampleValue, const int, const int, void*);

// Struct containing data for a threshold information
typedef struct {
  tSampleValue min;
  tSampleValue max;
} tThresholdInfo;

/**
 * Invoke eachRawBuffer on an input data.
 * This is meant to be used with rb_iterate.
 *
 * Parameters:
 * * *iValArgs* (<em>list<Object></em>): List of arguments:
 * ** *iValInputData* (<em>WSK::Model::InputData</em>): The input data
 * ** *iValIdxBeginSample* (_Integer_): Index of the first sample to search from
 */
VALUE commonutils_callEachRawBuffer(
  VALUE iValArgs);

/**
 * Invoke eachReverseRawBuffer on an input data.
 * This is meant to be used with rb_iterate.
 *
 * Parameters:
 * * *iValArgs* (<em>list<Object></em>): List of arguments:
 * ** *iValInputData* (<em>WSK::Model::InputData</em>): The input data
 * ** *iValIdxBeginSample* (_Integer_): Index of the first sample to search from
 */
VALUE commonutils_callEachReverseRawBuffer(
  VALUE iValArgs);

/**
 * Iterate through a raw buffer.
 *
 * Parameters:
 * * *iPtrRawBuffer* (<em>const char*</em>): The raw buffer
 * * *iNbrBitsPerSample* (<em>const int</em>): The number of bits per sample
 * * *iNbrChannels* (<em>const int</em>): The number of channels
 * * *iNbrSamples* (<em>const int</em>): The number of samples
 * * *iIdxOffsetSample* (<em>const int</em>): The base offset of samples to be counted and given to the processing method
 * * *iPtrProcessMethod* (<em>const tPtrFctProcess</em>): Pointer to the method to call for processing
 * * *iPtrArgs* (<em>void*</em>): Pointer to a user specific struct that will be given to the processing function
 */
void commonutils_iterateThroughRawBuffer(
  const char* iPtrRawBuffer,
  const int iNbrBitsPerSample,
  const int iNbrChannels,
  const int iNbrSamples,
  const int iIdxOffsetSample,
  const tPtrFctProcess iPtrProcessMethod,
  void* iPtrArgs);

/**
 * Iterate through a raw buffer in reverse mode.
 *
 * Parameters:
 * * *iPtrRawBuffer* (<em>const char*</em>): The raw buffer
 * * *iNbrBitsPerSample* (<em>const int</em>): The number of bits per sample
 * * *iNbrChannels* (<em>const int</em>): The number of channels
 * * *iNbrSamples* (<em>const int</em>): The number of samples
 * * *iIdxOffsetSample* (<em>const int</em>): The base offset of samples to be counted and given to the processing method
 * * *iPtrProcessMethod* (<em>const tPtrFctProcess</em>): Pointer to the method to call for processing
 * * *iPtrArgs* (<em>void*</em>): Pointer to a user specific struct that will be given to the processing function
 */
void commonutils_iterateReverseThroughRawBuffer(
  const char* iPtrRawBuffer,
  const int iNbrBitsPerSample,
  const int iNbrChannels,
  const int iNbrSamples,
  const int iIdxOffsetSample,
  const tPtrFctProcess iPtrProcessMethod,
  void* iPtrArgs);

#endif
