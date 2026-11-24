#!/usr/bin/env python3
"""Merges the Verilator coverage of one unit and reports it per source file.

usage: coverage.py <unit> <coverage directory> <format>

Writes <dir>/merged_<format>.dat, annotated sources in <dir>/annotated_<format> and
the report <dir>/coverage_<format>.rpt, and prints the summary. A point covers all the instances of its
source line: it is hit if any instance hits it. Testbench files are left out.
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


def main():
    unit, fmt = sys.argv[1], sys.argv[3]
    # the source paths in the data are relative to the simulation directory
    os.chdir(os.path.dirname(os.path.abspath(sys.argv[2])))
    cov_dir = os.path.basename(os.path.abspath(sys.argv[2]))
    dats = sorted(glob.glob(os.path.join(cov_dir, f"{fmt}_*.dat")))
    if not dats:
        sys.exit(f"coverage.py: no coverage data in {cov_dir}")
    merged = os.path.join(cov_dir, f"merged_{fmt}.dat")
    subprocess.run(["verilator_coverage", "--write", merged] + dats, check=True,
                   stdout=subprocess.DEVNULL)
    subprocess.run(["verilator_coverage", "--annotate", os.path.join(cov_dir, f"annotated_{fmt}"),
                    "--annotate-min", "1", merged], check=True, stdout=subprocess.DEVNULL)

    # (file, kind, line, name) -> count summed over instances
    hits = collections.defaultdict(int)
    for fields, count in points(merged):
        path = os.path.normpath(fields.get("f", ""))
        if path.endswith("_tb.v"):
            continue
        kind = "toggle" if fields.get("page", "").startswith("v_toggle") else "line"
        hits[(path, kind, int(fields.get("l", 0)), fields.get("o", ""))] += count

    files = sorted({k[0] for k in hits})
    lines = [f"Coverage of {unit}, {fmt} ({len(dats)} runs)", "",
             f"{'File':<40} {'Lines':>13} {'Toggles':>15}"]
    detail = []
    for path in files:
        stats = {}
        for kind in ("line", "toggle"):
            pts = {k: v for k, v in hits.items() if k[0] == path and k[1] == kind}
            stats[kind] = (sum(1 for v in pts.values() if v), len(pts))
        (lh, lt), (th, tt) = stats["line"], stats["toggle"]
        lines.append(f"{os.path.basename(path):<40} {lh:>5}/{lt:<5}{100 * lh / max(lt, 1):5.1f}% "
                     f"{th:>5}/{tt:<5}{100 * th / max(tt, 1):5.1f}%")

        missed_lines = sorted({k[2] for k, v in hits.items()
                               if k[0] == path and k[1] == "line" and not v})
        # signal -> bits that miss a toggle direction
        missed_sigs = collections.defaultdict(set)
        for k, v in hits.items():
            if k[0] == path and k[1] == "toggle" and not v:
                sig = re.sub(r"(\[\d+\])?:[01]->[01]$", "", k[3])
                bit = re.search(r"\[(\d+)\]", k[3])
                missed_sigs[sig].add(int(bit.group(1)) if bit else 0)
        if missed_lines or missed_sigs:
            detail.append(f"\n{path}")
        if missed_lines:
            detail.append("  lines never executed: " + ", ".join(map(str, missed_lines)))
        for sig in sorted(missed_sigs):
            bits = sorted(missed_sigs[sig])
            detail.append(f"  {sig}: {len(bits)} bit(s) not toggled both ways: {bits}")

    report = "\n".join(lines + ["", "Not covered:"] + detail) + "\n"
    with open(os.path.join(cov_dir, f"coverage_{fmt}.rpt"), "w") as f:
        f.write(report)
    print("\n".join(lines))
    print(f"details: {os.path.join(os.getcwd(), cov_dir, f'coverage_{fmt}.rpt')}")


if __name__ == "__main__":
    main()
