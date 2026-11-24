// Copyright (c) 2007 Intel Corp.

// Black-Scholes
// Analytical method for calculating European Options
//
// 
// Reference Source: Options, Futures, and Other Derivatives, 3rd Edition, Prentice 
// Hall, John C. Hull,

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <fstream>
#include <iostream>
#include <vector>
#include <iomanip>

#include "ieee754.h"
#include "common.h"


//double max_otype, min_otype ;
//double max_sptprice, min_sptprice;
//double max_strike, min_strike;
//double max_rate, min_rate ;
//double max_volatility, min_volatility;
//double max_otime, min_otime ;
//double max_out_price, min_out_price;


#define DIVIDE 120.0


//Precision to use for calculations
#define fptype float

#define NUM_RUNS 1

typedef struct OptionData_ {
        double s;          // spot price
        double strike;     // strike price
        double r;          // risk-free interest rate
        double divq;       // dividend rate
        double v;          // volatility
        double t;          // time to maturity or option expiration in years
                           //     (1yr = 1.0, 6mos = 0.5, 3mos = 0.25, ..., etc)  
        char OptionType;   // Option type.  "P"=PUT, "C"=CALL
        double divs;       // dividend vals (not used in this test)
        double DGrefval;   // DerivaGem Reference Value
} OptionData;

OptionData *data;
double *prices_d;
float *prices_f;
Ieee754 *prices_ieee754;
int numOptions;

int    * otype;
double * sptprice;
double * strike;
double * rate;
double * volatility;
double * otime;
int numError = 0;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Cumulative Normal Distribution Function
// See Hull, Section 11.8, P.243-244
#define inv_sqrt_2xPI 0.39894228040143270286

double CNDF_D ( double InputX ) {
    int sign;

    double OutputX;
    double xInput;
    double xNPrimeofX;
    double expValues;
    double xK2;
    double xK2_2, xK2_3;
    double xK2_4, xK2_5;
    double xLocal, xLocal_1;
    double xLocal_2, xLocal_3;

    // Check for negative value of InputX
    if (InputX < 0.0) {
        InputX = -InputX;
        sign = 1;
    } else
        sign = 0;

    xInput = InputX;

    // Compute NPrimeX term common to both four & six decimal accuracy calcs
    expValues = exp(-0.5f * InputX * InputX);
    xNPrimeofX = expValues;
    xNPrimeofX = xNPrimeofX * inv_sqrt_2xPI;

    xK2 = 0.2316419 * xInput;
    xK2 = 1.0 + xK2;
    xK2 = 1.0 / xK2;
    xK2_2 = xK2 * xK2;
    xK2_3 = xK2_2 * xK2;
    xK2_4 = xK2_3 * xK2;
    xK2_5 = xK2_4 * xK2;

    xLocal_1 = xK2 * 0.319381530;
    xLocal_2 = xK2_2 * (-0.356563782);
    xLocal_3 = xK2_3 * 1.781477937;
    xLocal_2 = xLocal_2 + xLocal_3;
    xLocal_3 = xK2_4 * (-1.821255978);
    xLocal_2 = xLocal_2 + xLocal_3;
    xLocal_3 = xK2_5 * 1.330274429;
    xLocal_2 = xLocal_2 + xLocal_3;

    xLocal_1 = xLocal_2 + xLocal_1;
    xLocal   = xLocal_1 * xNPrimeofX;

    //printf("# xLocal: %10.10f\n", xLocal);



    xLocal   = 1.0 - xLocal;

    OutputX  = xLocal;

    //printf("# Output: %10.10f\n", OutputX);

    if (sign) {
        OutputX = 1.0 - OutputX;
    }

    return OutputX;
}

