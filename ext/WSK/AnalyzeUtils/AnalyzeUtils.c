#include "ruby.h"
#include <math.h>
#include <stdio.h>

// Structure used to compute sum of squares
typedef struct {
  unsigned long long int high;
  unsigned long long int low;
} t128bits;

/** Add a 64 bits unsigned integer to a 128 bits unsigned integer
 *
 * Parameters:
 * * *ioPtrVal* (<em>t128bits*</em>): The 128 bits integer to modify
 * * *iAddValue* (<em>const unsigned long long int</em>): The value to add
 **/
inline void add128bits(t128bits* ioPtrVal, const unsigned long long int iAddValue) {
  unsigned long long int lOldLow = ioPtrVal->low;

  ioPtrVal->low += iAddValue;
  // check for overflow of low 64 bits, add carry to high
  if (ioPtrVal->low < lOldLow)
    ++ioPtrVal->high;
}

// Struct used to interpret raw buffers data
typedef struct {
  signed int value:24;
} t24bits;

/** Create empty arrays of long long integers to be used for various sums
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValNbrChannels* (_Integer_): Number of channels
 * * *iValInitialValue* (_Integer_): Initial value
 * Return:
 * * _Object_: An encapsulated array for computation
 **/
static VALUE analyzeutils_init64bitsArray(
  VALUE iSelf,
  VALUE iValNbrChannels,
  VALUE iValInitialValue) {
  VALUE rValContainer;
  int lNbrChannels = FIX2INT(iValNbrChannels);
  long long int lInitialValue = FIX2LONG(iValInitialValue);

  long long int * lSumArray = ALLOC_N(long long int, lNbrChannels);
  int lIdxChannel;
  for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
    lSumArray[lIdxChannel] = lInitialValue;
  }

  // Encapsulate it
  rValContainer = Data_Wrap_Struct(rb_cObject, NULL, free, lSumArray);

  return rValContainer;
}

/** Create empty arrays of 128 bits integers to be used for various sums
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValNbrChannels* (_Integer_): Number of channels
 * Return:
 * * _Object_: An encapsulated array for computation
 **/
static VALUE analyzeutils_init128bitsArray(
  VALUE iSelf,
  VALUE iValNbrChannels) {
  VALUE rValContainer;
  int lNbrChannels = FIX2INT(iValNbrChannels);

  t128bits * lSumArray = ALLOC_N(t128bits, lNbrChannels);
  // Fill it with 0
  memset(lSumArray, 0, lNbrChannels*sizeof(t128bits));

  // Encapsulate it
  rValContainer = Data_Wrap_Struct(rb_cObject, NULL, free, lSumArray);

  return rValContainer;
}

/** Complete the arrays of sums for analyzis
 * 
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValInputRawBuffer* (_String_): The input raw buffer
 * * *iValNbrBitsPerSample* (_Integer_): The number of bits per sample
 * * *iValNbrSamples* (_Integer_): The number of samples
 * * *iValNbrChannels* (_Integer_): The number of channels
 * * *ioValMaxValues* (_Object_): Container of the max values array (should be initialized with init64bitsArray)
 * * *ioValMinValues* (_Object_): Container of the min values array (should be initialized with init64bitsArray)
 * * *ioValSumValues* (_Object_): Container of the sum values array (should be initialized with init64bitsArray)
 * * *ioValAbsSumValues* (_Object_): Container of the abs sum values array (should be initialized with init64bitsArray)
 * * *ioValSquareSumValues* (_Object_): Container of the square sum values array (should be initialized with init128bitsArray)
 **/
