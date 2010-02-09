/*
 *  FixPoint.i
 *
 *  Provides fixpoint arithmetic (for use in SID.cpp)
 *  You need to define FIXPOINT_PREC (number of fractional bits) and
 *  ldSINTAB (ld of the size of the sinus table) as well M_PI
 *  _before_ including this file.
 *  Requires at least 32bit ints!
 *  (C) 1997 Andreas Dehmel
 */


#define FIXPOINT_BITS	32
#define FIXPOINT_SIGN	(1<<(FIXPOINT_BITS-1))


/*
 *  Elementary functions for the FixPoint class
 */

// Multiplies two fixpoint numbers, result is a fixpoint number.
static inline int32 fixmult(int32 x, int32 y)
{
  register uint32 a,b;
  register bool sign;

  sign = (x ^ y) < 0;
  if (x < 0) {x = -x;}
  if (y < 0) {y = -y;}
  // a, b : integer part; x, y : fractional part. All unsigned now (for shift right)!!!
  a = (((uint32)x) >> FIXPOINT_PREC); x &= ~(a << FIXPOINT_PREC);
  b = (((uint32)y) >> FIXPOINT_PREC); y &= ~(b << FIXPOINT_PREC);
  x = ((a*b) << FIXPOINT_PREC) + (a*y + b*x) +
      ((uint32)((x*y) + (1 << (FIXPOINT_PREC-1))) >> FIXPOINT_PREC);
#ifdef FIXPOINT_SIGN
  if (x < 0) {x ^= FIXPOINT_SIGN;}
#endif
  if (sign) {x = -x;}
  return(x);
}


// Multiplies a fixpoint number with an integer, result is a 32 bit (!) integer in
// contrast to using the standard member-functions which can provide only (32-FIXPOINT_PREC)
// valid bits.
static inline int32 intmult(int32 x, int32 y)	// x is fixpoint, y integer
{
  register uint32 i,j;
  register bool sign;

  sign = (x ^ y) < 0;
  if (x < 0) {x = -x;}
  if (y < 0) {y = -y;}
  i = (((uint32)x) >> 16); x &= ~(i << 16);	// split both into 16.16 parts
  j = (((uint32)y) >> 16); y &= ~(j << 16);
#if FIXPOINT_PREC <= 16
  // This '32' is independent of the number of bits used, it's due to the 16 bit shift
  i = ((i*j) << (32 - FIXPOINT_PREC)) + ((i*y + j*x) << (16 - FIXPOINT_PREC)) +
      ((uint32)(x*y + (1 << (FIXPOINT_PREC - 1))) >> FIXPOINT_PREC);
#else
  {
    register uint32 h;

    h = (i*y + j*x);
    i = ((i*j) << (32 - FIXPOINT_PREC)) + (h >> (FIXPOINT_PREC - 16));
    h &= ((1 << (FIXPOINT_PREC - 16)) - 1); x *= y;
    i += (x >> FIXPOINT_PREC); x &= ((1 << FIXPOINT_PREC) - 1);
    i += (((h + (x >> 16)) + (1 << (FIXPOINT_PREC - 17))) >> (FIXPOINT_PREC - 16));
  }
#endif
#ifdef FIXPOINT_SIGN
  if (i < 0) {i ^= FIXPOINT_SIGN;}
#endif
  if (sign) {i = -i;}
  return(i);
}


// Computes the product of a fixpoint number with itself.
static inline int32 fixsquare(int32 x)
{
  register uint32 a;

  if (x < 0) {x = -x;}
  a = (((uint32)x) >> FIXPOINT_PREC); x &= ~(a << FIXPOINT_PREC);
  x = ((a*a) << FIXPOINT_PREC) + ((a*x) << 1) +
      ((uint32)((x*x) + (1 << (FIXPOINT_PREC-1))) >> FIXPOINT_PREC);
#ifdef FIXPOINT_SIGN
  if (x < 0) {x ^= FIXPOINT_SIGN;}
#endif
  return(x);
}


// Computes the square root of a fixpoint number.
static inline int32 fixsqrt(int32 x)
{
  register int test, step;

  if (x < 0) return(-1); if (x == 0) return(0);
  step = (x <= (1<<FIXPOINT_PREC)) ? (1<<FIXPOINT_PREC) : (1<<((FIXPOINT_BITS - 2 + FIXPOINT_PREC)>>1));
  test = 0;
  while (step != 0)
  {
    register int h;

    h = fixsquare(test + step);
    if (h <= x) {test += step;}
    if (h == x) break;
    step >>= 1;
  }
  return(test);
}


// Divides a fixpoint number by another fixpoint number, yielding a fixpoint result.
static inline int32 fixdiv(int32 x, int32 y)
{
  register int32 res, mask;
  register bool sign;

  sign = (x ^ y) < 0;
  if (x < 0) {x = -x;}
  if (y < 0) {y = -y;}
  mask = (1<<FIXPOINT_PREC); res = 0;
  while (x > y) {y <<= 1; mask <<= 1;}
  while (mask != 0)
  {
    if (x >= y) {res |= mask; x -= y;}
    mask >>= 1; y >>= 1;
  }
#ifdef FIXPOINT_SIGN
  if (res < 0) {res ^= FIXPOINT_SIGN;}
#endif
  if (sign) {res = -res;}
  return(res);
}





