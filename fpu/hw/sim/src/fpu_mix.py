#!/usr/bin/env python3
"""Writes a random mix of TestFloat add, sub, mul and div vectors.

usage: fpu_mix.py <testfloat_gen> <count> <vector file>

Each output line is: funct a b expected
"""

import random
import subprocess
import sys

OPS = [("add", 0, 30), ("sub", 1, 30), ("mul", 2, 35), ("div", 3, 5)]
SEED = 754


def vectors(tool, op):
    text = subprocess.check_output([tool, "-level", "1", "-rnear_even", f"f32_{op}"], universal_newlines=True)
    return [line.split()[:3] for line in text.splitlines()]


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    tool, count, path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    rng = random.Random(SEED)
    pools = {funct: vectors(tool, op) for op, funct, _ in OPS}
    functs = [funct for _, funct, _ in OPS]
    weights = [weight for _, _, weight in OPS]
    with open(path, "w") as out:
        for funct in rng.choices(functs, weights, k=count):
            a, b, expected = rng.choice(pools[funct])
            out.write(f"{funct} {a} {b} {expected}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
