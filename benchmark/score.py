"""Score every method's labels with one rule.

Boxes are measured in points (y up) with matplotlib's text extent for Open Sans 8.6 pt.
For Stata methods the label position and alignment come from the exported SVG; for
adjustText from the figure; for ggrepel from the label centres read back from grid.
Per label it records: overlap with other labels, with any data marker (a box closer than
MARKER_PT/2 - 0.25 = 2.75 pt to a data point),
with the fitted line, whether it leaves the plot region, its distance from its own point,
and whether another point is closer to it than its own point (ambiguous). A label is *clean* when it
touches no other label, marker or line and stays in the plot; *clean and near* also requires it to be
within 3 ems of its own point.
A method whose output is missing (for example labrepel when it is not installed) is left out.
Writes results/labels.csv and results/graphs.csv.  python score.py [--check scen ...]
With --check, nothing is written to results/; instead out/check_<scen>.png shows each method's
rendered image with the measured boxes drawn over it, so the two can be compared.
"""
import csv
import html
import math
import os
import re
import sys
from common import manifest, data, geometry, Measurer, LABEL_PT, MARKER_PT

STATA = ["default", "gpolish", "labrepel"]
ALL = STATA + ["adjusttext", "ggrepel"]
TEXT_RE = re.compile(r'<text x="([-\d.]+)" y="([-\d.]+)" style="[^"]*font-size:([\d.]+)px[^"]*"( text-anchor="(\w+)")?>([^<]*)</text>')
HA = {None: "left", "start": "left", "middle": "center", "end": "right"}
# A label touches a marker when its box comes closer than this to a data point: a 6 pt marker's
# radius less a 0.25 pt tolerance. Stata draws msize(6pt) as a disc of radius 3.24 pt whose outer
# 0.5 pt is a white outline, so its coloured part ends at about 2.74 pt. marker_sensitivity.py
# rescores with other values.
MARKER_HIT = MARKER_PT / 2 - 0.25


