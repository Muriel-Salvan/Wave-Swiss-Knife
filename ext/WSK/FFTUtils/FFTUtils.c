#include "ruby.h"
#include <math.h>
#include <stdio.h>

// Struct used to interpret raw buffers data
typedef struct {
  signed int value:24;
} t24bits;

/** Create a ruby object storing the Wi coefficients used to compute the sin and cos sums
 *
 * Parameters:
 * * *iSelf* (_FFT_): The object containing this method
 * * *iValIdxFirstFreq* (_Integer_): First frequency index to generate the array of Wi
 * * *iValIdxLastFreq* (_Integer_): Last frequency index to generate the array of Wi
 * * *iValSampleRate* (_Integer_): The sample rate
 * Return:
 * * _Object_: The container of Wi series
 **/
static VALUE fftutils_createWi(
  VALUE iSelf,
  VALUE iValIdxFirstFreq,
  VALUE iValIdxLastFreq,
  VALUE iValSampleRate) {
  VALUE rValContainer;
  int lIdxFirstFreq = FIX2INT(iValIdxFirstFreq);
  int lIdxLastFreq = FIX2INT(iValIdxLastFreq);
  int lSampleRate = FIX2INT(iValSampleRate);

  double * lW = ALLOC_N(double, lIdxLastFreq-lIdxFirstFreq+1);
  // Define the common multipler (-880*PI)
  double lCommonMultiplier = -3520.0*atan2(1.0, 1.0);

  int lIdxFreq;
  double lDblSampleRate = (double)lSampleRate;
  for (lIdxFreq = lIdxFirstFreq; lIdxFreq < lIdxLastFreq + 1; ++lIdxFreq) {
    lW[lIdxFreq-lIdxFirstFreq] = (lCommonMultiplier*(pow(2.0,(((double)lIdxFreq)/12.0))))/lDblSampleRate;
  }

  // Encapsulate it
  rValContainer = Data_Wrap_Struct(rb_cObject, NULL, free, lW);

  return rValContainer;
}

/** Create empty arrays of long long integers to be used for sin and cos sums
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValNbrFreq* (_Integer_): Number of frequencies to store
 * * *iValNbrChannels* (_Integer_): Number of channels
 * Return:
 * * _Object_: An encapsulated array for computation
 **/
static VALUE fftutils_initSumArray(
  VALUE iSelf,
  VALUE iValNbrFreq,
  VALUE iValNbrChannels) {
  VALUE rValContainer;
  int lNbrFreq = FIX2INT(iValNbrFreq);
  int lNbrChannels = FIX2INT(iValNbrChannels);

  long long int * lSumArray = ALLOC_N(long long int, lNbrFreq*lNbrChannels);
  // Fill it with 0
  memset(lSumArray, 0, lNbrFreq*lNbrChannels*sizeof(long long int));

  // Encapsulate it
  rValContainer = Data_Wrap_Struct(rb_cObject, NULL, free, lSumArray);

  return rValContainer;
}

/** Complete the cosinus et sinus sums to compute the FFT
 * 
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValInputRawBuffer* (_String_): The input raw buffer
 * * *iValIdxSample* (_Integer_): The current sample index (to be used when several buffers are used for the same FFT)
 * * *iValNbrBitsPerSample* (_Integer_): The number of bits per sample
 * * *iValNbrSamples* (_Integer_): The number of samples
 * * *iValNbrChannels* (_Integer_): The number of channels
 * * *iValNbrFreq* (_Integer_): The number of frequencies to compute (size of array contained in iValW)
 * * *iValW* (_Object_): Container of the Wi (should be initialized with createWi)
 * * *ioValSumCos* (_Object_): Container of the cos sums (should be initialized with initSumArray)
 * * *ioValSumSin* (_Object_): Container of the sin sums (should be initialized with initSumArray)
 **/
static VALUE fftutils_completeSumCosSin(
  VALUE iSelf,
  VALUE iValInputRawBuffer,
  VALUE iValIdxSample,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrSamples,
  VALUE iValNbrChannels,
  VALUE iValNbrFreq,
  VALUE iValW,
  VALUE ioValSumCos,
  VALUE ioValSumSin) {
  // Translate Ruby objects
  int lNbrSamples = FIX2INT(iValNbrSamples);
  int lNbrChannels = FIX2INT(iValNbrChannels);
  int lNbrFreq = FIX2INT(iValNbrFreq);
  int lNbrBitsPerSample = FIX2LONG(iValNbrBitsPerSample);
  char* lPtrRawBuffer = RSTRING(iValInputRawBuffer)->ptr;
  long lIdxSample = FIX2LONG(iValIdxSample);
  // Get the lW array
  double * lW;
  Data_Get_Struct(iValW, double, lW);
  // Get the cos and sin sum arrays
  long long int * lSumCos;
  long long int * lSumSin;
  Data_Get_Struct(ioValSumCos, long long int, lSumCos);
  Data_Get_Struct(ioValSumSin, long long int, lSumSin);
  
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  int lIdxBufferSample;
  int lIdxChannel;
  int lIdxW;
  double lTrigoValue;
  int lIdxSum;
  double lValue;
  if (lNbrBitsPerSample == 8) {
    unsigned char* lPtrData = (unsigned char*)lPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < lNbrSamples; ++lIdxBufferSample) {
      lIdxSum = 0;
      for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
        lValue = (double)((*lPtrData) - 128);
        for (lIdxW = 0; lIdxW < lNbrFreq; ++lIdxW) {
          lTrigoValue = lW[lIdxW] * lIdxSample;
          lSumCos[lIdxSum] += (long long int)(lValue*cos(lTrigoValue));
          lSumSin[lIdxSum] += (long long int)(lValue*sin(lTrigoValue));
          ++lIdxSum;
        }
        ++lPtrData;
      }
      ++lIdxSample;
    }
  } else if (lNbrBitsPerSample == 16) {
    signed short int* lPtrData = (signed short int*)lPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < lNbrSamples; ++lIdxBufferSample) {
      lIdxSum = 0;
      for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
        lValue = (double)(*lPtrData);
        for (lIdxW = 0; lIdxW < lNbrFreq; ++lIdxW) {
          lTrigoValue = lW[lIdxW] * lIdxSample;
          lSumCos[lIdxSum] += (long long int)(lValue*cos(lTrigoValue));
          lSumSin[lIdxSum] += (long long int)(lValue*sin(lTrigoValue));
          ++lIdxSum;
        }
        ++lPtrData;
      }
      ++lIdxSample;
    }
  } else if (lNbrBitsPerSample == 24) {
    t24bits* lPtrData = (t24bits*)lPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < lNbrSamples; ++lIdxBufferSample) {
      lIdxSum = 0;
      for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
        lValue = (double)(lPtrData->value);
        for (lIdxW = 0; lIdxW < lNbrFreq; ++lIdxW) {
          lTrigoValue = lW[lIdxW] * lIdxSample;
          lSumCos[lIdxSum] += (long long int)(lValue*cos(lTrigoValue));
          lSumSin[lIdxSum] += (long long int)(lValue*sin(lTrigoValue));
          ++lIdxSum;
        }
        // Increase lPtrData this way to ensure alignment.
        lPtrData = (t24bits*)(((int)lPtrData)+3);
      }
      ++lIdxSample;
    }
  } else {
    rb_raise(rb_eRuntimeError, "Unknown bits per samples: %d\n", lNbrBitsPerSample);
  }

  return Qnil;
}

