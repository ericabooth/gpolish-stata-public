"""Synthetic label-placement scenarios for the benchmark.

Writes data/<scenario>.csv (x, y, label, lab) and one manifest per scenario set:
  data/manifest_synthetic.csv  main set: three designs, test seeds 1 to 20
  data/manifest_tuning.csv     tuning seeds 101 to 110, kept apart from the test seeds (used by tune.py only)
  data/manifest_scale.csv      scale set: 150 and 300 points, all labelled, seeds 1 to 5
  data/manifest_fontmark.csv   fontmark set: the 60-of-60 design, seeds 1 to 10, with 7 or 11 pt labels
                               (6 pt markers) or 4 or 9 pt markers (8.6 pt labels)
Points come from a mixture of three Gaussian clusters in the unit square, so labels
crowd in some places and not others. Labels are made-up names of 4 to 14 characters.
The real-data scenarios (main and perm sets) come from make_real.do.
Run from the benchmark folder:  python make_synthetic.py
"""
import csv
import os
import numpy as np
from common import MANIFEST_FIELDS, LABEL_PT, MARKER_PT

SYL = ["ka", "lo", "mi", "ren", "sa", "tor", "vel", "an", "bri", "cho", "dun", "el",
       "fa", "gor", "hal", "is", "jun", "kir", "lum", "mor", "nel", "ost", "pra", "qui"]
DESIGNS = [("syn30all", 30, 30), ("syn60all", 60, 60), ("syn60sub", 60, 20)]
SEEDS = range(1, 21)          # test seeds: used only to report results
TUNE_SEEDS = range(101, 111)  # tuning seeds: used only to choose gpolish's placement settings
SCALE = [("syn150all", 150, 150), ("syn300all", 300, 300)]
SCALE_SEEDS = range(1, 6)
# fontmark conditions: (tag, label font size in points, marker diameter in points)
FONTMARK = [("f7", 7.0, MARKER_PT), ("f11", 11.0, MARKER_PT), ("m4", LABEL_PT, 4.0), ("m9", LABEL_PT, 9.0)]
FONTMARK_SEEDS = range(1, 11)


def names(rng, n):
    out = set()
    while len(out) < n:
        k = rng.integers(2, 5)
        w = "".join(rng.choice(SYL, size=k)).capitalize()
        if rng.random() < 0.3:
            w += " " + "".join(rng.choice(SYL, size=rng.integers(1, 3))).capitalize()
        if 4 <= len(w) <= 14:
            out.add(w)
    return sorted(out)


def points(rng, n):
    centres = rng.uniform(0.2, 0.8, size=(3, 2))
    k = rng.integers(0, 3, size=n)
    xy = centres[k] + rng.normal(0, 0.12, size=(n, 2))
    return np.clip(xy, 0.02, 0.98)


def draw(n, nlab, seed):
    """Points, names and the labelled subset for one design and seed (the same as in every earlier release)."""
    rng = np.random.default_rng(1000 * n + 100 * nlab + seed)
    xy = points(rng, n)
    labs = names(rng, n)
    rng.shuffle(labs)
    chosen = set(rng.choice(n, size=nlab, replace=False))
    return xy, labs, chosen


def write_data(scen, xy, labs, chosen):
    with open(f"data/{scen}.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["x", "y", "label", "lab"])
        for i in range(len(labs)):
            w.writerow([f"{xy[i, 0]:.6f}", f"{xy[i, 1]:.6f}", labs[i], int(i in chosen)])


def row(scen, set_name, design, seed, n, nlab, label_pt=LABEL_PT, marker_pt=MARKER_PT):
    return dict(scenario=scen, set=set_name, design=design, seed=seed, n=n, nlab=nlab, fit=0,
                fa="", fb="", fx0="", fx1="", label_pt=label_pt, marker_pt=marker_pt)


def write_manifest(path, rows):
    with open(path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS)
        w.writeheader()
        w.writerows(rows)
    print(len(rows), "scenarios ->", path)


def main():
    os.makedirs("data", exist_ok=True)
    for seeds, tag, set_name, path in ((SEEDS, "s", "main", "data/manifest_synthetic.csv"),
                                       (TUNE_SEEDS, "t", "tuning", "data/manifest_tuning.csv")):
        rows = []
        for design, n, nlab in DESIGNS:
            for seed in seeds:
                scen = f"{design}_{tag}{seed:02d}"
                write_data(scen, *draw(n, nlab, seed))
                rows.append(row(scen, set_name, design, seed, n, nlab))
        write_manifest(path, rows)
    rows = []
    for design, n, nlab in SCALE:
        for seed in SCALE_SEEDS:
            scen = f"{design}_s{seed:02d}"
            write_data(scen, *draw(n, nlab, seed))
            rows.append(row(scen, "scale", design, seed, n, nlab))
    write_manifest("data/manifest_scale.csv", rows)
    rows = []
    for tag, lpt, mpt in FONTMARK:
        for seed in FONTMARK_SEEDS:
            scen = f"syn60all_{tag}_s{seed:02d}"
            write_data(scen, *draw(60, 60, seed))     # the same points and names as syn60all_s<seed>
            rows.append(row(scen, "fontmark", f"syn60all_{tag}", seed, 60, 60, lpt, mpt))
    write_manifest("data/manifest_fontmark.csv", rows)


if __name__ == "__main__":
    main()