static VALUE analyzeutils_completeAnalyze(
  VALUE iSelf,
  VALUE iValInputRawBuffer,
  VALUE iValNbrBitsPerSample,
  VALUE iValNbrSamples,
  VALUE iValNbrChannels,
  VALUE ioValMaxValues,
  VALUE ioValMinValues,
  VALUE ioValSumValues,
  VALUE ioValAbsSumValues,
  VALUE ioValSquareSumValues) {
  // Translate Ruby objects
  int lNbrSamples = FIX2INT(iValNbrSamples);
  int lNbrChannels = FIX2INT(iValNbrChannels);
  int lNbrBitsPerSample = FIX2LONG(iValNbrBitsPerSample);
  char* lPtrRawBuffer = RSTRING(iValInputRawBuffer)->ptr;
  // Get the arrays
  long long int * lMaxValues;
  long long int * lMinValues;
  long long int * lSumValues;
  long long int * lAbsSumValues;
  t128bits * lSquareSumValues;
  Data_Get_Struct(ioValMaxValues, long long int, lMaxValues);
  Data_Get_Struct(ioValMinValues, long long int, lMinValues);
  Data_Get_Struct(ioValSumValues, long long int, lSumValues);
  Data_Get_Struct(ioValAbsSumValues, long long int, lAbsSumValues);
  Data_Get_Struct(ioValSquareSumValues, t128bits, lSquareSumValues);
  
  // Parse the data. This is done differently depending on the data structure
  // Define variables outside the loops to not allocate and initialize heap size for nothing
  int lIdxBufferSample;
  int lIdxChannel;
  long long int lValue;
  if (lNbrBitsPerSample == 8) {
    unsigned char* lPtrData = (unsigned char*)lPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < lNbrSamples; ++lIdxBufferSample) {
      for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
        lValue = (long long int)((*lPtrData) - 128);
        if (lValue > lMaxValues[lIdxChannel]) {
          lMaxValues[lIdxChannel] = lValue;
        }
        if (lValue < lMinValues[lIdxChannel]) {
          lMinValues[lIdxChannel] = lValue;
        }
        lSumValues[lIdxChannel] += lValue;
        lAbsSumValues[lIdxChannel] += abs(lValue);
        add128bits(&(lSquareSumValues[lIdxChannel]), lValue*lValue);
        ++lPtrData;
      }
    }
  } else if (lNbrBitsPerSample == 16) {
    signed short int* lPtrData = (signed short int*)lPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < lNbrSamples; ++lIdxBufferSample) {
      for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
        lValue = (long long int)(*lPtrData);
        if (lValue > lMaxValues[lIdxChannel]) {
          lMaxValues[lIdxChannel] = lValue;
        }
        if (lValue < lMinValues[lIdxChannel]) {
          lMinValues[lIdxChannel] = lValue;
        }
        lSumValues[lIdxChannel] += lValue;
        lAbsSumValues[lIdxChannel] += abs(lValue);
        add128bits(&(lSquareSumValues[lIdxChannel]), lValue*lValue);
        ++lPtrData;
      }
    }
  } else if (lNbrBitsPerSample == 24) {
    t24bits* lPtrData = (t24bits*)lPtrRawBuffer;
    for (lIdxBufferSample = 0; lIdxBufferSample < lNbrSamples; ++lIdxBufferSample) {
      for (lIdxChannel = 0; lIdxChannel < lNbrChannels; ++lIdxChannel) {
        lValue = (long long int)(lPtrData->value);
        if (lValue > lMaxValues[lIdxChannel]) {
          lMaxValues[lIdxChannel] = lValue;
        }
        if (lValue < lMinValues[lIdxChannel]) {
          lMinValues[lIdxChannel] = lValue;
        }
        lSumValues[lIdxChannel] += lValue;
        lAbsSumValues[lIdxChannel] += abs(lValue);
        add128bits(&(lSquareSumValues[lIdxChannel]), lValue*lValue);
        // Increase lPtrData this way to ensure alignment.
        lPtrData = (t24bits*)(((int)lPtrData)+3);
      }
    }
  } else {
    rb_raise(rb_eRuntimeError, "Unknown bits per samples: %d\n", lNbrBitsPerSample);
  }

  return Qnil;
}

/** Get a Bignum Ruby arrays out of a 64bits C integers array
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValArray* (_Object_): Container of the array (should be initialized with init64bitsArray)
 * * *iValNbrItems* (_Integer_): The number of items in the array
 * Return:
 * * <em>list<Integer></em>: Corresponding Ruby array
 **/