/** Compute the final FFT coefficients in Ruby integers, per channel and per frequency.
 * Use previously computed cos and sin sum arrays.
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValNbrChannels* (_Integer_): The number of channels
 * * *iValNbrFreq* (_Integer_): The number of frequencies to compute (size of array contained in iValW)
 * * *iValSumCos* (_Object_): Container of the cos sums (should be initialized with initSumArray)
 * * *iValSumSin* (_Object_): Container of the sin sums (should be initialized with initSumArray)
 * Return:
 * * <em>list<list<Integer>></em>: List of FFT coefficients, per channel, per frequency
 **/
static VALUE fftutils_computeFFT(
  VALUE iSelf,
  VALUE iValNbrChannels,
  VALUE iValNbrFreq,
  VALUE iValSumCos,
  VALUE iValSumSin) {
  // Translate Ruby objects
  int lNbrChannels = FIX2INT(iValNbrChannels);
  int lNbrFreq = FIX2INT(iValNbrFreq);
  // Get the cos and sin sum arrays
  long long int * lSumCos;
  long long int * lSumSin;
  Data_Get_Struct(iValSumCos, long long int, lSumCos);
  Data_Get_Struct(iValSumSin, long long int, lSumSin);
  // The C-array of the final result
  VALUE lValFFT[lNbrFreq];
  VALUE lPlusID = rb_intern("+");
  VALUE lMultiplyID = rb_intern("*");

  int lIdxFreq;
  int lIdxChannel;
  int lIdxSum;
  // Buffer that stores string representation of long long int for Ruby RBigNum
  char lStrValue[128];
  // RBigNums that will store temprary arithmetic results
  VALUE lValCos;
  VALUE lValSin;
  VALUE lValCosCos;
  VALUE lValSinSin;
  // The bignums to put in the result
  VALUE lValChannelFFTs[lNbrChannels];
  // Put back the cos and sin values in the result, summing their square values
  for (lIdxFreq = 0; lIdxFreq < lNbrFreq; ++lIdxFreq) {
    for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
      lIdxSum = lIdxChannel*lNbrFreq+lIdxFreq;
      // Initialize Ruby objects for the arithmetic, as C will not treat numbers greater than 64 bits.
      sprintf(lStrValue, "%lld", lSumCos[lIdxSum]);
      lValCos = rb_cstr2inum(lStrValue, 10);
      sprintf(lStrValue, "%lld", lSumSin[lIdxSum]);
      lValSin = rb_cstr2inum(lStrValue, 10);
      lValCosCos = rb_funcall(lValCos, lMultiplyID, 1, lValCos);
      lValSinSin = rb_funcall(lValSin, lMultiplyID, 1, lValSin);
      lValChannelFFTs[lIdxChannel] = rb_funcall(lValCosCos, lPlusID, 1, lValSinSin);
    }
    lValFFT[lIdxFreq] = rb_ary_new4(lNbrChannels, lValChannelFFTs);
  }

  return rb_ary_new4(lNbrFreq, lValFFT);
}

// Initialize the module
void Init_FFTUtils() {
  VALUE lWSKModule;
  VALUE lFFTUtilsModule;
  VALUE lFFTUtilsClass;
  
  lWSKModule = rb_define_module("WSK");
  lFFTUtilsModule = rb_define_module_under(lWSKModule, "FFTUtils");
  lFFTUtilsClass = rb_define_class_under(lFFTUtilsModule, "FFTUtils", rb_cObject);
  rb_define_method(lFFTUtilsClass, "completeSumCosSin", fftutils_completeSumCosSin, 9);
  rb_define_method(lFFTUtilsClass, "createWi", fftutils_createWi, 3);
  rb_define_method(lFFTUtilsClass, "initSumArray", fftutils_initSumArray, 2);
  rb_define_method(lFFTUtilsClass, "computeFFT", fftutils_computeFFT, 4);
}
