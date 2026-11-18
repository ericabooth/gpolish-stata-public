"""Shared helpers: scenario list, Stata plot geometry, and one text-measuring rule."""
import csv
import functools
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

FONT = "Open Sans"
LABEL_PT = 8.6
MARKER_PT = 6.0          # marker diameter, points


def manifest():
    rows = []
    for f in ("data/manifest_synthetic.csv", "data/manifest_real.csv"):
        with open(f) as fh:
            rows += list(csv.DictReader(fh))
    return rows


def data(scen):
    with open(f"data/{scen}.csv", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    for r in rows:
        r["x"] = float(r["x"])
        r["y"] = float(r["y"])
        r["lab"] = int(r["lab"])
    return rows


@functools.lru_cache(maxsize=None)
def geometry_table():
    import glob
    out = {}
    for f in sorted(glob.glob("out/stata/geometry_*.csv")):
        with open(f) as fh:
            for r in csv.DictReader(fh):
                out[(r["scenario"], r["method"])] = {k: (float(v) if k not in ("scenario", "method") else v)
                                                     for k, v in r.items()}
    return out


def geometry(scen, method="default"):
    return geometry_table()[(scen, method)]


class Measurer:
    """Measures text boxes in points (y up) with matplotlib, the same way for every method."""

    def __init__(self, W, H):
        self.fig = plt.figure(figsize=(W / 72, H / 72), dpi=72)
        self.r = self.fig.canvas.get_renderer()
        self.t = self.fig.text(0, 0, "", fontsize=LABEL_PT, family=FONT)
        self.W, self.H = W, H

    def box(self, s, x, y, ha="left", va="baseline", size=LABEL_PT):
        self.t.set_text(s)
        self.t.set_fontsize(size)
        self.t.set_ha(ha)
        self.t.set_va(va)
        self.t.set_position((x / self.W, y / self.H))
        b = self.t.get_window_extent(self.r)
        return (b.x0, b.y0, b.x1, b.y1)

    def close(self):
        plt.close(self.fig)
