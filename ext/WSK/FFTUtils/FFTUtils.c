/**
 * Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
 * Licensed under the terms specified in LICENSE file. No warranty is provided.
 **/

#include "ruby.h"
#include <math.h>
#include <stdio.h>
#include <CommonUtils.h>

#include <gmp.h>

// Type used to compute FFT calculations
typedef long long int tFFTValue;

// Struct used to convey data among iterators in the completeSumCosSin method
typedef struct {
  int nbrFreq;
  double* w;
  tFFTValue* sumCos;
  tFFTValue* sumSin;
  int* ptrIdxSum;
  int nbrChannels;
  double** cosCache;
  double** sinCache;
} tCompleteSumCosSinStruct;

// Struct that contains the trigo cache
typedef struct {
  int nbrFreq;
  double** cosCache;
  double** sinCache;
} tTrigoCache;

// Struct that contains a C FFT profile
typedef struct {
  int nbrFreq;
  int nbrChannels;
  mpf_t** profile;
  mpf_t maxFFTValue;
} tFFTProfile;

/** Create a ruby object storing the Wi coefficients used to compute the sin and cos sums
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): The object containing this method
 * * *iValIdxFirstFreq* (_Integer_): First frequency index to generate the array of Wi
 * * *iValIdxLastFreq* (_Integer_): Last frequency index to generate the array of Wi
 * * *iValSampleRate* (_Integer_): The sample rate
 * Return::
 * * _Object_: The container of Wi series
 **/
static VALUE fftutils_createWi(
  VALUE iSelf,
  VALUE iValIdxFirstFreq,
  VALUE iValIdxLastFreq,
  VALUE iValSampleRate) {
  int lIdxFirstFreq = FIX2INT(iValIdxFirstFreq);
  int lIdxLastFreq = FIX2INT(iValIdxLastFreq);
  int lSampleRate = FIX2INT(iValSampleRate);

  // For each frequency index i, we have
  // Fi = Sum(t=0..N-1, Xt * cos( Wi * t ) )^2 + Sum(t=0..N-1, Xt * sin( Wi * t ) )^2
  // With N = Number of samples, Xt the sample number t, and Wi = -2*Pi*440*2^(i/12)/S, with S = sample rate
  double * lW = ALLOC_N(double, lIdxLastFreq-lIdxFirstFreq+1);
  // Define the common multipler (-880*PI)
  double lCommonMultiplier = -3520.0*atan2(1.0, 1.0);

  int lIdxFreq;
  double lDblSampleRate = (double)lSampleRate;
  for (lIdxFreq = lIdxFirstFreq; lIdxFreq < lIdxLastFreq + 1; ++lIdxFreq) {
    lW[lIdxFreq-lIdxFirstFreq] = (lCommonMultiplier*(pow(2.0,(((double)lIdxFreq)/12.0))))/lDblSampleRate;
  }

  // Encapsulate it
  return Data_Wrap_Struct(rb_cObject, NULL, free, lW);
}

/** Create empty arrays of tFFTValues to be used for sin and cos sums
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValNbrFreq* (_Integer_): Number of frequencies to store
 * * *iValNbrChannels* (_Integer_): Number of channels
 * Return::
 * * _Object_: An encapsulated array for computation
 **/
static VALUE fftutils_initSumArray(
  VALUE iSelf,
  VALUE iValNbrFreq,
  VALUE iValNbrChannels) {
  VALUE rValContainer;
  int lNbrFreq = FIX2INT(iValNbrFreq);
  int lNbrChannels = FIX2INT(iValNbrChannels);

  tFFTValue * lSumArray = ALLOC_N(tFFTValue, lNbrFreq*lNbrChannels);
  // Fill it with 0
  memset(lSumArray, 0, lNbrFreq*lNbrChannels*sizeof(tFFTValue));

  // Encapsulate it
  rValContainer = Data_Wrap_Struct(rb_cObject, NULL, free, lSumArray);

  return rValContainer;
}