float CNDF_F ( float InputX ) {
    int sign;

    float OutputX;
    float xInput;
    float xNPrimeofX;
    float expValues;
    float xK2;
    float xK2_2, xK2_3;
    float xK2_4, xK2_5;
    float xLocal, xLocal_1;
    float xLocal_2, xLocal_3;

    // Check for negative value of InputX
    if (InputX < 0.0) {
        InputX = -InputX;
        sign = 1;
    } else
        sign = 0;

    xInput = InputX;

    // Compute NPrimeX term common to both four & six decimal accuracy calcs
    expValues = exp(-0.5f * InputX * InputX);
    xNPrimeofX = expValues;
    xNPrimeofX = xNPrimeofX * inv_sqrt_2xPI;

    xK2 = 0.2316419 * xInput;
    xK2 = 1.0 + xK2;
    xK2 = 1.0 / xK2;
    xK2_2 = xK2 * xK2;
    xK2_3 = xK2_2 * xK2;
    xK2_4 = xK2_3 * xK2;
    xK2_5 = xK2_4 * xK2;

    xLocal_1 = xK2 * 0.319381530;
    xLocal_2 = xK2_2 * (-0.356563782);
    xLocal_3 = xK2_3 * 1.781477937;
    xLocal_2 = xLocal_2 + xLocal_3;
    xLocal_3 = xK2_4 * (-1.821255978);
    xLocal_2 = xLocal_2 + xLocal_3;
    xLocal_3 = xK2_5 * 1.330274429;
    xLocal_2 = xLocal_2 + xLocal_3;

    xLocal_1 = xLocal_2 + xLocal_1;
    xLocal   = xLocal_1 * xNPrimeofX;

    //printf("# xLocal: %10.10f\n", xLocal);



    xLocal   = 1.0 - xLocal;

    OutputX  = xLocal;

    //printf("# Output: %10.10f\n", OutputX);

    if (sign) {
        OutputX = 1.0 - OutputX;
    }

    return OutputX;
}

Ieee754 CNDF_IEEE754 ( Ieee754 InputX ) {
    int sign;

    Ieee754 OutputX;
    Ieee754 xInput;
    Ieee754 xNPrimeofX;
    Ieee754 expValues;
    Ieee754 xK2;
    Ieee754 xK2_2, xK2_3;
    Ieee754 xK2_4, xK2_5;
    Ieee754 xLocal, xLocal_1;
    Ieee754 xLocal_2, xLocal_3;

    // Check for negative value of InputX
    if (InputX < 0.0) {
        InputX = -InputX;
        sign = 1;
    } else
        sign = 0;

    xInput = InputX;

    // Compute NPrimeX term common to both four & six decimal accuracy calcs
    expValues = exp(-0.5f * InputX * InputX);
    xNPrimeofX = expValues;
    xNPrimeofX = xNPrimeofX * inv_sqrt_2xPI;

    xK2 = 0.2316419 * xInput;
    xK2 = 1.0 + xK2;
    xK2 = 1.0 / xK2;
    xK2_2 = xK2 * xK2;
    xK2_3 = xK2_2 * xK2;
    xK2_4 = xK2_3 * xK2;
    xK2_5 = xK2_4 * xK2;

    xLocal_1 = xK2 * 0.319381530;
    xLocal_2 = xK2_2 * (-0.356563782);
    xLocal_3 = xK2_3 * 1.781477937;
    xLocal_2 = xLocal_2 + xLocal_3;
    xLocal_3 = xK2_4 * (-1.821255978);
    xLocal_2 = xLocal_2 + xLocal_3;
    xLocal_3 = xK2_5 * 1.330274429;
    xLocal_2 = xLocal_2 + xLocal_3;

    xLocal_1 = xLocal_2 + xLocal_1;
    xLocal   = xLocal_1 * xNPrimeofX;

    //printf("# xLocal: %10.10f\n", xLocal);



    xLocal   = 1.0 - xLocal;

    OutputX  = xLocal;

    //printf("# Output: %10.10f\n", OutputX);

    if (sign) {
        OutputX = 1.0 - OutputX;
    }

    return OutputX;
}