/*
 *  The C++ Fixpoint class. By no means exhaustive...
 *  Since it contains only one int data, variables of type FixPoint can be
 *  passed directly rather than as a reference.
 */

class FixPoint
{
private:
  int32 x;

public:
  FixPoint(void);
  FixPoint(int32 y);
  ~FixPoint(void);

  // conversions
  int32 Value(void);
  int32 round(void);
  operator int32(void);

  // unary operators
  FixPoint sqrt(void);
  FixPoint sqr(void);
  FixPoint abs(void);
  FixPoint operator+(void);
  FixPoint operator-(void);
  FixPoint operator++(void);
  FixPoint operator--(void);

  // binary operators
  int32 imul(int32 y);
  FixPoint operator=(FixPoint y);
  FixPoint operator=(int32 y);
  FixPoint operator+(FixPoint y);
  FixPoint operator+(int32 y);
  FixPoint operator-(FixPoint y);
  FixPoint operator-(int32 y);
  FixPoint operator/(FixPoint y);
  FixPoint operator/(int32 y);
  FixPoint operator*(FixPoint y);
  FixPoint operator*(int32 y);
  FixPoint operator+=(FixPoint y);
  FixPoint operator+=(int32 y);
  FixPoint operator-=(FixPoint y);
  FixPoint operator-=(int32 y);
  FixPoint operator*=(FixPoint y);
  FixPoint operator*=(int32 y);
  FixPoint operator/=(FixPoint y);
  FixPoint operator/=(int32 y);
  FixPoint operator<<(int8 y);
  FixPoint operator>>(int8 y);
  FixPoint operator<<=(int8 y);
  FixPoint operator>>=(int8 y);

  // conditional operators
  bool operator<(FixPoint y);
  bool operator<(int32 y);
  bool operator<=(FixPoint y);
  bool operator<=(int32 y);
  bool operator>(FixPoint y);
  bool operator>(int32 y);
  bool operator>=(FixPoint y);
  bool operator>=(int32 y);
  bool operator==(FixPoint y);
  bool operator==(int32 y);
  bool operator!=(FixPoint y);
  bool operator!=(int32 y);
};


/*
 *  int gets treated differently according to the case:
 *
 *  a) Equations (=) or condition checks (==, <, <= ...): raw int (i.e. no conversion)
 *  b) As an argument for an arithmetic operation: conversion to fixpoint by shifting
 *
 *  Otherwise loading meaningful values into FixPoint variables would be very awkward.
 */

FixPoint::FixPoint(void) {x = 0;}

FixPoint::FixPoint(int32 y) {x = y;}

FixPoint::~FixPoint(void) {;}

inline int32 FixPoint::Value(void) {return(x);}

inline int32 FixPoint::round(void) {return((x + (1 << (FIXPOINT_PREC-1))) >> FIXPOINT_PREC);}

inline FixPoint::operator int32(void) {return(x);}


// unary operators
inline FixPoint FixPoint::sqrt(void) {return(fixsqrt(x));}

inline FixPoint FixPoint::sqr(void) {return(fixsquare(x));}

inline FixPoint FixPoint::abs(void) {return((x < 0) ? -x : x);}

inline FixPoint FixPoint::operator+(void) {return(x);}

inline FixPoint FixPoint::operator-(void) {return(-x);}

inline FixPoint FixPoint::operator++(void) {x += (1 << FIXPOINT_PREC); return x;}

inline FixPoint FixPoint::operator--(void) {x -= (1 << FIXPOINT_PREC); return x;}


// binary operators
inline int32 FixPoint::imul(int32 y) {return(intmult(x,y));}

inline FixPoint FixPoint::operator=(FixPoint y) {x = y.Value(); return x;}

inline FixPoint FixPoint::operator=(int32 y) {x = y; return x;}

inline FixPoint FixPoint::operator+(FixPoint y) {return(x + y.Value());}

inline FixPoint FixPoint::operator+(int32 y) {return(x + (y << FIXPOINT_PREC));}

inline FixPoint FixPoint::operator-(FixPoint y) {return(x - y.Value());}

inline FixPoint FixPoint::operator-(int32 y) {return(x - (y << FIXPOINT_PREC));}

inline FixPoint FixPoint::operator/(FixPoint y) {return(fixdiv(x,y.Value()));}

inline FixPoint FixPoint::operator/(int32 y) {return(x/y);}

inline FixPoint FixPoint::operator*(FixPoint y) {return(fixmult(x,y.Value()));}

inline FixPoint FixPoint::operator*(int32 y) {return(x*y);}

inline FixPoint FixPoint::operator+=(FixPoint y) {x += y.Value(); return x;}