/**
 * Process a value read from an input buffer for the CompleteSumCosSin function.
 *
 * Parameters::
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tNextSilentStruct*</em>.
 * Return::
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int fftutils_processValue_CompleteSumCosSin(
  const tSampleValue iValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  // Interpret parameters
  tCompleteSumCosSinStruct* lPtrVariables = (tCompleteSumCosSinStruct*)iPtrArgs;

  if (iIdxChannel == 0) {
    *(lPtrVariables->ptrIdxSum) = 0;
  }
  long double lTrigoValue;
  int lIdxW;
  for (lIdxW = 0; lIdxW < lPtrVariables->nbrFreq; ++lIdxW) {
    lTrigoValue = ((long double)lPtrVariables->w[lIdxW]) * ((long double)iIdxSample);
    lPtrVariables->sumCos[*(lPtrVariables->ptrIdxSum)] += (tFFTValue)(iValue*cos(lTrigoValue));
    lPtrVariables->sumSin[*(lPtrVariables->ptrIdxSum)] += (tFFTValue)(iValue*sin(lTrigoValue));
    ++(*(lPtrVariables->ptrIdxSum));
  }

  return 0;
}

/**
 * Process a value read from an input buffer for the CompleteSumCosSin function.
 * Use the trigo cache.
 *
 * Parameters::
 * * *iValue* (<em>const tSampleValue</em>): The value being read
 * * *iIdxSample* (<em>const tSampleIndex</em>): Index of this sample
 * * *iIdxChannel* (<em>const int</em>): Channel corresponding to the value being read
 * * *iPtrArgs* (<em>void*</em>): additional arguments. In fact a <em>tNextSilentStruct*</em>.
 * Return::
 * * _int_: The return code:
 * ** 0: Continue iteration
 * ** 1: Break all iterations
 * ** 2: Skip directly to the next sample (don't call us for other channels of this sample)
 */
int fftutils_processValue_CompleteSumCosSinWithCache(
  const tSampleValue iValue,
  const tSampleIndex iIdxSample,
  const int iIdxChannel,
  void* iPtrArgs) {
  // Interpret parameters
  tCompleteSumCosSinStruct* lPtrVariables = (tCompleteSumCosSinStruct*)iPtrArgs;

  if (iIdxChannel == 0) {
    *(lPtrVariables->ptrIdxSum) = 0;
  }
  int lIdxW;
  for (lIdxW = 0; lIdxW < lPtrVariables->nbrFreq; ++lIdxW) {
    lPtrVariables->sumCos[*(lPtrVariables->ptrIdxSum)] += (tFFTValue)(iValue*lPtrVariables->cosCache[lIdxW][iIdxSample]);
    lPtrVariables->sumSin[*(lPtrVariables->ptrIdxSum)] += (tFFTValue)(iValue*lPtrVariables->sinCache[lIdxW][iIdxSample]);
    ++(*(lPtrVariables->ptrIdxSum));
  }

  return 0;
}