//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////
double BlkSchlsEqEuroNoDiv_d( double sptprice,
                              double strike, double rate, double volatility,
                              double time, int otype, float timet, double* N1, double* N2) {
    double OptionPrice;

    // local private working variables for the calculation
    //double xStockPrice;
    //double xStrikePrice;
    double xRiskFreeRate;
    double xVolatility;
    double xTime;
    double xSqrtTime;

    double logValues;
    double xLogTerm;
    double xD1;
    double xD2;
    double xPowerTerm;
    double xDen;
    double d1;
    double d2;
    double FutureValueX;
    double NofXd1;
    double NofXd2;
    double NegNofXd1;
    double NegNofXd2;

    //xStockPrice = sptprice;
    //xStrikePrice = strike;
    xRiskFreeRate = rate;
    xVolatility = volatility;
    xTime = time;


    xSqrtTime = sqrt(xTime);

    logValues = log( sptprice / strike );

    xLogTerm = logValues;

    xPowerTerm = xVolatility * xVolatility;
    xPowerTerm = xPowerTerm * 0.5;

    xD1 = xRiskFreeRate + xPowerTerm;
    xD1 = xD1 * xTime;
    xD1 = xD1 + xLogTerm;

    xDen = xVolatility * xSqrtTime;
    xD1 = xD1 / xDen;
    xD2 = xD1 -  xDen;

    d1 = xD1;
    d2 = xD2;

    NofXd1 = CNDF_D( d1 );

    if(NofXd1 > 1.0)
        std::cerr << "Greater than one!" << std::endl ;
    //printf("# d1: %10.10f\n", NofXd1);

    NofXd2 = CNDF_D( d2 );
    if(NofXd2 > 1.0)
         std::cerr << "Greater than one!" << std::endl ;
    //printf("# d2: %10.10f\n", NofXd2);

    *N1 = NofXd1 ;
    *N2 = NofXd2 ;

    FutureValueX = strike * ( exp( -(rate)*(time) ) );
    if (otype == 0) {
        OptionPrice = (sptprice * NofXd1) - (FutureValueX * NofXd2);
    } else {
        NegNofXd1 = (1.0 - NofXd1);
        NegNofXd2 = (1.0 - NofXd2);
        OptionPrice = (FutureValueX * NegNofXd2) - (sptprice * NegNofXd1);
    }

    return OptionPrice;
}

float BlkSchlsEqEuroNoDiv_f( float sptprice,
                              float strike, float rate, float volatility,
                              float time, int otype, float timet, float* N1, float* N2) {
    float OptionPrice;

    // local private working variables for the calculation
    //float xStockPrice;
    //float xStrikePrice;
    float xRiskFreeRate;
    float xVolatility;
    float xTime;
    float xSqrtTime;

    float logValues;
    float xLogTerm;
    float xD1;
    float xD2;
    float xPowerTerm;
    float xDen;
    float d1;
    float d2;
    float FutureValueX;
    float NofXd1;
    float NofXd2;
    float NegNofXd1;
    float NegNofXd2;

    //xStockPrice = sptprice;
    //xStrikePrice = strike;
    xRiskFreeRate = rate;
    xVolatility = volatility;
    xTime = time;


    xSqrtTime = sqrt(xTime);

    logValues = log( sptprice / strike );
        
    xLogTerm = logValues;

    xPowerTerm = xVolatility * xVolatility;
    xPowerTerm = xPowerTerm * 0.5;

    xD1 = xRiskFreeRate + xPowerTerm;
    xD1 = xD1 * xTime;
    xD1 = xD1 + xLogTerm;

    xDen = xVolatility * xSqrtTime;
    xD1 = xD1 / xDen;
    xD2 = xD1 -  xDen;

    d1 = xD1;
    d2 = xD2;

    NofXd1 = CNDF_F( d1 );

    if(NofXd1 > 1.0)
        std::cerr << "Greater than one!" << std::endl ;
    //printf("# d1: %10.10f\n", NofXd1);

    NofXd2 = CNDF_F( d2 );
    if(NofXd2 > 1.0)
         std::cerr << "Greater than one!" << std::endl ;
    //printf("# d2: %10.10f\n", NofXd2);

    *N1 = NofXd1 ;
    *N2 = NofXd2 ;

    FutureValueX = strike * ( exp( -(rate)*(time) ) );
    if (otype == 0) {
        OptionPrice = (sptprice * NofXd1) - (FutureValueX * NofXd2);
    } else {
        NegNofXd1 = (1.0 - NofXd1);
        NegNofXd2 = (1.0 - NofXd2);
        OptionPrice = (FutureValueX * NegNofXd2) - (sptprice * NegNofXd1);
    }

    return OptionPrice;
}

