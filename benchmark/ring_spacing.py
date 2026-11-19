"""Ring spacings below the tuning grid.

The tuned ring spacing, 0.4 label heights, is the smallest value tune.py tried (0.4, 0.5, 0.6, 0.9 and
1.2). This script draws the 30 tuning graphs (synthetic seeds 101 to 110, never the test seeds) with the
ring spacing at 0.2, 0.3 and 0.4 label heights and every other tuned setting kept, and scores them with
tune.py's rule (the current measuring rule and gpolish's Open Sans width table). It reports only:
src/gpolish.ado and its defaults are unchanged, and no setting is chosen from it.
Writes results/ring_spacing.md.  Run from the benchmark folder after make_synthetic.py:
    python ring_spacing.py [stata executable]
"""
import os
import statistics as st
import sys
import tune

TUNED = (9, 0.4, 0.05, 0.005, 0.4, 3)
STEPS = [0.2, 0.3, 0.4]


def main():
    rows = []
    for s in STEPS:
        parms = (TUNED[0], s) + TUNED[2:]
        tag = "ring_s" + str(s)
        if not os.path.exists(f"out/tune/{tag}/geometry_gpolish.csv"):
            tune.run(tag, parms)
        res = tune.score_dir(tag)
        ds = sorted(res)
        rows.append((s, {d: res[d][0] for d in ds}, st.mean(res[d][0] for d in ds),
                     st.mean(res[d][1] for d in ds), st.mean(res[d][2] for d in ds)))
    ds = sorted(rows[0][1])
    out = ["# Ring spacings below the tuning grid", "",
           "Written by `ring_spacing.py`. Tuning scenarios only (synthetic seeds 101 to 110 of the three designs, "
           "30 graphs), scored with the current measuring rule and gpolish's Open Sans width table. Every other "
           "tuned setting is kept: " + str(TUNED) + ". These runs report; no setting was chosen from them.", "",
           "| Ring spacing (label heights) | " + " | ".join(f"Clean and near, {d}" for d in ds)
           + " | Clean and near, mean | Clean, mean | Mean distance (em) |", "|---|" + "---|" * (len(ds) + 3)]
    for s, per, near, clean, dist in rows:
        out.append(f"| {s:g}{' (tuned)' if s == TUNED[1] else ''} | " + " | ".join(f"{per[d]:.3f}" for d in ds)
                   + f" | {near:.3f} | {clean:.3f} | {dist:.2f} |")
    out.append("")
    open("results/ring_spacing.md", "w").write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        tune.STATA = sys.argv[1]
    main()