/** Complete the cosinus et sinus sums to compute the FFT
 * 
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValInputRawBuffer* (_String_): The input raw buffer
 * * *iValIdxSample* (_Integer_): The current sample index (to be used when several buffers are used for the same FFT)
 * * *iValNbrBitsPerSample* (_Integer_): The number of bits per sample
 * * *iValNbrSamples* (_Integer_): The number of samples
 * * *iValNbrChannels* (_Integer_): The number of channels
 * * *iValNbrFreq* (_Integer_): The number of frequencies to compute (size of array contained in iValW)
 * * *iValW* (_Object_): Container of the Wi (should be initialized with createWi), or nil if none. Either use W or TrigoCache.
 * * *iValTrigoCache* (_Object_): Container of the trigo cache (should be initialized with initTrigoCache), or nil if none. Either use W or TrigoCache.
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
  VALUE iValTrigoCache,
  VALUE ioValSumCos,
  VALUE ioValSumSin) {
  // Translate Ruby objects
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  int iNbrChannels = FIX2INT(iValNbrChannels);
  int iNbrFreq = FIX2INT(iValNbrFreq);
  int iNbrBitsPerSample = FIX2INT(iValNbrBitsPerSample);
  char* lPtrRawBuffer = RSTRING(iValInputRawBuffer)->ptr;
  tSampleIndex iIdxSample = FIX2LONG(iValIdxSample);
  // Get the lW array
  double * lW = NULL;
  if (iValW != Qnil) {
    Data_Get_Struct(iValW, double, lW);
  }
  // Get the trigo cache
  tTrigoCache* lPtrTrigoCache = NULL;
  if (iValTrigoCache != Qnil) {
    Data_Get_Struct(iValTrigoCache, tTrigoCache, lPtrTrigoCache);
  }
  // Get the cos and sin sum arrays
  tFFTValue * lSumCos;
  tFFTValue * lSumSin;
  Data_Get_Struct(ioValSumCos, tFFTValue, lSumCos);
  Data_Get_Struct(ioValSumSin, tFFTValue, lSumSin);
  
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  int lIdxSum = 0;

  // Set variables to give to the process
  tCompleteSumCosSinStruct lProcessVariables;
  lProcessVariables.nbrFreq = iNbrFreq;
  lProcessVariables.w = lW;
  lProcessVariables.sumCos = lSumCos;
  lProcessVariables.sumSin = lSumSin;
  lProcessVariables.ptrIdxSum = &lIdxSum;
  lProcessVariables.nbrChannels = iNbrChannels;
  if (lPtrTrigoCache == NULL) {
    // Iterate through the raw buffer
    commonutils_iterateThroughRawBuffer(
      lPtrRawBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      iIdxSample,
      &fftutils_processValue_CompleteSumCosSin,
      &lProcessVariables
    );
  } else {
    lProcessVariables.cosCache = lPtrTrigoCache->cosCache;
    lProcessVariables.sinCache = lPtrTrigoCache->sinCache;
    // Iterate through the raw buffer by using the cache
    commonutils_iterateThroughRawBuffer(
      lPtrRawBuffer,
      iNbrBitsPerSample,
      iNbrChannels,
      iNbrSamples,
      iIdxSample,
      &fftutils_processValue_CompleteSumCosSinWithCache,
      &lProcessVariables
    );
  }

  return Qnil;
}

/** Compute the final FFT coefficients in Ruby integers, per channel and per frequency.
 * Use previously computed cos and sin sum arrays.
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValNbrChannels* (_Integer_): The number of channels
 * * *iValNbrFreq* (_Integer_): The number of frequencies to compute (size of array contained in iValW)
 * * *iValSumCos* (_Object_): Container of the cos sums (should be initialized with initSumArray)
 * * *iValSumSin* (_Object_): Container of the sin sums (should be initialized with initSumArray)
 * Return::
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
  tFFTValue * lSumCos;
  tFFTValue * lSumSin;
  Data_Get_Struct(iValSumCos, tFFTValue, lSumCos);
  Data_Get_Struct(iValSumSin, tFFTValue, lSumSin);
  // The C-array of the final result
  VALUE lValFFT[lNbrFreq];

  int lIdxFreq;
  int lIdxChannel;
  int lIdxSum;
  // Buffer that stores string representation of tFFTValue for Ruby RBigNum
  char lStrValue[128];
  // The bignums to put in the result
  VALUE lValChannelFFTs[lNbrChannels];
  mpz_t lSinSin;
  mpz_init(lSinSin);
  mpz_t lFFTCoeff;
  mpz_init(lFFTCoeff);
  // Put back the cos and sin values in the result, summing their square values
  for (lIdxFreq = 0; lIdxFreq < lNbrFreq; ++lIdxFreq) {
    lIdxSum = lIdxFreq;
    for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
      // Initialize MPZ with char* as they don't accept long long int.
      sprintf(lStrValue, "%lld", lSumSin[lIdxSum]);
      mpz_set_str(lSinSin, lStrValue, 10);
      mpz_mul(lSinSin, lSinSin, lSinSin);
      sprintf(lStrValue, "%lld", lSumCos[lIdxSum]);
      mpz_set_str(lFFTCoeff, lStrValue, 10);
      mpz_mul(lFFTCoeff, lFFTCoeff, lFFTCoeff);
      mpz_add(lFFTCoeff, lFFTCoeff, lSinSin);
      lValChannelFFTs[lIdxChannel] = rb_cstr2inum(mpz_get_str(lStrValue, 16, lFFTCoeff), 16);
      lIdxSum += lNbrFreq;
    }
    lValFFT[lIdxFreq] = rb_ary_new4(lNbrChannels, lValChannelFFTs);
  }
  mpz_clear(lFFTCoeff);
  mpz_clear(lSinSin);

  return rb_ary_new4(lNbrFreq, lValFFT);
}
/* To be used if GMP library is absent.
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
  tFFTValue * lSumCos;
  tFFTValue * lSumSin;
  Data_Get_Struct(iValSumCos, tFFTValue, lSumCos);
  Data_Get_Struct(iValSumSin, tFFTValue, lSumSin);
  // The C-array of the final result
  VALUE lValFFT[lNbrFreq];
  ID lPlusID = rb_intern("+");
  ID lMultiplyID = rb_intern("*");

  int lIdxFreq;
  int lIdxChannel;
  int lIdxSum;
  // Buffer that stores string representation of tFFTValue for Ruby RBigNum
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
    lIdxSum = lIdxFreq;
    for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
      // Initialize Ruby objects for the arithmetic, as C will not treat numbers greater than 64 bits.
      sprintf(lStrValue, "%lld", lSumCos[lIdxSum]);
      lValCos = rb_cstr2inum(lStrValue, 10);
      sprintf(lStrValue, "%lld", lSumSin[lIdxSum]);
      lValSin = rb_cstr2inum(lStrValue, 10);
      lValCosCos = rb_funcall(lValCos, lMultiplyID, 1, lValCos);
      lValSinSin = rb_funcall(lValSin, lMultiplyID, 1, lValSin);
      lValChannelFFTs[lIdxChannel] = rb_funcall(lValCosCos, lPlusID, 1, lValSinSin);
      lIdxSum += lNbrFreq;
    }
    lValFFT[lIdxFreq] = rb_ary_new4(lNbrChannels, lValChannelFFTs);
  }

  return rb_ary_new4(lNbrFreq, lValFFT);
}
*/