Ieee754 BlkSchlsEqEuroNoDiv_ieee754( Ieee754 sptprice,
                                 Ieee754 strike, Ieee754 rate, Ieee754 volatility,
                                 Ieee754 time, int otype, float timet, Ieee754* N1, Ieee754* N2) {
    Ieee754 OptionPrice;

    // local private working variables for the calculation
    //Ieee754 xStockPrice;
    //Ieee754 xStrikePrice;
    Ieee754 xRiskFreeRate;
    Ieee754 xVolatility;
    Ieee754 xTime;
    Ieee754 xSqrtTime;

    Ieee754 logValues;
    Ieee754 xLogTerm;
    Ieee754 xD1;
    Ieee754 xD2;
    Ieee754 xPowerTerm;
    Ieee754 xDen;
    Ieee754 d1;
    Ieee754 d2;
    Ieee754 FutureValueX;
    Ieee754 NofXd1;
    Ieee754 NofXd2;
    Ieee754 NegNofXd1;
    Ieee754 NegNofXd2;

    //xStockPrice = sptprice;
    //xStrikePrice = strike;
    xRiskFreeRate = rate;
    xVolatility = volatility;
    xTime = time;

    xSqrtTime = sqrt(xTime);

    logValues = log( sptprice / strike );

    xLogTerm = logValues;

    xPowerTerm = xVolatility * xVolatility;
    xPowerTerm = xPowerTerm * 0.5;

    xD1 = xRiskFreeRate + xPowerTerm;
    xD1 = xD1 * xTime;
    xD1 = xD1 + xLogTerm;

    xDen = xVolatility * xSqrtTime;
    xD1 = xD1 / xDen;
    xD2 = xD1 -  xDen;

    d1 = xD1;
    d2 = xD2;

    NofXd1 = CNDF_IEEE754( d1 );

    if(NofXd1 > 1.0)
        std::cerr << "Greater than one!" << std::endl ;
    //printf("# d1: %10.10f\n", NofXd1);

    NofXd2 = CNDF_IEEE754( d2 );
    if(NofXd2 > 1.0)
         std::cerr << "Greater than one!" << std::endl ;
    //printf("# d2: %10.10f\n", NofXd2);

    *N1 = NofXd1 ;
    *N2 = NofXd2 ;

    FutureValueX = strike * ( exp( -(rate)*(time) ) );
    if (otype == 0) {
        OptionPrice = (sptprice * NofXd1) - (FutureValueX * NofXd2);
    } else {
        NegNofXd1 = (1.0 - NofXd1);
        NegNofXd2 = (1.0 - NofXd2);
        OptionPrice = (FutureValueX * NegNofXd2) - (sptprice * NegNofXd1);
    }

    return OptionPrice;
}

int bs_thread(void *tid_ptr) {
    int i, j;

    int tid = *(int *)tid_ptr;
    int start = tid * (numOptions);
    int end = start + (numOptions);
    double price_orig_d;
    float price_orig_f;
    Ieee754 price_orig_ieee754;

    for (j=0; j<NUM_RUNS; j++) {
        for (i=start; i<end; i++) {
            /* Calling main function to calculate option value based on 
             * Black & Scholes's equation.
             */
            double N1_d, N2_d;
            float N1_f, N2_f;
            Ieee754 N1_ieee754, N2_ieee754;

            double dataOut_d[1];
            float dataOut_f[1];
            Ieee754 dataOut_ieee754[1];

            price_orig_d = BlkSchlsEqEuroNoDiv_d( sptprice[i], strike[i],
                                                  rate[i], volatility[i], otime[i],
                                                  otype[i], 0, &N1_d, &N2_d);

            price_orig_f = BlkSchlsEqEuroNoDiv_f( (float)sptprice[i], (float)strike[i],
                                                  (float)rate[i], (float)volatility[i], (float)otime[i],
                                                  otype[i], 0, &N1_f, &N2_f);

            price_orig_ieee754 = BlkSchlsEqEuroNoDiv_ieee754( (Ieee754)sptprice[i], (Ieee754)strike[i],
                                                        (Ieee754)rate[i], (Ieee754)volatility[i], (Ieee754)otime[i],
                                                        otype[i], 0, &N1_ieee754, &N2_ieee754);
            dataOut_d[0] = price_orig_d;
            dataOut_f[0] = price_orig_f;
            dataOut_ieee754[0] = price_orig_ieee754;

            price_orig_d = dataOut_d[0];
            prices_d[i] = price_orig_d;

            price_orig_f = dataOut_f[0];
            prices_f[i] = price_orig_f;

            price_orig_ieee754 = dataOut_ieee754[0];
            prices_ieee754[i] = price_orig_ieee754;
        }
    }
    return 0;
}

