"""Synthetic label-placement scenarios for the benchmark.

Writes data/<scenario>.csv (x, y, label, lab) and appends rows to data/manifest_synthetic.csv.
Points come from a mixture of three Gaussian clusters in the unit square, so labels
crowd in some places and not others. Labels are made-up names of 4 to 14 characters.
Run from the benchmark folder:  python make_synthetic.py
"""
import csv
import os
import numpy as np

SYL = ["ka", "lo", "mi", "ren", "sa", "tor", "vel", "an", "bri", "cho", "dun", "el",
       "fa", "gor", "hal", "is", "jun", "kir", "lum", "mor", "nel", "ost", "pra", "qui"]
DESIGNS = [("syn30all", 30, 30), ("syn60all", 60, 60), ("syn60sub", 60, 20)]
SEEDS = range(1, 21)


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


def main():
    os.makedirs("data", exist_ok=True)
    rows = []
    for design, n, nlab in DESIGNS:
        for seed in SEEDS:
            rng = np.random.default_rng(1000 * n + 100 * nlab + seed)
            xy = points(rng, n)
            labs = names(rng, n)
            rng.shuffle(labs)
            chosen = set(rng.choice(n, size=nlab, replace=False))
            scen = f"{design}_s{seed:02d}"
            with open(f"data/{scen}.csv", "w", newline="") as fh:
                w = csv.writer(fh)
                w.writerow(["x", "y", "label", "lab"])
                for i in range(n):
                    w.writerow([f"{xy[i, 0]:.6f}", f"{xy[i, 1]:.6f}", labs[i], int(i in chosen)])
            rows.append([scen, design, seed, n, nlab, 0, "", "", "", ""])
    with open("data/manifest_synthetic.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["scenario", "design", "seed", "n", "nlab", "fit", "fa", "fb", "fx0", "fx1"])
        w.writerows(rows)
    print(len(rows), "synthetic scenarios")


if __name__ == "__main__":
    main()