/**
 * Free a trigonometric cache.
 * This method is called by Ruby GC.
 *
 * Parameters::
 * * *iPtrTrigoCache* (<em>void*</em>): The trigo cache to free (in fact a <em>tTrigoCache*</em>)
 */
static void fftutils_freeTrigoCache(void* iPtrTrigoCache) {
  tTrigoCache* lPtrTrigoCache = (tTrigoCache*)iPtrTrigoCache;

  int lIdxW;
  for (lIdxW = 0; lIdxW < lPtrTrigoCache->nbrFreq; ++lIdxW) {
    // Free it
    free(lPtrTrigoCache->cosCache[lIdxW]);
    free(lPtrTrigoCache->sinCache[lIdxW]);
  }
  free(lPtrTrigoCache->cosCache);
  free(lPtrTrigoCache->sinCache);
}

/**
 * Create a cache of trigonometric values that will be then used in completeSumCosSin method
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValW* (_Object_): Container of the W coefficients (initialized using createWi)
 * * *iValNbrFreq* (_Integer_): The number of frequencies in the W coefficients
 * * *iValNbrSamples* (_Integer_): Number of samples for which we create the cache
 * Return::
 * * _Object_: Container of the trigonometric cache
 */
static VALUE fftutils_initTrigoCache(
  VALUE iSelf,
  VALUE iValW,
  VALUE iValNbrFreq,
  VALUE iValNbrSamples) {
  // Translate parameters in C types
  int iNbrFreq = FIX2INT(iValNbrFreq);
  tSampleIndex iNbrSamples = FIX2LONG(iValNbrSamples);
  // Get the lW array
  double * lW;
  Data_Get_Struct(iValW, double, lW);

  // Create the cache
  int lIdxW;
  tSampleIndex lIdxSample;
  double* lTmpSamplesValuesCos;
  double* lTmpSamplesValuesSin;
  double lTrigoValue;
  tTrigoCache* lPtrTrigoCache = ALLOC(tTrigoCache);
  lPtrTrigoCache->cosCache = ALLOC_N(double*, iNbrFreq);
  lPtrTrigoCache->sinCache = ALLOC_N(double*, iNbrFreq);
  lPtrTrigoCache->nbrFreq = iNbrFreq;
  for (lIdxW = 0; lIdxW < iNbrFreq; ++lIdxW) {
    // Allocate the double array storing values for each sample
    lTmpSamplesValuesCos = ALLOC_N(double, iNbrSamples);
    lTmpSamplesValuesSin = ALLOC_N(double, iNbrSamples);
    // Fill it
    for (lIdxSample = 0; lIdxSample < iNbrSamples; ++lIdxSample) {
      lTrigoValue = lIdxSample*lW[lIdxW];
      lTmpSamplesValuesCos[lIdxSample] = cos(lTrigoValue);
      lTmpSamplesValuesSin[lIdxSample] = sin(lTrigoValue);
    }
    // Store it
    lPtrTrigoCache->cosCache[lIdxW] = lTmpSamplesValuesCos;
    lPtrTrigoCache->sinCache[lIdxW] = lTmpSamplesValuesSin;
  }

  // Encapsulate it in a Ruby object
  return Data_Wrap_Struct(rb_cObject, NULL, fftutils_freeTrigoCache, lPtrTrigoCache);
}

