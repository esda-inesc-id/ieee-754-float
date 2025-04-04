#ifndef IEEE754_H
#define IEEE754_H

#include <iostream>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>

#include "ieee754lib.h"

extern uint8_t op;

class Ieee754 {
    private:
        int32_t dw;
        int32_t ew;
        ieee754 val;
        ieee754Acc acc;
        int32_t sc;
    public:

        //
        // Declarations
        //

        Ieee754(): val(IEEE754_ZERO) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_rst_acc_(&acc); op = 0; };
        Ieee754(float f): val(floattoieee754(f)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
        Ieee754(double d): val(doubletoieee754(d)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
        Ieee754(long int i): val(doubletoieee754((double)i)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
        Ieee754(long unsigned int i): val(doubletoieee754((double)i)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
        Ieee754(unsigned int i): val(doubletoieee754((double)i)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
        Ieee754(int i): val(doubletoieee754((double)i)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
        Ieee754(short unsigned int i): val(doubletoieee754((double)i)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
        Ieee754(unsigned char i): val(doubletoieee754((double)i)) { dw = IEEE754_DATA_W; ew = IEEE754_EXP_W; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; };
  Ieee754(int32_t data_w, int32_t exp_w): val(IEEE754_ZERO) { dw = data_w; ew = exp_w; sc = 0; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; }
        Ieee754(int32_t data_w, int32_t exp_w, int32_t scale): val(IEEE754_ZERO) { dw = data_w; ew = exp_w; sc = scale; _ieee754_set_acc_(&acc, val, dw, ew); op = 0; }

        //
        // Conversion operators
        //

        operator float() { return _ieee754tofloat_(val, dw, ew); }
        operator double() { return _ieee754todouble_(val, dw, ew); }
        operator long int() { return (long int)_ieee754toint_(val, dw, ew); }
        operator long unsigned int() { return (long unsigned int)_ieee754toint_(val, dw, ew); }
        operator unsigned int() { return (unsigned int)_ieee754toint_(val, dw, ew); }
        operator unsigned int() const { return (unsigned int)_ieee754toint_(val, dw, ew); }
        operator int() { return (int)_ieee754toint_(val, dw, ew); }
        operator int() const { return (int)_ieee754toint_(val, dw, ew); }
        operator short unsigned int() { return (short unsigned int)_ieee754toint_(val, dw, ew); }
        operator unsigned char() { return (unsigned char)_ieee754toint_(val, dw, ew); }
        operator bool() { return (bool)_ieee754todouble_(val, dw, ew); }

        //
        // Setters and getters
        //

        void setvalue (int32_t value) { val = value; return; }
        ieee754 getvalue () { return val; }

        int32_t get_dw() { return dw; }
        int32_t get_ew() { return ew; }

        //
        // Assigment operators
        //
        void operator=(Ieee754 const& other) {
            if (!dw) dw = other.dw;
            if (!ew) ew = other.ew;
            if (!sc) sc = other.sc;
            if (dw != other.dw || ew != other.ew) val = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw, ew);
            else val = other.val;
            _ieee754_set_acc_(&acc, val, dw, ew);
            op = 0;
            return;
        }

        //
        // Arithmetic operators
        //

        // Addition
        Ieee754 operator++() {
            Ieee754 res(dw, ew);
            res.val = _ieee754_add_(val, _IEEE754_ONE_(dw, ew), dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator++( int ) {
            Ieee754 res(dw, ew);
            res.val = val;
            val = _ieee754_add_(val, _IEEE754_ONE_(dw, ew), dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+(Ieee754 const& other) const {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_add_(op1, op2, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator+(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_add_(op1, op2, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator+(double const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_add_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+(float const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_add_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+(long unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_add_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+(long int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_add_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+(unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_add_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+(int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_add_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+(unsigned char const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_add_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator+=(Ieee754 const& other) {
            ieee754Unpacked upk;
            if (!dw) dw = other.dw;
            if (!ew) ew = other.ew;
            if (op) {
              val = _ieee754_acc_(&acc, 0, 0, dw, ew);
            } else {
              ieee754 aux;
              if (dw != other.dw || ew != other.ew) aux = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw, ew);
              else aux = other.val;
              upk = _ieee754_unpack_(aux, dw, ew);
              val = _ieee754_acc_(&acc, &upk, other.sc, dw, ew);
            }
            op = 0;
            return val;
        }

        // Subtraction
        Ieee754 operator--() {
            Ieee754 res(dw, ew);
            res.val = _ieee754_sub_(val, _IEEE754_ONE_(dw, ew), dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator--( int ) {
            Ieee754 res(dw, ew);
            res.val = val;
            val = _ieee754_sub_(val, _IEEE754_ONE_(dw, ew), dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-() const {
            Ieee754 res(dw, ew);
            res.val = ieee754_neg(val, dw);
            op = 0;
            return res;
        }

        Ieee754 operator-() {
            Ieee754 res(dw, ew);
            res.val = ieee754_neg(val, dw);
            op = 0;
            return res;
        }

        Ieee754 operator-(Ieee754 const& other) const {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_sub_(op1, op2, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator-(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_sub_(op1, op2, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator-(double const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_sub_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-(float const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_sub_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-(long unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_sub_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-(long int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_sub_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-(unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_sub_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-(int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_sub_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-(unsigned char const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_sub_(val, res.val, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator-=(Ieee754 const& other) {
            if (!dw) dw = other.dw;
            if (!ew) ew = other.ew;
            op = 0;
            return val = _ieee754_sub_(val, other.val, dw, ew);
        }

        // Multiplication
        Ieee754 operator*(Ieee754 const& other) const {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_mul_(op1, sc, op2, other.sc, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator*(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_mul_(op1, sc, op2, other.sc, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator*(double const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_mul_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator*(float const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_mul_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator*(long unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_mul_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator*(long int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_mul_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator*(unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_mul_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator*(int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_mul_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator*(unsigned char const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_mul_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator*=(Ieee754 const& other) {
            if (!dw) dw = other.dw;
            if (!ew) ew = other.ew;
            op = 0;
            return val = _ieee754_mul_(val, sc, other.val, other.sc, dw, ew);
        }

        // Division
        Ieee754 operator/(Ieee754 const& other) const {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_div_(op1, sc, op2, other.sc, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator/(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            Ieee754 res(dw_int, ew_int);
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            res.val = _ieee754_div_(op1, sc, op2, other.sc, dw_int, ew_int);
            op = 1;
            return res;
        }

        Ieee754 operator/(double const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_div_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator/(float const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_div_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator/(long unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_div_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator/(long int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_div_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator/(unsigned int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_div_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator/(int const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_div_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator/(unsigned char const other) {
            Ieee754 res(dw, ew);
            res = other;
            res.val = _ieee754_div_(val, sc, res.val, 0, dw, ew);
            op = 1;
            return res;
        }

        Ieee754 operator/=(Ieee754 const& other) {
            if (!dw) dw = other.dw;
            if (!ew) ew = other.ew;
            op = 0;
            return val = _ieee754_div_(val, sc, other.val, other.sc, dw, ew);
        }

        //
        // Comparator operators
        //

        bool operator<(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            return (bool)ieee754_lt(op1, op2, dw_int);
        }

        bool operator<=(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            return (bool)ieee754_le(op1, op2, dw_int);
        }

        bool operator>(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            return (bool)ieee754_gt(op1, op2, dw_int);
        }

        bool operator>=(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            return (bool)ieee754_ge(op1, op2, dw_int);
        }

        bool operator==(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            return (bool)ieee754_eq(op1, op2, dw_int);
        }

        bool operator!=(Ieee754 const& other) {
            int32_t dw_int = (dw > other.dw)? dw: other.dw;
            int32_t ew_int = (ew > other.ew)? ew: other.ew;
            ieee754 op1, op2;
            if (dw != dw_int || ew != ew_int) op1 = _doubletoieee754_(_ieee754todouble_(val, dw, ew), dw_int, ew_int);
            else op1 = val;
            if (other.dw != dw_int || other.ew != ew_int) op2 = _doubletoieee754_(_ieee754todouble_(other.val, other.dw, other.ew), dw_int, ew_int);
            else op2 = other.val;
            return (bool)!ieee754_eq(op1, op2, dw_int);
        }

        //
        // Input/Output
        //

        friend std::ostream &operator<<(std::ostream &output, const Ieee754 &other ) {
            output << _ieee754todouble_(other.val, other.dw, other.ew);
         return output;
        }

        friend std::istream &operator>>(std::istream  &input, Ieee754 &other ) {
            double value;
            input >> value;
            other.val = _doubletoieee754_(value, other.dw, other.ew);
            return input;
        }
};

//
// More arithmetic operators
//

inline Ieee754 operator+(double d, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = d;
  return aux + num_ieee754;
}

inline Ieee754 operator+(float f, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = f;
  return aux + num_ieee754;
}

inline Ieee754 operator+(long unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux + num_ieee754;
}

inline Ieee754 operator+(long int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux + num_ieee754;
}

inline Ieee754 operator+(unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux + num_ieee754;
}

inline Ieee754 operator+(int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux + num_ieee754;
}

inline Ieee754 operator+(unsigned char i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux + num_ieee754;
}

inline Ieee754 operator-(double d, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = d;
  return aux - num_ieee754;
}

inline Ieee754 operator-(float f, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = f;
  return aux - num_ieee754;
}

inline Ieee754 operator-(long unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux - num_ieee754;
}

inline Ieee754 operator-(long int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux - num_ieee754;
}

inline Ieee754 operator-(unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux - num_ieee754;
}

inline Ieee754 operator-(int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux - num_ieee754;
}

inline Ieee754 operator-(unsigned char i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux - num_ieee754;
}

inline Ieee754 operator*(double d, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = d;
  return aux * num_ieee754;
}

inline Ieee754 operator*(float f, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = f;
  return aux * num_ieee754;
}

inline Ieee754 operator*(long unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux * num_ieee754;
}

inline Ieee754 operator*(long int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux * num_ieee754;
}

inline Ieee754 operator*(unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux * num_ieee754;
}

inline Ieee754 operator*(int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux * num_ieee754;
}

inline Ieee754 operator*(unsigned char i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux * num_ieee754;
}

inline Ieee754 operator/(double d, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = d;
  return aux / num_ieee754;
}

inline Ieee754 operator/(float f, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = f;
  return aux / num_ieee754;
}

inline Ieee754 operator/(long unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux / num_ieee754;
}

inline Ieee754 operator/(long int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux / num_ieee754;
}

inline Ieee754 operator/(unsigned int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux / num_ieee754;
}

inline Ieee754 operator/(int i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux / num_ieee754;
}

inline Ieee754 operator/(unsigned char i, Ieee754 num_ieee754) {
  Ieee754 aux(num_ieee754.get_dw(), num_ieee754.get_ew());
  aux = i;
  return aux / num_ieee754;
}

//
// More comparator operators
//

inline bool operator<(double d, Ieee754 num_ieee754) { return (Ieee754)d < num_ieee754; }
inline bool operator<(float f, Ieee754 num_ieee754) { return (Ieee754)f < num_ieee754; }
inline bool operator<(int i, Ieee754 num_ieee754) { return (Ieee754)i < num_ieee754; }
inline bool operator<(Ieee754 num_ieee754, double d) { return num_ieee754 < (Ieee754)d; }
inline bool operator<(Ieee754 num_ieee754, float f) { return num_ieee754 < (Ieee754)f; }
inline bool operator<(Ieee754 num_ieee754, int i) { return num_ieee754 < (Ieee754)i; }

inline bool operator<=(double d, Ieee754 num_ieee754) { return (Ieee754)d <= num_ieee754; }
inline bool operator<=(float f, Ieee754 num_ieee754) { return (Ieee754)f <= num_ieee754; }
inline bool operator<=(int i, Ieee754 num_ieee754) { return (Ieee754)i <= num_ieee754; }
inline bool operator<=(Ieee754 num_ieee754, double d) { return num_ieee754 <= (Ieee754)d; }
inline bool operator<=(Ieee754 num_ieee754, float f) { return num_ieee754 <= (Ieee754)f; }
inline bool operator<=(Ieee754 num_ieee754, int i) { return num_ieee754 <= (Ieee754)i; }

inline bool operator>(double d, Ieee754 num_ieee754) { return (Ieee754)d > num_ieee754; }
inline bool operator>(float f, Ieee754 num_ieee754) { return (Ieee754)f > num_ieee754; }
inline bool operator>(int i, Ieee754 num_ieee754) { return (Ieee754)i > num_ieee754; }
inline bool operator>(Ieee754 num_ieee754, double d) { return num_ieee754 > (Ieee754)d; }
inline bool operator>(Ieee754 num_ieee754, float f) { return num_ieee754 > (Ieee754)f; }
inline bool operator>(Ieee754 num_ieee754, int i) { return num_ieee754 > (Ieee754)i; }

inline bool operator>=(double d, Ieee754 num_ieee754) { return (Ieee754)d >= num_ieee754; }
inline bool operator>=(float f, Ieee754 num_ieee754) { return (Ieee754)f >= num_ieee754; }
inline bool operator>=(int i, Ieee754 num_ieee754) { return (Ieee754)i >= num_ieee754; }
inline bool operator>=(Ieee754 num_ieee754, double d) { return num_ieee754 >= (Ieee754)d; }
inline bool operator>=(Ieee754 num_ieee754, float f) { return num_ieee754 >= (Ieee754)f; }
inline bool operator>=(Ieee754 num_ieee754, int i) { return num_ieee754 >= (Ieee754)i; }

inline bool operator==(double d, Ieee754 num_ieee754) { return (Ieee754)d == num_ieee754; }
inline bool operator==(float f, Ieee754 num_ieee754) { return (Ieee754)f == num_ieee754; }
inline bool operator==(int i, Ieee754 num_ieee754) { return (Ieee754)i == num_ieee754; }
inline bool operator==(Ieee754 num_ieee754, double d) { return num_ieee754 == (Ieee754)d; }
inline bool operator==(Ieee754 num_ieee754, float f) { return num_ieee754 == (Ieee754)f; }
inline bool operator==(Ieee754 num_ieee754, int i) { return num_ieee754 == (Ieee754)i; }

inline bool operator!=(double d, Ieee754 num_ieee754) { return (Ieee754)d != num_ieee754; }
inline bool operator!=(float f, Ieee754 num_ieee754) { return (Ieee754)f != num_ieee754; }
inline bool operator!=(int i, Ieee754 num_ieee754) { return (Ieee754)i != num_ieee754; }
inline bool operator!=(Ieee754 num_ieee754, double d) { return num_ieee754 != (Ieee754)d; }
inline bool operator!=(Ieee754 num_ieee754, float f) { return num_ieee754 != (Ieee754)f; }
inline bool operator!=(Ieee754 num_ieee754, int i) { return num_ieee754 != (Ieee754)i; }

//
// Math functions
//

inline Ieee754 cos(Ieee754 x) { return (Ieee754)cos((double)x); }
inline Ieee754 sin(Ieee754 x) { return (Ieee754)sin((double)x); }
inline Ieee754 acos(Ieee754 x) { return (Ieee754)acos((double)x); }
inline Ieee754 exp(Ieee754 x) { return (Ieee754)exp((double)x); }
inline Ieee754 frexp(Ieee754 x, int *e) { return (Ieee754)frexp((double)x, e); }
inline Ieee754 log(Ieee754 x) { return (Ieee754)log((double)x); }
inline Ieee754 log2(Ieee754 x) { return (Ieee754)log2((double)x); }
inline Ieee754 pow(Ieee754 x, Ieee754 y) { return (Ieee754)pow((double)x, (double)y); }
inline Ieee754 pow(Ieee754 x, double y) { return (Ieee754)pow((double)x, y); }
inline Ieee754 pow(double x, Ieee754 y) { return (Ieee754)pow(x, (double)y); }
inline Ieee754 pow(float x, Ieee754 y) { return (Ieee754)pow(x, (double)y); }
inline Ieee754 pow(int x, Ieee754 y) { return (Ieee754)pow(x, (double)y); }
inline Ieee754 sqrt(Ieee754 x) { return (Ieee754)sqrt((double)x); }
inline Ieee754 ceil(Ieee754 x) { return (Ieee754)ceil((double)x); }
inline Ieee754 fabs(Ieee754 x) { return ieee754_abs(x.getvalue(), x.get_dw()); }
inline Ieee754 fabsf(Ieee754 x) { return ieee754_abs(x.getvalue(), x.get_dw()); }
inline Ieee754 floor(Ieee754 x) { return (Ieee754)floor((double)x); }

//
// Standard functions
//

inline void *memset(Ieee754 *ieee754_ptr, int val, size_t n) {
  return memset((void *)ieee754_ptr, val, n);
}

inline void *memcpy(Ieee754 *ieee754_ptr, const double *fp_ptr, size_t n) {
  n /= sizeof(double);
  while (n--) ieee754_ptr[n] = (Ieee754)fp_ptr[n];
  return (void *)ieee754_ptr;
}

inline void *memcpy(Ieee754 *ieee754_ptr, const float *fp_ptr, size_t n) {
  n /= sizeof(float);
  while (n--) ieee754_ptr[n] = (Ieee754)fp_ptr[n];
  return (void *)ieee754_ptr;
}

inline void *memcpy(Ieee754 *ieee754_ptr, const int *i_ptr, size_t n) {
  n /= sizeof(int);
  while (n--) ieee754_ptr[n] = (Ieee754)i_ptr[n];
  return (void *)ieee754_ptr;
}

inline void *malloc_ieee754(size_t size, int32_t dw, int32_t ew, int32_t sc) {
  Ieee754 *ptr = (Ieee754 *)calloc(size, 1);
  if (!(size % sizeof(Ieee754))) {
    Ieee754 zero(dw, ew, sc);
    size_t n = size / sizeof(Ieee754);
    while (n--) ptr[n] = zero;
  }
  return (void *)ptr;
}

inline void *malloc_ieee754(size_t size, int32_t dw, int32_t ew) {
  return malloc_ieee754(size, dw, ew, 0);
}

inline void *malloc_ieee754(size_t size) {
  return malloc_ieee754(size, 0, 0, 0);
}

#define malloc malloc_ieee754

inline void *calloc(size_t nitems, size_t size, int32_t dw, int32_t ew, int32_t sc) {
  Ieee754 *ptr = (Ieee754 *)calloc(nitems, size);
  Ieee754 zero(dw, ew, sc);
  while (nitems--) ptr[nitems] = zero;
  return (void *)ptr;
}

inline void *calloc(size_t nitems, size_t size, int32_t dw, int32_t ew) {
  return calloc(nitems, size, dw, ew, 0);
}

#define printf printf_ieee754
#define fprintf fprintf_ieee754

#define scanf scanf_ieee754
#define fscanf fscanf_ieee754
#define sscanf sscanf_ieee754

inline size_t getlen_(const char * str) {
  size_t len = 0;
  if (!str) return len;
  while (str[len] != '%' && str[len]) len++;
  while (str[len] != 'c' &&
         str[len] != 's' &&
         str[len] != 'd' && str[len] != 'i' &&
         str[len] != 'e' && str[len] != 'E' &&
         str[len] != 'f' && str[len] != 'F' &&
         str[len] != 'g' && str[len] != 'G' &&
         str[len] != 'o' &&
         str[len] != 'u' &&
         str[len] != 'x' && str[len] != 'X' &&
         str[len] != 'p' &&
         str[len] != 'n' &&
         str[len])
    len++;
  if (str[len]) len++;
  return len;
}

inline int vsnprintf_ieee754(char *s, size_t n, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int ret = vsnprintf(s, n, fmt, args);
  va_end(args);
  return ret;
}

extern char fmt_ieee754[1024];
extern char buf_ieee754[1024];
extern char buf2_ieee754[1024];
extern char str_ieee754[1024];

inline int vfprintf_ieee754(FILE *fp, const char *fmt, va_list args) {
  size_t len = getlen_(fmt);
  if (!len) return 0;
  memcpy(fmt_ieee754, fmt, len);
  fmt_ieee754[len] = 0;

  int ret;
  if (fmt_ieee754[len-1] == 'f' ||
      fmt_ieee754[len-1] == 'e' ||
      fmt_ieee754[len-1] == 'g') {
    Ieee754 num_ieee754 = va_arg(args, Ieee754);
    ret = vsnprintf_ieee754(buf_ieee754, 1023, fmt_ieee754, (double)num_ieee754);
    fputs(buf_ieee754, fp);
  } else {
    ret = vfprintf(fp, fmt_ieee754, args);
  }
  return ret + vfprintf_ieee754(fp, fmt+len, args);
}

inline int fprintf_ieee754(FILE *fp, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int ret = vfprintf_ieee754(fp, fmt, args);
  va_end(args);
  return ret;
}

inline int printf_ieee754(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int ret = vfprintf_ieee754(stdout, fmt, args);
  va_end(args);
  return ret;
}

inline char* sgetnw(char *buf, int n, char *str) {
  int i = 0;
  while (*str++ == ' ');
  if (!*str--) return 0;
  do buf[i++] = *str++;
  while (buf[i-1] != ' ' && buf[i-1] != '\n' && *str && n--);
  buf[i-1] = 0;
  return str;
}

inline int sscanf2_ieee754(char *str, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int ret = vsscanf(str, fmt, args);
  va_end(args);
  return ret;
}

inline int vsscanf_ieee754(char *str, const char *fmt, va_list args) {
  while (*str == ' ') str++;
  while (*fmt == ' ') fmt++;
  char *str_nxt = strchr(str, ' ');
  if (!str_nxt) str_nxt = str + strlen(str);
  memcpy(str_ieee754, str, str_nxt-str);
  str_ieee754[str_nxt-str] = 0;

  size_t len = getlen_(fmt);
  if (!len) return 0;
  memcpy(fmt_ieee754, fmt, len);
  fmt_ieee754[len] = 0;

  int ret;
  if (fmt_ieee754[len-1] == 'f' ||
      fmt_ieee754[len-1] == 'e' ||
      fmt_ieee754[len-1] == 'g') {
    Ieee754 *ieee754_ptr = va_arg(args, Ieee754*);
    sgetnw(buf2_ieee754, 1024, (char *)str);
    *ieee754_ptr = (Ieee754) atof(buf2_ieee754);
    ret = 1;
  } else {
    void *ptr = va_arg(args, void *);
    ret = sscanf2_ieee754(str_ieee754, fmt_ieee754, ptr);
  }
  str_nxt = strchr(str, ' ');
  if (str_nxt) ret += vsscanf_ieee754(str_nxt, fmt+len, args);
  return ret;
}

inline int vfscanf_ieee754(FILE *fp, const char *fmt, va_list args) {
  char *str = buf_ieee754;
  int ret = 0;
  while (fgets(str, 1024-(str-buf_ieee754), fp)) {
    char *lspace = 0;
    if (strlen(buf_ieee754) == 1023) {
      lspace = strrchr(buf_ieee754, ' ');
      *lspace++ = 0;
    }
    int ret_int = vsscanf_ieee754(buf_ieee754, fmt, args);
    ret += ret_int;
    if (lspace) strcpy(buf_ieee754, lspace);
    else break;
    str = buf_ieee754 + strlen(lspace);
    while (ret_int--) {
      while (*fmt++ != '%');
      while (*fmt++ != ' ');
    }
  }
  return ret;
}

inline int fscanf_ieee754(FILE *fp, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int ret = vfscanf_ieee754(fp, fmt, args);
  va_end(args);
  return ret;
}

inline int scanf_ieee754(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int ret = vfscanf_ieee754(stdin, fmt, args);
  va_end(args);
  return ret;
}

inline int sscanf_ieee754(char *str, const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  int ret = vsscanf_ieee754(str, fmt, args);
  va_end(args);
  return ret;
}

#endif