def read_csv(path):
    with open(path, encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def stata_boxes(scen, method, labels, meas, H):
    svg = open(f"out/stata/{scen}__{method}.svg", encoding="utf-8").read()
    vb = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', svg)
    k = float(vb.group(1)) / meas.W
    out = {}
    for m in TEXT_RE.finditer(svg):
        s = html.unescape(m.group(6))
        if s in labels and s not in out:
            x, y, fs = float(m.group(1)) / k, H - float(m.group(2)) / k, float(m.group(3)) / k
            out[s] = meas.box(s, x, y, ha=HA[m.group(5)], va="baseline", size=fs)
    return out


def ov(a, b):
    w = min(a[2], b[2]) - max(a[0], b[0])
    h = min(a[3], b[3]) - max(a[1], b[1])
    return w * h if w > 0 and h > 0 else 0.0


def dist_box(px, py, b):
    dx = max(b[0] - px, 0, px - b[2])
    dy = max(b[1] - py, 0, py - b[3])
    return math.hypot(dx, dy)


def seg_hits_box(p, q, b):
    """Liang-Barsky clip of segment pq against box b."""
    x0, y0 = p
    dx, dy = q[0] - x0, q[1] - y0
    t0, t1 = 0.0, 1.0
    for pp, qq in ((-dx, x0 - b[0]), (dx, b[2] - x0), (-dy, y0 - b[1]), (dy, b[3] - y0)):
        if pp == 0:
            if qq < 0:
                return False
        else:
            t = qq / pp
            if pp < 0:
                t0 = max(t0, t)
            else:
                t1 = min(t1, t)
            if t0 > t1:
                return False
    return True


def score_graph(boxes, pts, idx, line, plot, near_em=3.0, marker_hit=MARKER_HIT):
    rows = []
    names = list(boxes)
    for i, s in enumerate(names):
        b = boxes[s]
        area = (b[2] - b[0]) * (b[3] - b[1])
        o_area = 0.0
        o_n = 0
        for j, t in enumerate(names):
            if j != i:
                a = ov(b, boxes[t])
                if a > 0.25:
                    o_area += a
                    o_n += 1
        on_mark = sum(1 for (px, py) in pts if dist_box(px, py, b) < marker_hit)
        on_line = bool(line) and seg_hits_box(line[0], line[1], (b[0] + 0.5, b[1] + 0.5, b[2] - 0.5, b[3] - 0.5))
        outside = b[0] < plot[0] - 0.5 or b[1] < plot[1] - 0.5 or b[2] > plot[2] + 0.5 or b[3] > plot[3] + 0.5
        ax, ay = pts[idx[s]]
        d_own = dist_box(ax, ay, b)
        d_other = min((dist_box(px, py, b) for k, (px, py) in enumerate(pts) if k != idx[s]), default=1e9)
        rows.append(dict(label=s, area=area, overlap_area=o_area, overlap_n=o_n, on_marker=on_mark,
                         on_line=int(on_line), outside=int(outside), dist_em=d_own / LABEL_PT,
                         ambiguous=int(d_other < d_own - 1.0),
                         clean=int(o_n == 0 and on_mark == 0 and not on_line and not outside),
                         clean_near=int(o_n == 0 and on_mark == 0 and not on_line and not outside
                                        and d_own / LABEL_PT <= near_em)))
    return rows


def main(check, marker_hit=MARKER_HIT, write=True):
    os.makedirs("results", exist_ok=True)
    at, gg, times = {}, {}, {}
    if os.path.exists("out/adjusttext/results.csv"):
        for r in read_csv("out/adjusttext/results.csv"):
            at.setdefault(r["scenario"], {})[r["label"]] = tuple(float(r[k]) for k in ("x0", "y0", "x1", "y1"))
    if os.path.exists("out/ggrepel/results.csv"):
        for r in read_csv("out/ggrepel/results.csv"):
            gg.setdefault(r["scenario"], []).append(r)
    import glob
    for f in sorted(glob.glob("out/stata/geometry_*.csv")):
        for r in read_csv(f):
            times[(r["scenario"], r["method"])] = float(r["seconds"])
    for meth, f in (("adjusttext", "out/adjusttext/timing.csv"), ("ggrepel", "out/ggrepel/timing.csv")):
        if os.path.exists(f):
            for r in read_csv(f):
                times[(r["scenario"], meth)] = float(r["seconds"])
    missing = [m for m in ALL if not any(k[1] == m for k in times)]
    if missing and write:
        print(f"note: no output for {', '.join(missing)}; left out")
    label_rows, graph_rows = [], []
    for m in manifest():
        scen = m["scenario"]
        if check and scen not in check:
            continue
        d = data(scen)
        labels = {r["label"] for r in d if r["lab"]}
        # the default method's geometry (the one adjustText and ggrepel were drawn on), or, when
        # only some Stata methods were run, the first one present
        g0 = next((geometry(scen, mm) for mm in STATA if (scen, mm) in times), None)
        if g0 is None:
            continue
        meas = Measurer(g0["W"], g0["H"])
        per = {}
        for meth in ALL:
            if (scen, meth) not in times:
                continue
            g = geometry(scen, meth) if meth in STATA else g0
            pts = [(g["xA"] + g["xB"] * r["x"], g["yA"] + g["yB"] * r["y"]) for r in d]
            idx = {r["label"]: i for i, r in enumerate(d)}
            line = None
            if m["fit"] == "1":
                fa, fb, x0, x1 = (float(m[k]) for k in ("fa", "fb", "fx0", "fx1"))
                line = [(g["xA"] + g["xB"] * x, g["yA"] + g["yB"] * (fa + fb * x)) for x in (x0, x1)]
            plot = (g["px0"], g["py0"], g["px1"], g["py1"])
            if meth in STATA:
                boxes = stata_boxes(scen, meth, labels, meas, g["H"])
            elif meth == "adjusttext":
                boxes = {s: b for s, b in at.get(scen, {}).items() if s in labels}
            else:
                boxes = {}
                for r in gg.get(scen, []):
                    if r["label"] in labels:
                        boxes[r["label"]] = meas.box(r["label"], float(r["cx"]), float(r["cy"]), ha="center", va="center")
            rows = score_graph(boxes, pts, idx, line, plot, marker_hit=marker_hit)
            per[meth] = (boxes, pts, line, plot)
            for r in rows:
                label_rows.append(dict(scenario=scen, design=m["design"], method=meth, **r))
            n = len(labels)
            tot_area = sum(r["area"] for r in rows) or 1
            graph_rows.append(dict(
                scenario=scen, design=m["design"], seed=m["seed"], method=meth, n_points=len(d), n_labels=n,
                drawn=len(rows), clean_share=sum(r["clean"] for r in rows) / n,
                clean_near_share=sum(r["clean_near"] for r in rows) / n,
                overlap_pairs=sum(r["overlap_n"] for r in rows) / 2,
                overlap_area_share=sum(r["overlap_area"] for r in rows) / 2 / tot_area,
                on_marker_share=sum(r["on_marker"] > 0 for r in rows) / n,
                on_line_share=sum(r["on_line"] for r in rows) / n,
                outside_share=sum(r["outside"] for r in rows) / n,
                ambiguous_share=sum(r["ambiguous"] for r in rows) / n,
                mean_dist_em=sum(r["dist_em"] for r in rows) / max(len(rows), 1),
                seconds=times.get((scen, meth), float("nan"))))
        meas.close()
        if check:
            draw_check(scen, per)
    if not graph_rows:
        sys.exit("no graphs to score: run the drawing steps first")
    if write and not check:
        for name, rows in (("labels", label_rows), ("graphs", graph_rows)):
            with open(f"results/{name}.csv", "w", newline="") as fh:
                w = csv.DictWriter(fh, fieldnames=list(rows[0]))
                w.writeheader()
                w.writerows(rows)
    if write:
        print(len(graph_rows), "graphs scored")
    return graph_rows


def rendered_png(scen, meth):
    """The image each method drew for this scenario (kept for real-data scenarios and seed 1)."""
    f = f"out/stata/{scen}__{meth}.png" if meth in STATA else f"out/{meth}/{scen}.png"
    return f if os.path.exists(f) else None


def draw_check(scen, per):
    """Each method's rendered image, with the measured boxes (red) and data points (blue rings) over it."""
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle
    fig, axes = plt.subplots(2, 3, figsize=(15, 7))
    meths = [m for m in ALL if m in per]
    for ax, meth in zip(axes.flat, meths):
        boxes, pts, line, plot = per[meth]
        g = geometry(scen, meth if meth in STATA else "default")
        png = rendered_png(scen, meth)
        if png:
            ax.imshow(plt.imread(png), extent=[0, g["W"], 0, g["H"]], interpolation="antialiased")
        ax.add_patch(Rectangle(plot[:2], plot[2] - plot[0], plot[3] - plot[1], fill=False, ec="0.7"))
        ax.scatter([p[0] for p in pts], [p[1] for p in pts], s=10, facecolor="none", edgecolor="tab:blue", lw=0.5)
        if line:
            ax.plot([line[0][0], line[1][0]], [line[0][1], line[1][1]], color="0.5", lw=0.5)
        for s, b in boxes.items():
            ax.add_patch(Rectangle(b[:2], b[2] - b[0], b[3] - b[1], fill=False, ec="tab:red", lw=0.6))
            if not png:
                ax.text(b[0], b[1], s, fontsize=5)
        ax.set_title(meth if png else f"{meth} (no rendered image kept for this scenario)", fontsize=9)
        ax.set_xlim(0, g["W"])
        ax.set_ylim(0, g["H"])
        ax.set_aspect("equal")
    for ax in list(axes.flat)[len(meths):]:
        ax.axis("off")
    fig.tight_layout()
    fig.savefig(f"out/check_{scen}.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[1:] if a[:1] == ["--check"] else [])
