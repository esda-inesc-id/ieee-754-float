#!/usr/bin/env python3
"""Checks the C model against TestFloat and the RTL, and the Python wrapper against the C model.

Every check runs in the five rounding modes. The model-vs-RTL checks also run with the mode
changing on every operation or product ("cycle"); modes other than RNE use the first
1/MODE_FRACTION of the vectors.

usage: check.py --rtl <repository root> --work <directory> --model-run <program>
"""

import argparse
import concurrent.futures
import importlib.util
import os
import random
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "python"))
import ieee754  # noqa: E402

FORMATS = [(32, 8), (16, 5), (64, 11)]
OPS = ["add", "sub", "mul", "div"]
OP_WEIGHTS = [30, 30, 35, 5]
GUARDS_32 = [(0, 0), (4, 0), (0, 4), (3, 5), (8, 8)]
GUARDS_OTHER = [(0, 0), (2, 3)]
STREAMS = 6000
MIX = 100000
OTHER_STREAMS = 2000
OTHER_MIX = 20000
SEED = 754
# rounding modes: rnd_mode value, name and TestFloat option
MODES = [(0, "rne", "-rnear_even"), (1, "rtz", "-rminMag"), (2, "rdn", "-rmin"),
         (3, "rup", "-rmax"), (4, "rmm", "-rnear_maxMag")]
MODE_FRACTION = 8
JOBS = os.cpu_count() or 1

TF_GEN = "lib/sim/testfloat-build/berkeley-testfloat-3/build/Linux-x86_64-GCC/testfloat_gen"
LIB_SRC = ["unpack.v", "cls.v", "round.v", "pack.v"]


def rtl_sources(root, unit):
    lib = [os.path.join(root, "lib/src", name) for name in LIB_SRC]
    if unit == "fmac":
        return [os.path.join(root, "fmac/hw/src", name) for name in ("fmac.v", "fmac_core.v")] + lib
    files = ["fpu/hw/src/fpu.v", "fadd/hw/src/fadd_core.v", "fmul/hw/src/fmul_core.v", "fdiv/hw/src/fdiv_core.v",
             "lib/src/norm.v"]
    return [os.path.join(root, name) for name in files] + lib


def simulate(root, work, unit, runs, data_w, exp_w, lguard=0, rguard=0):
    """Runs the RTL on {rnd: vector file} and returns {rnd: result lines}.

    rnd is a mode value or "cycle".
    """
    run_dir = os.path.join(work, f"{unit}_{data_w}_{lguard}_{rguard}")
    os.makedirs(run_dir, exist_ok=True)
    defines = [f"-DRTL_DATA_W={data_w}", f"-DRTL_EXP_W={exp_w}"]
    if unit == "fmac":
        defines += ["-DFMAC", f"-DRTL_LGUARD_W={lguard}", f"-DRTL_RGUARD_W={rguard}"]
    xezim = ["xezim", "--max-time", "1000s", "-s", "rtl_tb", "-I", os.path.join(root, "lib/src"),
             *defines, os.path.join(HERE, "rtl_tb.v"), *rtl_sources(root, unit)]

    def run(rnd, vectors):
        mode_dir = os.path.join(run_dir, f"rnd_{rnd}")
        os.makedirs(mode_dir, exist_ok=True)
        link = os.path.join(mode_dir, "vectors.tv")
        if os.path.lexists(link):
            os.remove(link)
        os.symlink(os.path.abspath(vectors), link)
        plusarg = "+rnd_cycle" if rnd == "cycle" else f"+rnd_mode={rnd}"
        subprocess.run([*xezim, plusarg], cwd=mode_dir, check=True, stdout=subprocess.DEVNULL)
        with open(os.path.join(mode_dir, "results.out")) as src:
            return [int(line, 16) for line in src.read().split()]

    with concurrent.futures.ThreadPoolExecutor(JOBS) as pool:
        futures = {rnd: pool.submit(run, rnd, vectors) for rnd, vectors in runs.items()}
        return {rnd: future.result() for rnd, future in futures.items()}


def model(tool, mode, vectors, *args):
    with open(vectors) as src:
        text = subprocess.run([tool, mode, *map(str, args)], stdin=src, check=True,
                              capture_output=True, text=True).stdout
    return [int(line, 16) for line in text.split()]


def report(name, expected, actual, labels=None):
    """Prints one check line and returns 1 on a mismatch."""
    bad = [i for i, (x, y) in enumerate(zip(expected, actual)) if x != y]
    count_ok = len(expected) == len(actual) and len(expected) > 0
    print(f"{name}: vectors={len(expected)} mismatches={len(bad)}"
          + ("" if count_ok else f" (result count {len(actual)})"), flush=True)
    for i in bad[:5]:
        label = f" {labels[i]}" if labels else ""
        print(f"  index {i}{label}: rtl/reference {expected[i]:x}, model {actual[i]:x}")
    return 0 if count_ok and not bad else 1