void blackscholes(char *inputDir, char *outputDir, FILE *fp_d, FILE *fp_f, FILE *fp_ieee754) {
    int i;
    int loopnum;
    double * buffer;
    int * buffer2;
    int rv;

    // Read input data from file
    sprintf(buf, "%s/black-scholes/data_in.txt", inputDir);
    FILE *file = fopen(buf, "r");
    if(file == NULL) {
      printf("ERROR: Unable to open file `%s'.\n", buf);
      exit(1);
    }
    rv = fscanf(file, "%i", &numOptions);
    if(rv != 1) {
      printf("ERROR: Unable to read from file `%s'.\n", buf);
      fclose(file);
      exit(1);
    }


    // alloc spaces for the option data
    data = (OptionData*)malloc(numOptions*sizeof(OptionData));
    prices_d = (double*)malloc(numOptions*sizeof(double));
    prices_f = (float*)malloc(numOptions*sizeof(float));
    prices_ieee754 = (Ieee754*)malloc(numOptions*sizeof(Ieee754));
    for ( loopnum = 0; loopnum < numOptions; ++ loopnum ) {
        rv = fscanf(file, "%lF %lF %lF %lF %lF %lF %c %lF %lF", &data[loopnum].s, &data[loopnum].strike, &data[loopnum].r, &data[loopnum].divq, &data[loopnum].v, &data[loopnum].t, &data[loopnum].OptionType, &data[loopnum].divs, &data[loopnum].DGrefval);
        if(rv != 9) {
          printf("ERROR: Unable to read from file `%s'.\n", buf);
          fclose(file);
          exit(1);
        }
    }
    rv = fclose(file);
    if(rv != 0) {
      printf("ERROR: Unable to close file `%s'.\n", buf);
      exit(1);
    }

#define PAD 256
#define LINESIZE 64

    buffer = (double *) malloc(5 * numOptions * sizeof(double) + PAD);
    sptprice = (double *) (((unsigned long long)buffer + PAD) & ~(LINESIZE - 1));
    strike = sptprice + numOptions;
    rate = strike + numOptions;
    volatility = rate + numOptions;
    otime = volatility + numOptions;

    buffer2 = (int *) malloc(numOptions * sizeof(double) + PAD);
    otype = (int *) (((unsigned long long)buffer2 + PAD) & ~(LINESIZE - 1));

    for (i=0; i<numOptions; i++) {
        otype[i]      = (data[i].OptionType == 'P') ? 1 : 0;
        sptprice[i]   = data[i].s / DIVIDE;
        strike[i]     = data[i].strike / DIVIDE;
        rate[i]       = data[i].r;
        volatility[i] = data[i].v;    
        otime[i]      = data[i].t;
    }

    //serial version
    int tid=0;
    bs_thread(&tid);


    // Write prices to output file
    sprintf(buf, "%s/prices.txt", outputDir);
    file = fopen(buf, "w");
    if(file == NULL) {
      printf("ERROR: Unable to open file `%s'.\n", buf);
      exit(1);
    }
    //rv = fprintf(file, "%i\n", numOptions);
    if(rv < 0) {
      printf("ERROR: Unable to write to file `%s'.\n", buf);
      fclose(file);
      exit(1);
    }
    for(i=0; i<numOptions; i++) {
      rv = fprintf(file, "%.18F\n", prices_d[i]);
      if(rv < 0) {
        printf("ERROR: Unable to write to file `%s'.\n", buf);
        fclose(file);
        exit(1);
      }
      fprintf(fp_d, "%.16E\n", prices_d[i]);
      fprintf(fp_f, "%.16E\n", prices_f[i]);
      fprintf(fp_ieee754, "%.16e\n", (double)prices_ieee754[i]);
    }
    rv = fclose(file);
    if(rv != 0) {
      printf("ERROR: Unable to close file `%s'.\n", buf);
      exit(1);
    }

    free(data);
    free(prices_d);
    free(prices_f);
    free(prices_ieee754);


    free(buffer);
    free(buffer2);

    return;
}
