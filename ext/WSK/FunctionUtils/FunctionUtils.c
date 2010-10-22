#include "ruby.h"
#include <math.h>
#include <stdio.h>
#include <CommonUtils.h>
#include <gmp.h>

/**
 * Free a C function.
 * This method is called by Ruby GC.
 *
 * Parameters:
 * * *iPtrCFct* (<em>void*</em>): The C function to free (in fact a <em>tFunction*</em>)
 */
static void volumeutils_freeCFct(void* iPtrCFct) {
  tFunction* lPtrCFct = (tFunction*)iPtrCFct;

  if (lPtrCFct->freeFct != NULL) {
    (lPtrCFct->freeFct)(lPtrCFct->fctData);
  }
  free(lPtrCFct->fctData);
}

/**
 * Free a C function of type Piecewiese Linear.
 *
 * Parameters:
 * * *iPtrCFct* (<em>void*</em>): The C function to free (in fact a <em>tFunction_PiecewiseLinear*</em>)
 */
static void functionutils_freeCFct_PiecewiseLinear(void* iPtrCFct) {
  tFunction_PiecewiseLinear* lPtrCFct = (tFunction_PiecewiseLinear*)iPtrCFct;

  free(lPtrCFct->pointsX);
  free(lPtrCFct->pointsY);
}

static int gID_to_s;
static int gID_numerator;
static int gID_denominator;

/**
 * Convert a Ruby function value into a long double
 *
 * Parameters:
 * * *iValBD* (_Rational_): The value to convert
 * Return:
 * * <em>long double</em>: The equivalent long double
 */
inline long double value2ld(
  VALUE iValBD) {
  long double rResult;

  mpf_t lDenominator;
  mpf_init_set_str(lDenominator, RSTRING(rb_funcall(rb_funcall(iValBD, gID_denominator, 0), gID_to_s, 0))->ptr, 10);
  mpf_t lDivResult;
  mpf_init_set_str(lDivResult, RSTRING(rb_funcall(rb_funcall(iValBD, gID_numerator, 0), gID_to_s, 0))->ptr, 10);
  mpf_div(lDivResult, lDivResult, lDenominator);
  rResult = mpf_get_d(lDivResult);
  mpf_clear(lDivResult);
  mpf_clear(lDenominator);

  return rResult;
}

/**
 * Fill a C function with a given function of type Piecewise Linear
 *
 * Parameters:
 * * *oPtrCFunction* (<em>tFunction*</em>): The C function to fill
 * * *iValFunction* (<em>map<Symbol,Object></em>): The function to apply
 * * *iIdxBeginSample* (<em>tSampleIndex</em>): First sample beginning the function
 * * *iIdxEndSample* (<em>tSampleIndex</em>): Last sample ending the function
 */
static int functionutils_fillCFunction_PiecewiseLinear(
  tFunction* oPtrCFunction,
  VALUE iValFunction,
  tSampleIndex iIdxBeginSample,
  tSampleIndex iIdxEndSample) {
  int rResultCode = 0;
  
  // Create the basic structure
  tFunction_PiecewiseLinear* lPtrFctData = ALLOC(tFunction_PiecewiseLinear);
  oPtrCFunction->fctData = (void*)lPtrFctData;
  oPtrCFunction->freeFct = functionutils_freeCFct_PiecewiseLinear;
  
  // Fill it
  // Read points in a sorted list of couples [x,y]
  VALUE lValSortedPoints = rb_funcall(rb_funcall(rb_hash_aref(iValFunction, ID2SYM(rb_intern("Points"))), rb_intern("to_a"), 0), rb_intern("sort"), 0);
  int lNbrPoints = RARRAY(lValSortedPoints)->len;
  lPtrFctData->pointsX = ALLOC_N(tSampleIndex, lNbrPoints);
  lPtrFctData->pointsY = ALLOC_N(long double, lNbrPoints);

  // Get the X bounds
  long double lMinX = value2ld(rb_ary_entry(rb_ary_entry(lValSortedPoints, 0), 0));
  long double lDistX = value2ld(rb_ary_entry(rb_ary_entry(lValSortedPoints, lNbrPoints-1), 0))-lMinX;
  long double lDistSample = iIdxEndSample-iIdxBeginSample;

  // Loop on each points pair
  VALUE lValPoint;
  int lIdxPoint;
  for (lIdxPoint = 0; lIdxPoint < lNbrPoints; ++lIdxPoint) {
    lValPoint = rb_ary_entry(lValSortedPoints, lIdxPoint);
    lPtrFctData->pointsX[lIdxPoint] = iIdxBeginSample+((tSampleIndex)((lDistSample*(value2ld(rb_ary_entry(lValPoint, 0))-lMinX))/lDistX));
    lPtrFctData->pointsY[lIdxPoint] = value2ld(rb_ary_entry(lValPoint, 1));
/*
    printf("Function point n.%d: %lld,%LF\n", lIdxPoint, lPtrFctData->pointsX[lIdxPoint], lPtrFctData->pointsY[lIdxPoint]);
*/
  }

  return rResultCode;
}

/**
 * Create a C function based on a given function to be applied on a given discrete range.
 *
 * Parameters:
 * * *iSelf* (_Object_): Calling object
 * * *iValFunction* (<em>map<Symbol,Object></em>): The function
 * * *iValIdxBeginSample* (<em>map<Symbol,Object></em>): The first sample for this function
 * * *iValIdxEndSample* (<em>map<Symbol,Object></em>): The last sample for this function
 * Return:
 * * _Object_: The Ruby object containing the C function
 */
static VALUE functionutils_createCFunction(
  VALUE iSelf,
  VALUE iValFunction,
  VALUE iValIdxBeginSample,
  VALUE iValIdxEndSample) {
  tSampleIndex iIdxBeginSample = FIX2LONG(iValIdxBeginSample);
  tSampleIndex iIdxEndSample = FIX2LONG(iValIdxEndSample);

  tFunction* lPtrCFunction = ALLOC(tFunction);
  // Retrieve the function type
  lPtrCFunction->fctType = FIX2INT(rb_hash_aref(iValFunction, ID2SYM(rb_intern("FunctionType"))));
  // Call the relevant method based on the type
  switch (lPtrCFunction->fctType) {
    case FCTTYPE_PIECEWISE_LINEAR:
      functionutils_fillCFunction_PiecewiseLinear(lPtrCFunction, iValFunction, iIdxBeginSample, iIdxEndSample);
      break;
    default: ; // The ; is here to make gcc compile: variables declarations are forbidden after a label.
      char lLogMessage[256];
      sprintf(lLogMessage, "Unknown function type %d", lPtrCFunction->fctType);
      rb_funcall(iSelf, rb_intern("logErr"), 1, rb_str_new2(lLogMessage));
      break;
  }

  return Data_Wrap_Struct(rb_cObject, NULL, volumeutils_freeCFct, lPtrCFunction);
}

// Initialize the module
void Init_FunctionUtils() {
  VALUE lWSKModule = rb_define_module("WSK");
  VALUE lFunctionUtilsModule = rb_define_module_under(lWSKModule, "FunctionUtils");
  VALUE lFunctionUtilsClass = rb_define_class_under(lFunctionUtilsModule, "FunctionUtils", rb_cObject);

  rb_define_method(lFunctionUtilsClass, "createCFunction", functionutils_createCFunction, 3);
  gID_to_s = rb_intern("to_s");
  gID_numerator = rb_intern("numerator");
  gID_denominator = rb_intern("denominator");
}
