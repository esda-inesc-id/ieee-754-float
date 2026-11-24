#!/usr/bin/env python3
"""Generates fmac product streams and checks the results against the exact sum.

usage: fmac_streams.py gen <streams> <vector file>
       fmac_streams.py check <vector file> <result file>

A finite result passes if |result - exact| <= ulp(exact)/2 + (n+2) * 2**-46 * sum(|a*b|).
"""

import random
import sys
from fractions import Fraction

F_W = 23
BIAS = 127
EXP_MAX = 255
SIGN = 1 << 31
QNAN = 0x7FC00000
INF = 0x7F800000
MAX_FINITE = (2 - Fraction(1, 2**F_W)) * 2**BIAS
OVERFLOW = MAX_FINITE + Fraction(2 ** (BIAS - F_W), 2)
SEED = 754


def fields(bits):
    return bits >> 31, (bits >> F_W) & EXP_MAX, bits & ((1 << F_W) - 1)


def is_nan(bits):
    _, exp, frac = fields(bits)
    return exp == EXP_MAX and frac != 0


def is_inf(bits):
    _, exp, frac = fields(bits)
    return exp == EXP_MAX and frac == 0


def is_zero(bits):
    return bits & (SIGN - 1) == 0


def value(bits):
    sign, exp, frac = fields(bits)
    man = frac if exp == 0 else frac | (1 << F_W)
    scale = max(exp, 1) - BIAS - F_W
    val = Fraction(man) * Fraction(2) ** scale
    return -val if sign else val


def log2_floor(mag):
    k = mag.numerator.bit_length() - mag.denominator.bit_length()
    if Fraction(2) ** k > mag:
        k -= 1
    return k


def ulp(val):
    if val == 0:
        return Fraction(2) ** (1 - BIAS - F_W)
    return Fraction(2) ** (max(log2_floor(abs(val)), 1 - BIAS) - F_W)


def encode(val):
    """Rounds a rational to the nearest binary32, ties to even."""
    sign = SIGN if val < 0 else 0
    mag = abs(val)
    if mag == 0:
        return sign
    exp = max(log2_floor(mag), 1 - BIAS)
    scaled = mag / Fraction(2) ** (exp - F_W)
    man = scaled.numerator // scaled.denominator
    rem = scaled - man
    if rem > Fraction(1, 2) or (rem == Fraction(1, 2) and man & 1):
        man += 1
    if man == 1 << (F_W + 1):
        man >>= 1
        exp += 1
    if exp > BIAS:
        return sign | INF
    if man < 1 << F_W:
        return sign | man
    return sign | ((exp + BIAS) << F_W) | (man - (1 << F_W))


def make(rng, exp_lo, exp_hi):
    exp = rng.randint(exp_lo, exp_hi)
    return (rng.getrandbits(1) << 31) | (exp << F_W) | rng.getrandbits(F_W)


def stream_narrow(rng):
    return [(make(rng, 120, 134), make(rng, 120, 134)) for _ in range(rng.randint(1, 16))]


def stream_wide(rng):
    return [(make(rng, 60, 190), make(rng, 60, 190)) for _ in range(rng.randint(1, 32))]


def stream_cancel(rng):
    terms = [(make(rng, 110, 140), make(rng, 110, 140)) for _ in range(rng.randint(1, 16))]
    terms += [(a ^ SIGN, b) for a, b in terms]
    terms.append((make(rng, 90, 110), make(rng, 90, 110)))
    rng.shuffle(terms)
    return terms


def stream_gendot(rng):
    """Ill-conditioned dot product, after Ogita, Rump and Oishi."""
    n = rng.randrange(8, 66, 2)
    half_cond = rng.randint(4, 30)
    terms = []
    partial = Fraction(0)
    for i in range(n):
        if i < n // 2:
            exp = BIAS + rng.randint(-half_cond, half_cond)
            a, b = make(rng, exp, exp), make(rng, exp, exp)
        else:
            exp = BIAS + round(half_cond * (n - 1 - i) / n)
            a = make(rng, exp, exp)
            target = value(make(rng, exp, exp)) * Fraction(1, 2**half_cond) - partial
            b = encode(target / value(a))
        terms.append((a, b))
        partial += value(a) * value(b)
    return terms


def stream_tiny(rng):
    terms = []
    for _ in range(rng.randint(1, 12)):
        a = rng.getrandbits(1) << 31 | rng.getrandbits(F_W) >> rng.randint(0, F_W)
        terms.append((a, make(rng, 90, 170)))
    return terms