def check_testfloat(root, tool):
    """Model against TestFloat level 1, in every format, operation and mode; mulAdd runs
    fmac on a*b + c*1.0."""
    gen = os.path.join(root, TF_GEN)

    def run(data_w, exp_w, op, rnd, option):
        source = subprocess.Popen([gen, "-level", "1", option, f"f{data_w}_{op}"],
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        result = subprocess.run([tool, "tf", op, str(data_w), str(exp_w), str(rnd)],
                                stdin=source.stdout, capture_output=True, text=True)
        source.stdout.close()
        source.wait()
        return result

    jobs = [(data_w, exp_w, op, rnd, option) for data_w, exp_w in FORMATS
            for op in OPS + ["mulAdd"] for rnd, _, option in MODES]
    failed = 0
    with concurrent.futures.ThreadPoolExecutor(JOBS) as pool:
        for result in pool.map(lambda job: run(*job), jobs):
            print(result.stdout + result.stderr, end="", flush=True)
            failed |= result.returncode
    return failed


def read_streams(path):
    with open(path) as src:
        tokens = src.read().split()
    streams, pos = [], 0
    while pos < len(tokens):
        n = int(tokens[pos])
        pos += 1
        streams.append([(int(tokens[pos + 2 * i], 16), int(tokens[pos + 2 * i + 1], 16))
                        for i in range(n)])
        pos += 2 * n
    return streams


def read_mix(path):
    with open(path) as src:
        rows = [line.split() for line in src]
    return [(int(row[0]), int(row[1], 16), int(row[2], 16)) for row in rows]


def cycle_mode(k):
    return (k * 3 + (k >> 3)) & 7


def check_wrapper(name, fmt, mix_rows, c_results, rnd):
    ops = [fmt.add, fmt.sub, fmt.mul, fmt.div]
    results = []
    with ieee754.Rounding(0 if rnd == "cycle" else rnd):
        for k, (funct, a, b) in enumerate(mix_rows):
            if rnd == "cycle":
                ieee754.set_rounding(cycle_mode(k))
            results.append(ops[funct](a, b))
    return report(f"python vs C {name}", c_results, results)


def check_wrapper_mac(name, fmt, streams, c_results, lguard, rguard, rnd):
    results = []
    k = 0
    with ieee754.Rounding(0 if rnd == "cycle" else rnd):
        for terms in streams:
            with ieee754.Mac(fmt.data_w, fmt.exp_w, lguard, rguard) as mac:
                for a, b in terms:
                    if rnd == "cycle":
                        ieee754.set_rounding(cycle_mode(k))
                        k += 1
                    mac.push(a, b)
                results.append(mac.result())
    return report(f"python vs C {name}", c_results, results)


def write_mix(root, path, data_w, count):
    rng = random.Random(SEED)
    gen = os.path.join(root, TF_GEN)
    pools = []
    for op in OPS:
        text = subprocess.check_output([gen, "-level", "1", "-rnear_even", f"f{data_w}_{op}"],
                                       text=True, stderr=subprocess.DEVNULL)
        pools.append([line.split()[:2] for line in text.splitlines()])
    with open(path, "w") as out:
        for funct in rng.choices(range(4), OP_WEIGHTS, k=count):
            a, b = rng.choice(pools[funct])
            out.write(f"{funct} {a} {b}\n")


def write_streams(path, data_w, exp_w, count):
    """Random streams with cancellation, subnormals and special values."""
    rng = random.Random(SEED)
    f_w = data_w - exp_w - 1
    exp_max = (1 << exp_w) - 1
    bias = exp_max >> 1
    sign = 1 << (data_w - 1)
    inf = exp_max << f_w
    specials = [0, sign, inf, inf | sign, inf | (1 << (f_w - 1)), bias << f_w, 1, sign | 1]

    def make(lo, hi):
        exp = rng.randint(max(lo, 0), min(hi, exp_max - 1))
        return (rng.getrandbits(1) << (data_w - 1)) | (exp << f_w) | rng.getrandbits(f_w)

    span = max(bias // 8, 3)
    with open(path, "w") as out:
        for i in range(count):
            kind = i % 5
            size = rng.randint(1, 32)
            if kind == 0:
                terms = [(make(bias - span, bias + span), make(bias - span, bias + span))
                         for _ in range(size)]
            elif kind == 1:
                terms = [(make(0, exp_max - 1), make(0, exp_max - 1)) for _ in range(size)]
            elif kind == 2:
                terms = [(make(bias - span, bias + span), make(bias - span, bias + span))
                         for _ in range(size)]
                terms += [(a ^ sign, b) for a, b in terms]
                terms.append((make(bias - span, bias), make(bias - span, bias)))
                rng.shuffle(terms)
            elif kind == 3:
                terms = [(rng.getrandbits(f_w) >> rng.randint(0, f_w), make(bias, bias + span))
                         for _ in range(size)]
            else:
                terms = [(rng.choice(specials), rng.choice(specials))
                         for _ in range(rng.randint(1, 6))]
            out.write(f"{len(terms)}\n")
            for a, b in terms:
                out.write(f"{a:x} {b:x}\n")


def fmac_streams_module(root):
    path = os.path.join(root, "fmac/hw/sim/src/fmac_streams.py")
    spec = importlib.util.spec_from_file_location("fmac_streams", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def mode_runs(path, count, write):
    """{rnd: vector file}: all vectors in RNE, the first count / MODE_FRACTION otherwise."""
    short = path.replace(".tv", "_short.tv")
    write(short, max(count // MODE_FRACTION, 1))
    runs = {0: path}
    runs.update({rnd: short for rnd, _, _ in MODES[1:]})
    runs["cycle"] = short
    return runs


def mode_name(rnd):
    return rnd if rnd == "cycle" else MODES[rnd][1]


def check_format(root, work, tool, data_w, exp_w, stream_runs, mix_runs):
    failed = 0
    fmt = ieee754.Format(data_w, exp_w)
    name = f"f{data_w}"

    mix_rtl = simulate(root, work, "fpu", mix_runs, data_w, exp_w)
    for rnd, vectors in mix_runs.items():
        mix_rows = read_mix(vectors)
        labels = [f"funct {f} a {a:x} b {b:x}" for f, a, b in mix_rows]
        mix_model = model(tool, "mix", vectors, data_w, exp_w, rnd)
        tag = f"fpu mix {name} {mode_name(rnd)}"
        failed |= report(f"{tag} model vs RTL", mix_rtl[rnd], mix_model, labels)
        failed |= check_wrapper(tag, fmt, mix_rows, mix_model, rnd)

    for lguard, rguard in (GUARDS_32 if data_w == 32 else GUARDS_OTHER):
        mac_rtl = simulate(root, work, "fmac", stream_runs, data_w, exp_w, lguard, rguard)
        for rnd, vectors in stream_runs.items():
            streams = read_streams(vectors)
            tag = f"fmac {name} LGUARD_W={lguard} RGUARD_W={rguard} {mode_name(rnd)}"
            mac_model = model(tool, "mac", vectors, data_w, exp_w, lguard, rguard, rnd)
            labels = [f"stream length {len(terms)}" for terms in streams]
            failed |= report(f"{tag} model vs RTL", mac_rtl[rnd], mac_model, labels)
            failed |= check_wrapper_mac(tag, fmt, streams, mac_model, lguard, rguard, rnd)
    return failed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rtl", required=True)
    parser.add_argument("--work", required=True)
    parser.add_argument("--model-run", required=True)
    args = parser.parse_args()
    root = os.path.abspath(args.rtl)
    work = os.path.abspath(args.work)
    tool = os.path.abspath(args.model_run)
    os.makedirs(work, exist_ok=True)

    failed = check_testfloat(root, tool)

    for data_w, exp_w in FORMATS:
        streams_tv = os.path.join(work, f"streams_{data_w}.tv")
        mix_tv = os.path.join(work, f"mix_{data_w}.tv")
        if data_w == 32:
            def gen_streams(path, count):
                fmac_streams_module(root).generate(count, path)

            def gen_mix(path, count):
                subprocess.run([sys.executable, os.path.join(root, "fpu/hw/sim/src/fpu_mix.py"),
                                os.path.join(root, TF_GEN), str(count), path], check=True)

            streams, mix = STREAMS, MIX
        else:
            def gen_streams(path, count, data_w=data_w, exp_w=exp_w):
                write_streams(path, data_w, exp_w, count)

            def gen_mix(path, count, data_w=data_w):
                write_mix(root, path, data_w, count)

            streams, mix = OTHER_STREAMS, OTHER_MIX
        gen_streams(streams_tv, streams)
        gen_mix(mix_tv, mix)
        failed |= check_format(root, work, tool, data_w, exp_w,
                               mode_runs(streams_tv, streams, gen_streams),
                               mode_runs(mix_tv, mix, gen_mix))

    print("check: PASS" if not failed else "check: FAIL")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
