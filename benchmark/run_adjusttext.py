"""Label-placement benchmark, adjustText side (Python, matplotlib).

Each scenario is drawn on a figure with exactly the plot region and axis scales of the
Stata graph (read from out/stata/geometry.csv), so all methods see the same geometry.
adjustText runs with its defaults except for the stopping rule, and is told about every data point.
With neither time_lim nor iter_lim set, adjust_text() stops after 1 second of wall-clock time, so its
result depends on machine speed and load and differs from run to run. Here it runs a fixed number
of iterations (ITER_LIM, or the first argument) with no time limit, so two runs give the same positions.
Writes out/adjusttext/results.csv (one row per label) and timing.csv (seconds and iterations).
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
from common import manifest, data, geometry, FONT, LABEL_PT, MARKER_PT

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


def main(iter_lim):
    print(f"adjustText {adjustText.__version__}: iter_lim={iter_lim}, time_lim=None")
    counter = StepCount()
    lg = logging.getLogger("adjustText")
    lg.setLevel(logging.DEBUG)
    lg.addHandler(counter)
    lg.propagate = False
    os.makedirs("out/adjusttext", exist_ok=True)
    lab_rows, time_rows = [], []
    for m in manifest():
        scen = m["scenario"]
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
        ax.scatter(xs, ys, s=MARKER_PT ** 2, color=(11 / 255, 93 / 255, 122 / 255, 0.7), edgecolor="white", lw=0.4, zorder=3)
        lab = [r for r in d if r["lab"]]
        texts = [ax.text(r["x"], r["y"], r["label"], fontsize=LABEL_PT, family=FONT) for r in lab]
        counter.steps = None
        t0 = time.perf_counter()
        adjust_text(texts, x=xs, y=ys, ax=ax, iter_lim=iter_lim, time_lim=None,
                    arrowprops=dict(arrowstyle="-", color="0.6", lw=0.5))
        secs = time.perf_counter() - t0
        rend = fig.canvas.get_renderer()
        for r, t in zip(lab, texts):
            b = t.get_window_extent(rend)
            lab_rows.append([scen, r["label"], b.x0, b.y0, b.x1, b.y1])
        time_rows.append([scen, secs, counter.steps])
        if m["seed"] in ("0", "1"):
            fig.savefig(f"out/adjusttext/{scen}.png", dpi=200, facecolor="white")
        plt.close(fig)
    with open("out/adjusttext/results.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["scenario", "label", "x0", "y0", "x1", "y1"])
        w.writerows(lab_rows)
    with open("out/adjusttext/timing.csv", "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["scenario", "seconds", "iterations"])
        w.writerows(time_rows)
    print(len(time_rows), "scenarios")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else ITER_LIM)
