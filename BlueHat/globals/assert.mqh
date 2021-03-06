//+------------------------------------------------------------------+
//| Implementation of the assertion mechanism                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Sergey Eryomin (ENSED)"
#property link      "http://www.ensed.org"
#property strict

#define DEBUG

#ifdef DEBUG  
   #define assert(condition, message) \
      if(!(condition)) \
        { \
         string fullMessage= \
                            #condition+", " \
                            +__FILE__+", " \
                            +__FUNCSIG__+", " \
                            +"line: "+(string)__LINE__ \
                            +(message=="" ? "" : ", "+message); \
         \
         Alert("Assertion failed! "+fullMessage); \
         double x[]; \
         ArrayResize(x, 0); \
         x[1] = 0.0; \
        }
#else 
   #define assert(condition, message) ;
#endif
//+------------------------------------------------------------------+
