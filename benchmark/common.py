"""Shared helpers: scenario sets, methods, Stata plot geometry, and one text-measuring rule."""
import csv
import functools
import glob
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

FONT = "Open Sans"
LABEL_PT = 8.6           # label font size, points (every set except "fontmark")
MARKER_PT = 6.0          # marker diameter, points (every set except "fontmark")

# Scenario sets. Each has its own manifest in data/ and its own list of methods.
#   main      the headline benchmark: 4 real-data scenarios and 3 synthetic designs x 20 test seeds
#   perm      the 4 real-data scenarios with their rows in 10 random orders (permutation seeds 1 to 10)
#   scale     synthetic scatterplots with 150 and 300 points, all labelled, 5 seeds each
#   fontmark  the 60-of-60 synthetic design (seeds 1 to 10) at other font and marker sizes
#   tuning    synthetic tuning seeds 101 to 110 (tune.py, tune_others.py); run only when BENCH_SETS names it
#   realhold  held-out real-data scenarios (census, hsng, states), and rhperm their 10 row orders; written
#             only for extra.py (BENCH_EXTRA=1)
SETS = ["main", "perm", "scale", "fontmark", "holdout", "rule", "realhold", "rhperm"]
ALL_METHODS = ["default", "labrepel", "gpolish", "gpolish060", "adjusttext", "ggrepel", "ggrepel_inf"]
# adjustText and informed ggrepel at the settings tune_others.py chose on the tuning seeds; their
# outputs exist only in extra.py's "tuned" and "realhold" working copies
TUNED = ["adjusttext_tuned", "ggrepel_tuned"]
SET_METHODS = {
    "main": ALL_METHODS,
    "perm": ALL_METHODS,
    "scale": ["default", "gpolish", "adjusttext", "ggrepel", "ggrepel_inf"],
    "fontmark": ["default", "gpolish", "adjusttext", "ggrepel", "ggrepel_inf"],
    "holdout": ALL_METHODS,
    "rule": ALL_METHODS,
    "realhold": ALL_METHODS + TUNED,
    "rhperm": ALL_METHODS + TUNED,
    "tuning": ["default", "adjusttext", "ggrepel", "ggrepel_inf"] + TUNED,
}
SET_METHODS["main"] = ALL_METHODS + TUNED
SET_METHODS["perm"] = ALL_METHODS + TUNED
STATA = ["default", "gpolish", "gpolish060", "labrepel"]
MANIFEST_FIELDS = ["scenario", "set", "design", "seed", "n", "nlab", "fit", "fa", "fb", "fx0", "fx1",
                   "label_pt", "marker_pt"]


def manifest_files():
    """The manifest of every scenario set, in a fixed order."""
    return [("main", "data/manifest_real.csv"), ("main", "data/manifest_synthetic.csv"),
            ("perm", "data/manifest_perm.csv"), ("scale", "data/manifest_scale.csv"),
            ("fontmark", "data/manifest_fontmark.csv"),
            ("holdout", "data/manifest_holdout.csv"), ("rule", "data/manifest_rule.csv"),
            ("realhold", "data/manifest_realhold.csv"), ("rhperm", "data/manifest_rhperm.csv"),
            ("tuning", "data/manifest_tuning.csv")]


def manifest():
    """Every scenario of the sets named in BENCH_SETS (default: all), or only those named in BENCH_SCENARIOS."""
    sets = os.environ.get("BENCH_SETS", "").split() or SETS
    rows = []
    for s, f in manifest_files():
        if s in sets and os.path.exists(f):
            with open(f) as fh:
                rows += list(csv.DictReader(fh))
    only = os.environ.get("BENCH_SCENARIOS", "").split()
    if only:
        rows = [r for r in rows if r["scenario"] in only]
    return rows


def set_order(set_name):
    """Every scenario of a set in manifest order, ignoring BENCH_SCENARIOS (to keep merged files in order)."""
    out = []
    for s, f in manifest_files():
        if s == set_name and os.path.exists(f):
            with open(f) as fh:
                out += [r["scenario"] for r in csv.DictReader(fh)]
    return {scen: i for i, scen in enumerate(out)}


def methods_for(set_name):
    """The methods run on a set, limited by BENCH_METHODS when it is given."""
    only = os.environ.get("BENCH_METHODS", "").split()
    return [m for m in SET_METHODS[set_name] if not only or m in only]


def data(scen):
    with open(f"data/{scen}.csv", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    for r in rows:
        r["x"] = float(r["x"])
        r["y"] = float(r["y"])
        r["lab"] = int(r["lab"])
    return rows


@functools.lru_cache(maxsize=None)
def method_geometry(method):
    """Plot geometry of one Stata method's drawings, from out/stata/geometry_<method>_<set>.csv.
    Only that method's files are read, so another method's run still writing its file does not matter."""
    out = {}
    for f in sorted(glob.glob(f"out/stata/geometry_{method}_*.csv")):
        with open(f) as fh:
            for r in csv.DictReader(fh):
                out[(r["scenario"], r["method"])] = {
                    k: (v if k in ("scenario", "method", "font") else float(v)) for k, v in r.items()}
    return out


def geometry_table():
    """Plot geometry of every Stata drawing."""
    out = {}
    for m in STATA:
        out.update(method_geometry(m))
    return out


def geometry(scen, method="default"):
    return method_geometry(method)[(scen, method)]


class Measurer:
    """Measures text boxes in points (y up) with matplotlib, the same way for every method.
    The text is laid out at K * 72 dpi and the extent scaled back to points. At 72 dpi matplotlib
    rounds text extents to whole pixels (whole points), which made boxes about 6 percent wider and
    0.4 points taller than the drawn text; at 40 * 72 dpi the rounding is 0.025 points."""

    K = 40

    def __init__(self, W, H, size=LABEL_PT):
        # a one-inch figure is enough: the text is laid out at its centre and the box moved to (x, y)
        self.fig = plt.figure(figsize=(1, 1), dpi=72 * self.K)
        self.r = self.fig.canvas.get_renderer()
        self.t = self.fig.text(0.5, 0.5, "", fontsize=size, family=FONT)
        self.o = 0.5 * 72 * self.K
        self.W, self.H, self.size = W, H, size

    def box(self, s, x, y, ha="left", va="baseline", size=None):
        self.t.set_text(s)
        self.t.set_fontsize(size or self.size)
        self.t.set_ha(ha)
        self.t.set_va(va)
        b = self.t.get_window_extent(self.r)
        k, o = self.K, self.o
        return (x + (b.x0 - o) / k, y + (b.y0 - o) / k, x + (b.x1 - o) / k, y + (b.y1 - o) / k)

    def m_ascent(self, size=None):
        """Height of the ink of "M" above the baseline, in points (grid's string height for one line)."""
        from matplotlib.textpath import TextPath
        from matplotlib.font_manager import FontProperties
        tp = TextPath((0, 0), "M", size=size or self.size, prop=FontProperties(family=FONT))
        return float(tp.get_extents().y1)

    def close(self):
        plt.close(self.fig)
