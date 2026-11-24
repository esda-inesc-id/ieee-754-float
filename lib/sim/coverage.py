#!/usr/bin/env python3
"""Merges the Verilator coverage of one unit and reports it per source file.

usage: coverage.py <unit> <coverage directory>

Merges every run in the directory, whatever its test and format, writes
<dir>/merged.dat, annotated sources in <dir>/annotated and the report
<dir>/coverage.rpt, and exits with 1 if a point is neither
covered nor waived in coverage_waivers.txt, and prints the summary. A point covers all the instances of its
source line and every format: it is hit if any instance in any run hits it. Testbench files are left out.
"""

import collections
import glob
import os
import re
import subprocess
import sys

FIELD = re.compile("\x01([^\x02]+)\x02([^\x01]*)")


def points(dat):
    """Yields (fields, count) for every coverage point of a Verilator .dat file."""
    with open(dat) as f:
        for line in f:
            if not line.startswith("C '"):
                continue
            key, count = line[3:].rsplit("' ", 1)
            yield dict(FIELD.findall(key)), int(count)


WAIVERS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "coverage_waivers.txt")


def load_waivers():
    """Reads coverage_waivers.txt: <units> <file> <signal regex> <bits> <reason>.

    <units> is a comma-separated list or *. <bits> is all, msb, top<N> (the N top
    bits), low<N> (the N low bits) or a list of bit indices. A signal's width is
    its widest in any format, so msb is the top bit of the widest format.
    """
    waivers = []
    with open(WAIVERS) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            units, file, sig, bits, reason = line.split(None, 4)
            waivers.append((units.split(","), file, re.compile(sig), bits, reason))
    return waivers


def waiver_reason(waivers, unit, base, sig, bit, width):
    """Returns the reason of the first waiver for this bit, or None."""
    for units, file, sig_re, bits, reason in waivers:
        if "*" not in units and unit not in units:
            continue
        if file not in ("*", base) or not sig_re.fullmatch(sig):
            continue
        if bits == "all":
            hit = True
        elif bits == "msb":
            hit = bit == width - 1
        elif bits.startswith("top"):
            hit = bit >= width - int(bits[3:])
        elif bits.startswith("low"):
            hit = bit < int(bits[3:])
        else:
            hit = bit in {int(b) for b in bits.split(",")}
        if hit:
            return reason
    return None


def main():
    unit = sys.argv[1]
    # the source paths in the data are relative to the simulation directory
    os.chdir(os.path.dirname(os.path.abspath(sys.argv[2])))
    cov_dir = os.path.basename(os.path.abspath(sys.argv[2]))
    dats = sorted(d for d in glob.glob(os.path.join(cov_dir, "*.dat"))
                  if os.path.basename(d) != "merged.dat")
    if not dats:
        sys.exit(f"coverage.py: no coverage data in {cov_dir}")
    merged = os.path.join(cov_dir, "merged.dat")
    subprocess.run(["verilator_coverage", "--write", merged] + dats, check=True,
                   stdout=subprocess.DEVNULL)
    subprocess.run(["verilator_coverage", "--annotate", os.path.join(cov_dir, "annotated"),
                    "--annotate-min", "1", merged], check=True, stdout=subprocess.DEVNULL)

    # (file, kind, line, name) -> count summed over instances
    hits = collections.defaultdict(int)
    for fields, count in points(merged):
        path = os.path.normpath(fields.get("f", ""))
        if path.endswith("_tb.v"):
            continue
        kind = "toggle" if fields.get("page", "").startswith("v_toggle") else "line"
        hits[(path, kind, int(fields.get("l", 0)), fields.get("o", ""))] += count

    waivers = load_waivers()

    # signal -> width, from the highest bit index of its toggle points
    def split(name):
        bit = re.search(r"\[(\d+)\]:[01]->[01]$", name)
        return re.sub(r"(\[\d+\])?:[01]->[01]$", "", name), int(bit.group(1)) if bit else 0
    width = collections.defaultdict(int)
    for (path, kind, _, name) in hits:
        if kind == "toggle":
            sig, bit = split(name)
            width[(path, sig)] = max(width[(path, sig)], bit + 1)

    files = sorted({k[0] for k in hits})
    lines = [f"Coverage of {unit} ({len(dats)} runs); waived points are left out", "",
             f"{'File':<16} {'Lines':>17} {'Toggles':>19} {'Waived':>7}"]
    detail, waived_detail = [], []
    uncovered = 0
    for path in files:
        base = os.path.basename(path)
        line_pts = {k: v for k, v in hits.items() if k[0] == path and k[1] == "line"}
        missed_lines = sorted({k[2] for k, v in line_pts.items() if not v})
        # signal -> bits that miss a toggle direction, split into waived and not
        missed, waived = collections.defaultdict(set), collections.defaultdict(set)
        reasons = {}
        n_tog = n_tog_hit = n_waived = 0
        for k, v in hits.items():
            if k[0] != path or k[1] != "toggle":
                continue
            sig, bit = split(k[3])
            reason = waiver_reason(waivers, unit, base, sig, bit, width[(path, sig)])
            if reason is not None and not v:
                waived[sig].add(bit)
                reasons[sig] = reason
                n_waived += 1
                continue
            n_tog += 1
            if v:
                n_tog_hit += 1
            else:
                missed[sig].add(bit)
        lh, lt = sum(1 for v in line_pts.values() if v), len(line_pts)
        lines.append(f"{base:<16} {lh:>5}/{lt:<5}{100 * lh / max(lt, 1):6.1f}% "
                     f"{n_tog_hit:>5}/{n_tog:<5}{100 * n_tog_hit / max(n_tog, 1):6.1f}% {n_waived:>7}")
        uncovered += len(missed_lines) + sum(len(b) for b in missed.values())
        if missed_lines or missed:
            detail.append(f"\n{path}")
        if missed_lines:
            detail.append("  lines never executed: " + ", ".join(map(str, missed_lines)))
        for sig in sorted(missed):
            bits = sorted(missed[sig])
            detail.append(f"  {sig}: {len(bits)} bit(s) not toggled both ways: {bits}")
        if waived:
            waived_detail.append(f"\n{path}")
        for sig in sorted(waived):
            bits = sorted(waived[sig])
            waived_detail.append(f"  {sig} {bits}: {reasons[sig]}")

    lines.append("")
    lines.append(f"{uncovered} point(s) not covered and not waived")
    report = "\n".join(lines + ["", "Not covered:"] + (detail or ["  none"]) +
                       ["", "Waived:"] + (waived_detail or ["  none"])) + "\n"
    with open(os.path.join(cov_dir, "coverage.rpt"), "w") as f:
        f.write(report)
    print("\n".join(lines))
    print(f"details: {os.path.join(os.getcwd(), cov_dir, 'coverage.rpt')}")
    return 1 if uncovered else 0


if __name__ == "__main__":
    sys.exit(main())
