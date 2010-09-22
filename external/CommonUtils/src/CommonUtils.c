#include "CommonUtils.h"
#include "ruby.h"
#include <stdio.h>

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
  VALUE iValArgs) {
  // Read arguments
  VALUE iValInputData = rb_ary_entry(iValArgs, 0);
  VALUE iValIdxBeginSample = rb_ary_entry(iValArgs, 1);

  return rb_funcall(iValInputData, rb_intern("eachRawBuffer"), 1, iValIdxBeginSample);
}

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
  VALUE iValArgs) {
  // Read arguments
  VALUE iValInputData = rb_ary_entry(iValArgs, 0);
  VALUE iValIdxBeginSample = rb_ary_entry(iValArgs, 1);

  return rb_funcall(iValInputData, rb_intern("eachReverseRawBuffer"), 2, INT2FIX(0), iValIdxBeginSample);
}

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
  void* iPtrArgs) {
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  int lIdxBufferSample;
  int lIdxChannel;
  int lIdxSample = iIdxOffsetSample;
  // 0: Continue iterations
  // 1: Break all
  // 2: Skip to the next sample
  int lProcessResult;
  if (iNbrBitsPerSample == 8) {
    unsigned char* lPtrData = (unsigned char*)iPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
        if (lProcessResult == 0) {
          lProcessResult = iPtrProcessMethod((tSampleValue)((*lPtrData) - 128), lIdxSample, lIdxChannel, iPtrArgs);
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lPtrData;
      }
      if (lProcessResult == 1) {
        break;
      }
      ++lIdxSample;
    }
  } else if (iNbrBitsPerSample == 16) {
    signed short int* lPtrData = (signed short int*)iPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
        if (lProcessResult == 0) {
          lProcessResult = iPtrProcessMethod((tSampleValue)(*lPtrData), lIdxSample, lIdxChannel, iPtrArgs);
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lPtrData;
      }
      if (lProcessResult == 1) {
        break;
      }
      ++lIdxSample;
    }
  } else if (iNbrBitsPerSample == 24) {
    t24bits* lPtrData = (t24bits*)iPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
        if (lProcessResult == 0) {
          lProcessResult = iPtrProcessMethod((tSampleValue)(lPtrData->value), lIdxSample, lIdxChannel, iPtrArgs);
        }
        if (lProcessResult == 1) {
          break;
        }
        // Increase lPtrData this way to ensure alignment.
        lPtrData = (t24bits*)(((int)lPtrData)+3);
      }
      if (lProcessResult == 1) {
        break;
      }
      ++lIdxSample;
    }
  } else {
    rb_raise(rb_eRuntimeError, "Unknown bits per samples: %d\n", iNbrBitsPerSample);
  }
}

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
  void* iPtrArgs) {
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  int lIdxBufferSample;
  int lIdxChannel;
  int lIdxSample = iIdxOffsetSample;
  // 0: Continue iterations
  // 1: Break all
  // 2: Skip to the next sample
  int lProcessResult;
  if (iNbrBitsPerSample == 8) {
    unsigned char* lPtrData = (unsigned char*)iPtrRawBuffer;
    lPtrData += iNbrSamples*iNbrChannels - 1;
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
        if (lProcessResult == 0) {
          lProcessResult = iPtrProcessMethod((tSampleValue)((*lPtrData) - 128), lIdxSample, lIdxChannel, iPtrArgs);
        }
        if (lProcessResult == 1) {
          break;
        }
        --lPtrData;
      }
      if (lProcessResult == 1) {
        break;
      }
      --lIdxSample;
    }
  } else if (iNbrBitsPerSample == 16) {
    signed short int* lPtrData = (signed short int*)iPtrRawBuffer;
    lPtrData += iNbrSamples*iNbrChannels - 1;
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
        if (lProcessResult == 0) {
          lProcessResult = iPtrProcessMethod((tSampleValue)(*lPtrData), lIdxSample, lIdxChannel, iPtrArgs);
        }
        if (lProcessResult == 1) {
          break;
        }
        --lPtrData;
      }
      if (lProcessResult == 1) {
        break;
      }
      --lIdxSample;
    }
  } else if (iNbrBitsPerSample == 24) {
    t24bits* lPtrData = (t24bits*)iPtrRawBuffer;
    lPtrData = (t24bits*)(((int)lPtrData)+3*(iNbrSamples*iNbrChannels - 1));
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
        if (lProcessResult == 0) {
          lProcessResult = iPtrProcessMethod((tSampleValue)(lPtrData->value), lIdxSample, lIdxChannel, iPtrArgs);
        }
        if (lProcessResult == 1) {
          break;
        }
        // Increase lPtrData this way to ensure alignment.
        lPtrData = (t24bits*)(((int)lPtrData)-3);
      }
      if (lProcessResult == 1) {
        break;
      }
      --lIdxSample;
    }
  } else {
    rb_raise(rb_eRuntimeError, "Unknown bits per samples: %d\n", iNbrBitsPerSample);
  }
}