/**
 * Initialize an MPF number based on a Ruby's fixnum.
 *
 * Parameters::
 * * *ioMPF* (<em>mpf_t</em>): The mpf to initialize
 * * *iValInt* (_Integer_): The Ruby integer
 * Return::
 * * _int_: The result code of the set
 */
inline int initMPF(
  mpf_t ioMPF,
  VALUE iValInt) {
  return mpf_init_set_str(ioMPF, RSTRING(rb_big2str(iValInt, 16))->ptr, 16);
}

/**
 * Get a Ruby integer based on an MPF storing an integer value.
 * Prerequisite: The MPF value must be truncated before calling this function.
 *
 * Parameters::
 * * *iMPF* (<em>mpf_t</em>): The mpf to read
 * Return::
 * * _Integer_: The Ruby integer
 */
#define MAX_NUMBER_DIGITS 256
VALUE mpf2RubyInt(
  mpf_t iMPF) {
  // The buffer where it will be written
  char lStrNumber[MAX_NUMBER_DIGITS];
  // The exponent part. Used to add trailing 0s.
  mp_exp_t lExp;
  // Fill the string with the mantissa part
  mpf_get_str(lStrNumber, &lExp, 16, MAX_NUMBER_DIGITS, iMPF);
  int lStrSize = strlen(lStrNumber);
  if (lExp-lStrSize > 0) {
    // We need to add (lExp-lStrSize) trailing 0s.
    char* lPtrStrNumber = lStrNumber + lStrSize;
    memset(lPtrStrNumber, '0', lExp-lStrSize);
    lPtrStrNumber[lExp-lStrSize] = 0;
  }

  return rb_cstr2inum(lStrNumber, 16);
}

/**
 * Free an FFT profile.
 * This method is called by Ruby GC.
 *
 * Parameters::
 * * *iPtrFFTProfile* (<em>void*</em>): The FFT profile to free (in fact a <em>tFFTProfile*</em>)
 */
