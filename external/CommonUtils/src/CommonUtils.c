/**
 * Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
 * Licensed under the terms specified in LICENSE file. No warranty is provided.
 **/

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
  void* iPtrArgs) {
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  tSampleIndex lIdxBufferSample;
  int lIdxChannel;
  tSampleIndex lIdxSample = iIdxOffsetSample;
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
          lProcessResult = iPtrProcessMethod(((tSampleValue)(*lPtrData)) - 128, lIdxSample, lIdxChannel, iPtrArgs);
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
 * Iterate through a raw buffer, and writes another raw buffer.
 *
 * Parameters:
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
  void* iPtrArgs) {
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  tSampleIndex lIdxBufferSample;
  int lIdxChannel;
  tSampleIndex lIdxSample = iIdxOffsetSample;
  // 0: Continue iterations
  // 1: Break all
  // 2: Skip to the next sample
  int lProcessResult;
  tSampleValue lOutputValue;
  // Compute max and min values if needed only
  if (iNeedCheck != 0) {
    char lLogMessage[256];
    ID lIDLogWarn = rb_intern("logWarn");
    int lMaxValue = (1 << (iNbrBitsPerSample-1)) - 1;
    int lMinValue = -(1 << (iNbrBitsPerSample-1));
    if (iNbrBitsPerSample == 8) {
      unsigned char* lPtrData = (unsigned char*)iPtrRawBuffer;
      unsigned char* lPtrDataOut = (unsigned char*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(((tSampleValue)(*lPtrData)) - 128, &lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          if (lOutputValue > lMaxValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding maximal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMaxValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMaxValue;
          } else if (lOutputValue < lMinValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding minimal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMinValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMinValue;
          }
          (*lPtrDataOut) = (unsigned char)(lOutputValue + 128);
          ++lPtrDataOut;
          ++lPtrData;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 16) {
      signed short int* lPtrData = (signed short int*)iPtrRawBuffer;
      signed short int* lPtrDataOut = (signed short int*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod((tSampleValue)(*lPtrData), &lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          if (lOutputValue > lMaxValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding maximal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMaxValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMaxValue;
          } else if (lOutputValue < lMinValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding minimal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMinValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMinValue;
          }
          (*lPtrDataOut) = (signed short int)lOutputValue;
          ++lPtrDataOut;
          ++lPtrData;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 24) {
      t24bits* lPtrData = (t24bits*)iPtrRawBuffer;
      t24bits* lPtrDataOut = (t24bits*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod((tSampleValue)(lPtrData->value), &lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          if (lOutputValue > lMaxValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding maximal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMaxValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMaxValue;
          } else if (lOutputValue < lMinValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding minimal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMinValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMinValue;
          }
          lPtrDataOut->value = lOutputValue;
          lPtrDataOut = (t24bits*)(((int)lPtrDataOut)+3);
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
  } else {
    // No check needed here. Just write what we get.
    if (iNbrBitsPerSample == 8) {
      unsigned char* lPtrData = (unsigned char*)iPtrRawBuffer;
      unsigned char* lPtrDataOut = (unsigned char*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(((tSampleValue)(*lPtrData)) - 128, &lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          (*lPtrDataOut) = (unsigned char)(lOutputValue + 128);
          ++lPtrDataOut;
          ++lPtrData;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 16) {
      signed short int* lPtrData = (signed short int*)iPtrRawBuffer;
      signed short int* lPtrDataOut = (signed short int*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod((tSampleValue)(*lPtrData), &lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          (*lPtrDataOut) = (signed short int)lOutputValue;
          ++lPtrDataOut;
          ++lPtrData;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 24) {
      t24bits* lPtrData = (t24bits*)iPtrRawBuffer;
      t24bits* lPtrDataOut = (t24bits*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod((tSampleValue)(lPtrData->value), &lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          lPtrDataOut->value = lOutputValue;
          lPtrDataOut = (t24bits*)(((int)lPtrDataOut)+3);
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
}

/**
 * Iterate through an output raw buffer only, without input raw buffer.
 *
 * Parameters:
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
  void* iPtrArgs) {
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  tSampleIndex lIdxBufferSample;
  int lIdxChannel;
  tSampleIndex lIdxSample = iIdxOffsetSample;
  // 0: Continue iterations
  // 1: Break all
  // 2: Skip to the next sample
  int lProcessResult;
  tSampleValue lOutputValue;
  // Compute max and min values if needed only
  if (iNeedCheck != 0) {
    char lLogMessage[256];
    ID lIDLogWarn = rb_intern("logWarn");
    int lMaxValue = (1 << (iNbrBitsPerSample-1)) - 1;
    int lMinValue = -(1 << (iNbrBitsPerSample-1));
    if (iNbrBitsPerSample == 8) {
      unsigned char* lPtrDataOut = (unsigned char*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(&lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          if (lOutputValue > lMaxValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding maximal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMaxValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMaxValue;
          } else if (lOutputValue < lMinValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding minimal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMinValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMinValue;
          }
          (*lPtrDataOut) = (unsigned char)(lOutputValue + 128);
          ++lPtrDataOut;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 16) {
      signed short int* lPtrDataOut = (signed short int*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(&lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          if (lOutputValue > lMaxValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding maximal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMaxValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMaxValue;
          } else if (lOutputValue < lMinValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding minimal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMinValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMinValue;
          }
          (*lPtrDataOut) = (signed short int)lOutputValue;
          ++lPtrDataOut;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 24) {
      t24bits* lPtrDataOut = (t24bits*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(&lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          if (lOutputValue > lMaxValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding maximal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMaxValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMaxValue;
          } else if (lOutputValue < lMinValue) {
            sprintf(lLogMessage, "@%lld,%d - Exceeding minimal value: %d, set to %d", lIdxSample, lIdxChannel, lOutputValue, lMinValue);
            rb_funcall(iSelf, lIDLogWarn, 1, rb_str_new2(lLogMessage));
            lOutputValue = lMinValue;
          }
          lPtrDataOut->value = lOutputValue;
          // Increase lPtrDataOut this way to ensure alignment.
          lPtrDataOut = (t24bits*)(((int)lPtrDataOut)+3);
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else {
      rb_raise(rb_eRuntimeError, "Unknown bits per samples: %d\n", iNbrBitsPerSample);
    }
  } else {
    // No check needed here. Just write what we get.
    if (iNbrBitsPerSample == 8) {
      unsigned char* lPtrDataOut = (unsigned char*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(&lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          (*lPtrDataOut) = (unsigned char)(lOutputValue + 128);
          ++lPtrDataOut;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 16) {
      signed short int* lPtrDataOut = (signed short int*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(&lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          (*lPtrDataOut) = (signed short int)lOutputValue;
          ++lPtrDataOut;
        }
        if (lProcessResult == 1) {
          break;
        }
        ++lIdxSample;
      }
    } else if (iNbrBitsPerSample == 24) {
      t24bits* lPtrDataOut = (t24bits*)oPtrRawBufferOut;
      for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
        lProcessResult = 0;
        for (lIdxChannel = 0; lIdxChannel < iNbrChannels; ++lIdxChannel) {
          if (lProcessResult == 0) {
            lProcessResult = iPtrProcessMethod(&lOutputValue, lIdxSample, lIdxChannel, iPtrArgs);
          }
          if (lProcessResult == 1) {
            break;
          }
          // Write lOutputValue
          lPtrDataOut->value = lOutputValue;
          // Increase lPtrDataOut this way to ensure alignment.
          lPtrDataOut = (t24bits*)(((int)lPtrDataOut)+3);
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
}

/**
 * Iterate through a raw buffer in reverse mode.
 *
 * Parameters:
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
  void* iPtrArgs) {
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  tSampleIndex lIdxBufferSample;
  int lIdxChannel;
  tSampleIndex lIdxSample = iIdxOffsetSample;
  // 0: Continue iterations
  // 1: Break all
  // 2: Skip to the next sample
  int lProcessResult;
  if (iNbrBitsPerSample == 8) {
    unsigned char* lPtrData = (unsigned char*)iPtrRawBuffer;
    lPtrData += iNbrSamples*iNbrChannels - 1;
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = iNbrChannels-1; lIdxChannel >= 0; --lIdxChannel) {
        if (lProcessResult == 0) {
          lProcessResult = iPtrProcessMethod(((tSampleValue)(*lPtrData)) - 128, lIdxSample, lIdxChannel, iPtrArgs);
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
      for (lIdxChannel = iNbrChannels-1; lIdxChannel >= 0; --lIdxChannel) {
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
    lPtrData = (t24bits*)(((int)lPtrData)+3*(((int)iNbrSamples)*iNbrChannels - 1));
    for (lIdxBufferSample = 0; lIdxBufferSample < iNbrSamples; ++lIdxBufferSample) {
      lProcessResult = 0;
      for (lIdxChannel = iNbrChannels-1; lIdxChannel >= 0; --lIdxChannel) {
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
