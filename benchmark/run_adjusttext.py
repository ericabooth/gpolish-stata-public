"""Label-placement benchmark, adjustText side (Python, matplotlib).

Each scenario is drawn on a figure with exactly the plot region and axis scales of the Stata graph
(read from out/stata/geometry_default_<set>.csv), so all methods see the same geometry.
adjustText runs with its defaults except for the stopping rule, and is told about every data point.
With neither time_lim nor iter_lim set, adjust_text() stops after 1 second of wall-clock time, so its
result depends on machine speed and load and differs from run to run. Here it runs a fixed number
of iterations (ITER_LIM, or the first argument) with no time limit, so two runs give the same positions.
Writes, per scenario set, out/adjusttext/results_<set>.csv (one row per label: the box adjustText
worked with, the text's anchor and alignment (adjustText centres each text on its anchor) and, when
adjustText drew one, its leader line, all in points with y up) and timing_<set>.csv (seconds and
iterations). score.py measures each box from the anchor with the same rule as the other methods; the
box adjustText worked with comes from this 72 dpi figure, whose text extents are rounded to whole
pixels. A run limited by BENCH_SCENARIOS keeps the rows of the set's other scenarios.
BENCH_LINEPTS=1 also gives adjust_text() the fitted line as extra points every 4 points along it, so its
labels also avoid the line (a further run, see extra.py).
Run from the benchmark folder after run_stata.do:  python run_adjusttext.py [iterations]
"""
import csv
import logging
import os
import re
import sys
import time
import adjustText
import matplotlib.pyplot as plt
from adjustText import adjust_text
from common import manifest, data, geometry, methods_for, set_order, FONT

ITER_LIM = 100


class StepCount(logging.Handler):
    """Reads the iteration count that adjust_text() reports at debug level."""

    def __init__(self):
        super().__init__(logging.DEBUG)
        self.steps = None

    def emit(self, rec):
        m = re.match(r"Adjustment took (\d+) iterations", rec.getMessage())
        if m:
            self.steps = int(m.group(1))


def leader(p):
    """End points, in points (y up), of an arrow adjustText drew; the figure is at 72 dpi."""
    ap = getattr(p, "arrow_patch", p)
    path, _ = ap._get_path_in_displaycoord()
    if isinstance(path, list):
        path = path[0]
    v = path.vertices
    return ap, (v[0][0], v[0][1], v[-1][0], v[-1][1])


def merge_write(path, header, rows, scens, order):
    """Writes rows, keeping the rows of scenarios not run this time, in manifest order."""
    old = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            old = [r for r in csv.reader(fh)][1:]
        old = [r for r in old if r[0] not in scens]
    allrows = sorted(old + [["" if v is None else str(v) for v in r] for r in rows],
                     key=lambda r: order.get(r[0], len(order)))
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(allrows)


def main(iter_lim):
    print(f"adjustText {adjustText.__version__}: iter_lim={iter_lim}, time_lim=None")
    counter = StepCount()
    lg = logging.getLogger("adjustText")
    lg.setLevel(logging.DEBUG)
    lg.addHandler(counter)
    lg.propagate = False
    os.makedirs("out/adjusttext", exist_ok=True)
    by_set = {}
    for m in manifest():
        if "adjusttext" in methods_for(m["set"]):
            by_set.setdefault(m["set"], []).append(m)
    for set_name, mans in by_set.items():
        lab_rows, time_rows = [], []
        for m in mans:
            scen = m["scenario"]
            lpt, mpt = float(m["label_pt"]), float(m["marker_pt"])
            g = geometry(scen)
            d = data(scen)
            W, H = g["W"], g["H"]
            fig = plt.figure(figsize=(W / 72, H / 72), dpi=72)
            ax = fig.add_axes([g["px0"] / W, g["py0"] / H, (g["px1"] - g["px0"]) / W, (g["py1"] - g["py0"]) / H])
            ax.set_xlim((g["px0"] - g["xA"]) / g["xB"], (g["px1"] - g["xA"]) / g["xB"])
            ax.set_ylim((g["py0"] - g["yA"]) / g["yB"], (g["py1"] - g["yA"]) / g["yB"])
            xs = [r["x"] for r in d]
            ys = [r["y"] for r in d]
            if m["fit"] == "1":
                fa, fb, x0, x1 = (float(m[k]) for k in ("fa", "fb", "fx0", "fx1"))
                ax.plot([x0, x1], [fa + fb * x0, fa + fb * x1], color="0.55", lw=1)
            ax.scatter(xs, ys, s=mpt ** 2, color=(11 / 255, 93 / 255, 122 / 255, 0.7), edgecolor="white", lw=0.4, zorder=3)
            lab = [r for r in d if r["lab"]]
            ox, oy = list(xs), list(ys)
            if m["fit"] == "1" and os.environ.get("BENCH_LINEPTS"):
                # the fitted line, sampled every 4 pt (as gpolish samples lines), as extra points to avoid
                X0, X1 = g["xA"] + g["xB"] * x0, g["xA"] + g["xB"] * x1
                Y0, Y1 = g["yA"] + g["yB"] * (fa + fb * x0), g["yA"] + g["yB"] * (fa + fb * x1)
                k = int(((X1 - X0) ** 2 + (Y1 - Y0) ** 2) ** 0.5 // 4) + 1
                for j in range(k + 1):
                    xv = x0 + (x1 - x0) * j / k
                    ox.append(xv)
                    oy.append(fa + fb * xv)
            texts = [ax.text(r["x"], r["y"], r["label"], fontsize=lpt, family=FONT) for r in lab]
            counter.steps = None
            t0 = time.perf_counter()
            _, patches = adjust_text(texts, x=ox, y=oy, ax=ax, iter_lim=iter_lim, time_lim=None,
                                     arrowprops=dict(arrowstyle="-", color="0.6", lw=0.5))
            secs = time.perf_counter() - t0
            fig.canvas.draw()
            rend = fig.canvas.get_renderer()
            lead = {}
            for p in patches:
                ap, seg = leader(p)
                lead[id(ap.patchA)] = seg
            for r, t in zip(lab, texts):
                b = t.get_window_extent(rend)
                tx, ty = ax.transData.transform(t.get_position())
                seg = lead.get(id(t), ("", "", "", ""))
                lab_rows.append([scen, r["label"], b.x0, b.y0, b.x1, b.y1, tx, ty, t.get_ha(), t.get_va(), *seg])
            time_rows.append([scen, secs, counter.steps])
            # images are kept for the main set's real-data scenarios and seed 1 at 200 dpi, or for
            # every scenario run at BENCH_PNG_DPI when it is set (for audit_ink.py)
            png_dpi = os.environ.get("BENCH_PNG_DPI", "")
            if png_dpi or (set_name == "main" and m["seed"] in ("0", "1")):
                fig.savefig(f"out/adjusttext/{scen}.png", dpi=float(png_dpi or 200), facecolor="white")
            plt.close(fig)
        scens = {m["scenario"] for m in mans}
        merge_write(f"out/adjusttext/results_{set_name}.csv",
                    ["scenario", "label", "x0", "y0", "x1", "y1", "tx", "ty", "ha", "va", "lx0", "ly0", "lx1", "ly1"], lab_rows, scens,
                    set_order(set_name))
        if os.environ.get("BENCH_PNG_DPI", ""):
            continue      # its seconds include saving larger images, so they are not kept
        merge_write(f"out/adjusttext/timing_{set_name}.csv", ["scenario", "seconds", "iterations"], time_rows, scens,
                    set_order(set_name))
        print(set_name, len(time_rows), "scenarios")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else ITER_LIM)