static void fftutils_freeFFTProfile(void* iPtrFFTProfile) {
  tFFTProfile* lPtrFFTProfile = (tFFTProfile*)iPtrFFTProfile;

  int lIdxFreq;
  int lIdxChannel;
  mpf_t* lPtrChannelValues;
  for (lIdxFreq = 0; lIdxFreq < lPtrFFTProfile->nbrFreq; ++lIdxFreq) {
    lPtrChannelValues = lPtrFFTProfile->profile[lIdxFreq];
    for (lIdxChannel = 0; lIdxChannel < lPtrFFTProfile->nbrChannels; ++lIdxChannel) {
      mpf_clear(lPtrChannelValues[lIdxChannel]);
    }
    // Free it
    free(lPtrFFTProfile->profile[lIdxFreq]);
  }
  mpf_clear(lPtrFFTProfile->maxFFTValue);
  free(lPtrFFTProfile->profile);
}

/**
 * Initialize a C object storing a profile
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValFFTProfile* (<em>[Integer,Integer,list<list<Integer>>]</em>): FFT Profile
 * Return::
 * * _Object_: Object storing a C FFT Profile, to be used with other C functions
 */
static VALUE fftutils_createCFFTProfile(
  VALUE iSelf,
  VALUE iValFFTProfile) {
  // The C profile
  tFFTProfile* lPtrFFTProfile = ALLOC(tFFTProfile);
  int lNbrBitsPerSample = FIX2INT(rb_ary_entry(iValFFTProfile, 0));
  tSampleIndex lNbrSamples = FIX2LONG(rb_ary_entry(iValFFTProfile, 1));
  VALUE lValFFTCoeffs = rb_ary_entry(iValFFTProfile, 2);
  lPtrFFTProfile->nbrFreq = RARRAY(lValFFTCoeffs)->len;
  lPtrFFTProfile->nbrChannels = RARRAY(rb_ary_entry(lValFFTCoeffs, 0))->len;

  // Compute the maximal values
  mpf_init_set_ui(lPtrFFTProfile->maxFFTValue, 1 << (lNbrBitsPerSample-1));
  mpf_mul_ui(lPtrFFTProfile->maxFFTValue, lPtrFFTProfile->maxFFTValue, lNbrSamples);
  mpf_mul(lPtrFFTProfile->maxFFTValue, lPtrFFTProfile->maxFFTValue, lPtrFFTProfile->maxFFTValue);
  mpf_add(lPtrFFTProfile->maxFFTValue, lPtrFFTProfile->maxFFTValue, lPtrFFTProfile->maxFFTValue);

  // Fill the C structure
  lPtrFFTProfile->profile = ALLOC_N(mpf_t*, lPtrFFTProfile->nbrFreq);
  mpf_t* lPtrChannelValues;
  VALUE lValChannelValues;
  int lConvertResult = 0;
  int lIdxFreq;
  int lIdxChannel;
  for (lIdxFreq = 0; lIdxFreq < lPtrFFTProfile->nbrFreq; ++lIdxFreq) {
    lValChannelValues = rb_ary_entry(lValFFTCoeffs, lIdxFreq);
    lPtrChannelValues = ALLOC_N(mpf_t, lPtrFFTProfile->nbrChannels);
    for (lIdxChannel = 0; lIdxChannel < lPtrFFTProfile->nbrChannels; ++lIdxChannel) {
      lConvertResult += initMPF(lPtrChannelValues[lIdxChannel], rb_ary_entry(lValChannelValues, lIdxChannel));
    }
    lPtrFFTProfile->profile[lIdxFreq] = lPtrChannelValues;
  }
  if (lConvertResult != 0) {
    // Errors occured
    char lLogMessage[256];
    sprintf(lLogMessage, "%d errors occurred while creating the C FFT profile.", -lConvertResult);
    rb_funcall(iSelf, rb_intern("log_err"), 1, rb_str_new2(lLogMessage));
  }

  // Encapsulate it in a Ruby object
  return Data_Wrap_Struct(rb_cObject, NULL, fftutils_freeFFTProfile, lPtrFFTProfile);
}