static VALUE analyzeutils_getRuby64bitsArray(
  VALUE iSelf,
  VALUE iValArray,
  VALUE iValNbrItems) {
  // Translate Ruby objects
  int lNbrItems = FIX2INT(iValNbrItems);
  // Get the array
  long long int * lArray;
  Data_Get_Struct(iValArray, long long int, lArray);
  // The C-array of the final result
  VALUE lFinalArray[lNbrItems];

  // Buffer that stores string representation of long long int for Ruby RBigNum
  char lStrValue[128];
  int lIdxItem;
  for (lIdxItem = 0; lIdxItem < lNbrItems; ++lIdxItem) {
    sprintf(lStrValue, "%lld", lArray[lIdxItem]);
    lFinalArray[lIdxItem] = rb_cstr2inum(lStrValue, 10);
  }

  return rb_ary_new4(lNbrItems, lFinalArray);
}

/** Get a Bignum Ruby arrays out of a 128bits C integers array
 *
 * Parameters:
 * * *iSelf* (_FFT_): Self
 * * *iValArray* (_Object_): Container of the array (should be initialized with init128bitsArray)
 * * *iValNbrItems* (_Integer_): The number of items in the array
 * Return:
 * * <em>list<Integer></em>: Corresponding Ruby array
 **/
static VALUE analyzeutils_getRuby128bitsArray(
  VALUE iSelf,
  VALUE iValArray,
  VALUE iValNbrItems) {
  // Translate Ruby objects
  int lNbrItems = FIX2INT(iValNbrItems);
  // Get the array
  t128bits * lArray;
  Data_Get_Struct(iValArray, t128bits, lArray);
  // The C-array of the final result
  VALUE lFinalArray[lNbrItems];
  // Operations that will be used
  ID lPlusID = rb_intern("+");
  ID lMultiplyID = rb_intern("*");

  // Buffer that stores string representation of long long int for Ruby RBigNum
  char lStrValue[128];
  int lIdxItem;
  VALUE lValHigh;
  VALUE lValLow;
  VALUE lValHighShifted;
  // We will need to multiply High part by 2^64
  VALUE lValShiftFactor = rb_cstr2inum("18446744073709551616", 10);
  for (lIdxItem = 0; lIdxItem < lNbrItems; ++lIdxItem) {
    sprintf(lStrValue, "%llu", lArray[lIdxItem].high);
    lValHigh = rb_cstr2inum(lStrValue, 10);
    sprintf(lStrValue, "%llu", lArray[lIdxItem].low);
    lValLow = rb_cstr2inum(lStrValue, 10);
    lValHighShifted = rb_funcall(lValHigh, lMultiplyID, 1, lValShiftFactor);
    lFinalArray[lIdxItem] = rb_funcall(lValHighShifted, lPlusID, 1, lValLow);
  }

  return rb_ary_new4(lNbrItems, lFinalArray);
}

// Initialize the module
void Init_AnalyzeUtils() {
  VALUE lWSKModule;
  VALUE lAnalyzeUtilsModule;
  VALUE lAnalyzeUtilsClass;
  
  lWSKModule = rb_define_module("WSK");
  lAnalyzeUtilsModule = rb_define_module_under(lWSKModule, "AnalyzeUtils");
  lAnalyzeUtilsClass = rb_define_class_under(lAnalyzeUtilsModule, "AnalyzeUtils", rb_cObject);
  rb_define_method(lAnalyzeUtilsClass, "init64bitsArray", analyzeutils_init64bitsArray, 2);
  rb_define_method(lAnalyzeUtilsClass, "init128bitsArray", analyzeutils_init128bitsArray, 1);
  rb_define_method(lAnalyzeUtilsClass, "completeAnalyze", analyzeutils_completeAnalyze, 9);
  rb_define_method(lAnalyzeUtilsClass, "getRuby64bitsArray", analyzeutils_getRuby64bitsArray, 2);
  rb_define_method(lAnalyzeUtilsClass, "getRuby128bitsArray", analyzeutils_getRuby128bitsArray, 2);
}