def stream_special(rng):
    pool = [0, SIGN, INF, INF | SIGN, QNAN, 0x3F800000, 0xBF800000, 1, SIGN | 1]
    return [(rng.choice(pool), rng.choice(pool)) for _ in range(rng.randint(1, 6))]


def stream_carry(rng):
    """Same-sign products of equal magnitude: the accumulator carries on most additions."""
    sign = rng.getrandbits(1) << 31
    exp = rng.randint(BIAS - 2, BIAS + 2)
    full_range = rng.getrandbits(1)
    terms = []
    for _ in range(rng.randint(2, 64)):
        frac = rng.getrandbits(F_W) if full_range else ((1 << F_W) - 1) ^ rng.getrandbits(8)
        terms.append((sign | (exp << F_W) | frac, (BIAS << F_W) | frac))
    return terms


def stream_long(rng):
    n = rng.choice([256, 1024, 4096])
    return [(make(rng, 118, 136), make(rng, 118, 136)) for _ in range(n)]


GENERATORS = [
    stream_narrow,
    stream_wide,
    stream_cancel,
    stream_gendot,
    stream_tiny,
    stream_special,
    stream_carry,
]


def generate(count, path):
    rng = random.Random(SEED)
    with open(path, "w") as out:
        for i in range(count):
            gen = stream_long if i % 200 == 199 else GENERATORS[i % len(GENERATORS)]
            terms = gen(rng)
            out.write(f"{len(terms)}\n")
            for a, b in terms:
                out.write(f"{a:08x} {b:08x}\n")


def read_streams(path):
    with open(path) as src:
        tokens = src.read().split()
    pos = 0
    while pos < len(tokens):
        n = int(tokens[pos])
        pos += 1
        yield [(int(tokens[pos + 2 * i], 16), int(tokens[pos + 2 * i + 1], 16)) for i in range(n)]
        pos += 2 * n


def special_result(terms):
    """The IEEE result if the sum is NaN, infinite or a signed zero, else None."""
    pos_inf = neg_inf = False
    for a, b in terms:
        if is_nan(a) or is_nan(b):
            return QNAN
        if is_inf(a) or is_inf(b):
            if is_zero(a) or is_zero(b):
                return QNAN
            if (a ^ b) & SIGN:
                neg_inf = True
            else:
                pos_inf = True
    if pos_inf and neg_inf:
        return QNAN
    if pos_inf:
        return INF
    if neg_inf:
        return INF | SIGN
    if all(is_zero(a) or is_zero(b) for a, b in terms):
        return SIGN if all((a ^ b) & SIGN for a, b in terms) else 0
    return None


def check_one(terms, res):
    """Returns (passed, correctly rounded)."""
    expected = special_result(terms)
    if expected is not None:
        same = (is_nan(res) and is_nan(expected)) or res == expected
        return same, same

    products = [value(a) * value(b) for a, b in terms]
    exact = sum(products)
    rounded = encode(exact)
    if res == rounded:
        return True, True
    bound = (len(terms) + 2) * Fraction(1, 2**46) * sum(abs(p) for p in products)
    if is_nan(res):
        return False, False
    if is_inf(res):
        same_sign = (res & SIGN != 0) == (exact < 0)
        return same_sign and abs(exact) + bound >= OVERFLOW, False
    return abs(value(res) - exact) <= ulp(exact) / 2 + bound, False


def check(vector_path, result_path):
    with open(result_path) as src:
        results = [int(tok, 16) for tok in src.read().split()]
    streams = list(read_streams(vector_path))
    if len(results) != len(streams):
        print(f"FMAC_STREAMS ERROR: {len(streams)} streams, {len(results)} results")
        return 1
    fails = rounded = 0
    with open("fails_streams.tv", "w") as out:
        for i, (terms, res) in enumerate(zip(streams, results)):
            passed, exact_round = check_one(terms, res)
            rounded += exact_round
            if not passed:
                fails += 1
                out.write(f"stream {i} n={len(terms)} res={res:08x}\n")
    print(f"FMAC_STREAMS streams={len(streams)} correctly_rounded={rounded} fails={fails}")
    return 1 if fails or not streams else 0


def main():
    if len(sys.argv) == 4 and sys.argv[1] == "gen":
        generate(int(sys.argv[2]), sys.argv[3])
        return 0
    if len(sys.argv) == 4 and sys.argv[1] == "check":
        return check(sys.argv[2], sys.argv[3])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