/**
 * Compare 2 FFT profiles and measure their distance.
 * Here is an FFT profile structure:
 * [ Integer,          Integer,    list<list<Integer>> ]
 * [ NbrBitsPerSample, NbrSamples, FFTValues ]
 * FFTValues are declined per channel, per frequency index.
 * Bits per sample and number of samples are taken into account to relatively compare the profiles.
 *
 * Parameters::
 * * *iSelf* (_FFTUtils_): Self
 * * *iValProfile1* (_Object_): Profile 1, initialized by createCFFTProfile.
 * * *iValProfile2* (_Object_): Profile 2, initialized by createCFFTProfile.
 * * *iValScale* (_Integer_): The scale used to compute values
 * Return::
 * * _Integer_: Distance (Profile 2 - Profile 1).
 */
static VALUE fftutils_distFFTProfiles(
  VALUE iSelf,
  VALUE iValProfile1,
  VALUE iValProfile2,
  VALUE iValScale) {
  // Translate parameters in C types
  mpf_t iScale;
  initMPF(iScale, iValScale);
  // Get the FFT Profiles
  tFFTProfile* lPtrFFTProfile1;
  Data_Get_Struct(iValProfile1, tFFTProfile, lPtrFFTProfile1);
  tFFTProfile* lPtrFFTProfile2;
  Data_Get_Struct(iValProfile2, tFFTProfile, lPtrFFTProfile2);

  // Return the max of the distances of each frequency coefficient
  mpf_t lMaxDist;
  mpf_init_set_ui(lMaxDist, 0);
  
  int lIdxFreq;
  int lIdxChannel;
  mpf_t* lPtrChannelValues1;
  mpf_t* lPtrChannelValues2;
  mpf_t lDist;
  mpf_init(lDist);
  mpf_t lDist2;
  mpf_init(lDist2);

  for (lIdxFreq = 0; lIdxFreq < lPtrFFTProfile1->nbrFreq; ++lIdxFreq) {
    lPtrChannelValues1 = lPtrFFTProfile1->profile[lIdxFreq];
    lPtrChannelValues2 = lPtrFFTProfile2->profile[lIdxFreq];
    for (lIdxChannel = 0; lIdxChannel < lPtrFFTProfile1->nbrChannels; ++lIdxChannel) {
      // Compute iFFT2Value - iFFT1Value, on a scale of iScale
      mpf_div(lDist, lPtrChannelValues2[lIdxChannel], lPtrFFTProfile2->maxFFTValue);
      mpf_div(lDist2, lPtrChannelValues1[lIdxChannel], lPtrFFTProfile1->maxFFTValue);
      mpf_sub(lDist, lDist, lDist2);
      if (mpf_cmp(lDist, lMaxDist) > 0) {
        mpf_set(lMaxDist, lDist);
      }
    }
  }
  // Apply the scale
  mpf_mul(lMaxDist, lMaxDist, iScale);
  mpf_trunc(lMaxDist, lMaxDist);
  // Get the Ruby result
  VALUE rValDistance = mpf2RubyInt(lMaxDist);

  // Clean memory
  mpf_clear(lDist2);
  mpf_clear(lDist);
  mpf_clear(lMaxDist);
  mpf_clear(iScale);

  return rValDistance;
}

// Initialize the module
void Init_FFTUtils() {
  VALUE lWSKModule = rb_define_module("WSK");
  VALUE lFFTUtilsModule = rb_define_module_under(lWSKModule, "FFTUtils");
  VALUE lFFTUtilsClass = rb_define_class_under(lFFTUtilsModule, "FFTUtils", rb_cObject);
  
  rb_define_method(lFFTUtilsClass, "completeSumCosSin", fftutils_completeSumCosSin, 10);
  rb_define_method(lFFTUtilsClass, "createWi", fftutils_createWi, 3);
  rb_define_method(lFFTUtilsClass, "initSumArray", fftutils_initSumArray, 2);
  rb_define_method(lFFTUtilsClass, "initTrigoCache", fftutils_initTrigoCache, 3);
  rb_define_method(lFFTUtilsClass, "computeFFT", fftutils_computeFFT, 4);
  rb_define_method(lFFTUtilsClass, "createCFFTProfile", fftutils_createCFFTProfile, 1);
  rb_define_method(lFFTUtilsClass, "distFFTProfiles", fftutils_distFFTProfiles, 3);
}