inline FixPoint FixPoint::operator+=(int32 y) {x += (y << FIXPOINT_PREC); return x;}

inline FixPoint FixPoint::operator-=(FixPoint y) {x -= y.Value(); return x;}

inline FixPoint FixPoint::operator-=(int32 y) {x -= (y << FIXPOINT_PREC); return x;}

inline FixPoint FixPoint::operator*=(FixPoint y) {x = fixmult(x,y.Value()); return x;}

inline FixPoint FixPoint::operator*=(int32 y) {x *= y; return x;}

inline FixPoint FixPoint::operator/=(FixPoint y) {x = fixdiv(x,y.Value()); return x;}

inline FixPoint FixPoint::operator/=(int32 y) {x /= y; return x;}

inline FixPoint FixPoint::operator<<(int8 y) {return(x << y);}

inline FixPoint FixPoint::operator>>(int8 y) {return(x >> y);}

inline FixPoint FixPoint::operator<<=(int8 y) {x <<= y; return x;}

inline FixPoint FixPoint::operator>>=(int8 y) {x >>= y; return x;}


// conditional operators
inline bool FixPoint::operator<(FixPoint y) {return(x < y.Value());}

inline bool FixPoint::operator<(int32 y) {return(x < y);}

inline bool FixPoint::operator<=(FixPoint y) {return(x <= y.Value());}

inline bool FixPoint::operator<=(int32 y) {return(x <= y);}

inline bool FixPoint::operator>(FixPoint y) {return(x > y.Value());}

inline bool FixPoint::operator>(int32 y) {return(x > y);}

inline bool FixPoint::operator>=(FixPoint y) {return(x >= y.Value());}

inline bool FixPoint::operator>=(int32 y) {return(x >= y);}

inline bool FixPoint::operator==(FixPoint y) {return(x == y.Value());}

inline bool FixPoint::operator==(int32 y) {return(x == y);}

inline bool FixPoint::operator!=(FixPoint y) {return(x != y.Value());}

inline bool FixPoint::operator!=(int32 y) {return(x != y);}



/*
 *  In case the first argument is an int (i.e. member-operators not applicable):
 *  Not supported: things like int/FixPoint. The same difference in conversions
 *  applies as mentioned above.
 */


// binary operators
inline FixPoint operator+(int32 x, FixPoint y) {return((x << FIXPOINT_PREC) + y.Value());}

inline FixPoint operator-(int32 x, FixPoint y) {return((x << FIXPOINT_PREC) - y.Value());}

inline FixPoint operator*(int32 x, FixPoint y) {return(x*y.Value());}


// conditional operators
inline bool operator==(int32 x, FixPoint y) {return(x == y.Value());}

inline bool operator!=(int32 x, FixPoint y) {return(x != y.Value());}

inline bool operator<(int32 x, FixPoint y) {return(x < y.Value());}

inline bool operator<=(int32 x, FixPoint y) {return(x <= y.Value());}

inline bool operator>(int32 x, FixPoint y) {return(x > y.Value());}

inline bool operator>=(int32 x, FixPoint y) {return(x >= y.Value());}


/*
 *  For more convenient creation of constant fixpoint numbers from constant floats.
 */

#define FixNo(n)	(FixPoint)((int)(n*(1<<FIXPOINT_PREC)))


/*
 *  Stuff re. the sinus table used with fixpoint arithmetic
 */


// define as global variable
FixPoint SinTable[(1<<ldSINTAB)];


#define FIXPOINT_SIN_COS_GENERIC \
  if (angle >= 3*(1<<ldSINTAB)) {return(-SinTable[(1<<(ldSINTAB+2)) - angle]);}\
  if (angle >= 2*(1<<ldSINTAB)) {return(-SinTable[angle - 2*(1<<ldSINTAB)]);}\
  if (angle >= (1<<ldSINTAB)) {return(SinTable[2*(1<<ldSINTAB) - angle]);}\
  return(SinTable[angle]);


// sin and cos: angle is fixpoint number 0 <= angle <= 2 (*PI)
static inline FixPoint fixsin(FixPoint x)
{
  int32 angle = x;

  angle = (angle >> (FIXPOINT_PREC - ldSINTAB - 1)) & ((1<<(ldSINTAB+2))-1);
  FIXPOINT_SIN_COS_GENERIC
}


static inline FixPoint fixcos(FixPoint x)
{
  int32 angle = x;

  // cos(x) = sin(x+PI/2)
  angle = (angle + (1<<(FIXPOINT_PREC-1)) >> (FIXPOINT_PREC - ldSINTAB - 1)) & ((1<<(ldSINTAB+2))-1);
  FIXPOINT_SIN_COS_GENERIC
}

static inline void InitFixSinTab(void)
{
	int i;
	float step;
	
	for (i=0, step=0; i<(1<<ldSINTAB); i++, step+=0.5/(1<<ldSINTAB))
	{
		SinTable[i] = FixNo(sin(M_PI * step));
	}
}
