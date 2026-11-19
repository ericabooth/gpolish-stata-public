"""Score every method's labels with one rule.

Two stages.
1. Collect (needs out/): every label box is measured in points (y up) with matplotlib's text extent
   for Open Sans at the scenario's font size (common.Measurer, laid out at 40 x 72 dpi so that the
   extent is not rounded to whole points), placed where the method anchored the text. For Stata
   methods the label position and alignment come from the exported SVG and the leader lines from
   out/stata/leaders_*.csv; for adjustText the text anchors, alignment and leader lines come from the
   finished figure; for ggrepel the label centres, baselines and leader segments come from the drawn
   grid objects. Writes results/positions.csv (each method's label boxes and
   leader segments, rounded to 0.001 pt), results/geometry.csv (plot geometry, fit line, font and
   marker size, seconds and, for adjustText and ggrepel, iterations per graph) and results/points.csv (the data points).
2. Score (needs only those three files): writes results/labels.csv and results/graphs.csv.
`python score.py` runs both stages. `python score.py --rescore` runs stage 2 alone, so the scores can be
checked or rescored with another rule without Stata, R or adjustText; it gives the same labels.csv
and graphs.csv byte for byte.

Per label it records: overlap with other labels; markers touched (a box closer than marker/2 - 0.25 pt,
2.75 pt for 6 pt markers, to a data point), counting its own point and not counting it; whether it
crosses the fitted line; whether it leaves the plot region; its distance from its own point; whether
another point is closer to it than its own point (ambiguous); and its leader line, if the method drew
one: the part of the drawn segment outside the label's own box, counted as a leader when at least 1 pt
long, and whether it crosses another label's box, comes within the marker distance of another point,
or crosses another leader. A label is *clean* when it touches no other label, marker or line and stays
in the plot; *clean and near* also requires it to be within 3 ems of its own point; *clean except own
marker* is clean with the label's own marker not counted. Leader crossings do not enter these three.
A method whose output is missing (for example labrepel when it is not installed) is left out.
`python score.py --check scen ...` writes nothing to results/; instead out/check_<scen>.png shows each
method's rendered image with the measured boxes (red) and leader segments (green) drawn over it.
"""
import csv
import glob
import html
import math
import os
import re
import sys
from common import (manifest, data, geometry, geometry_table, Measurer, methods_for, LABEL_PT, MARKER_PT,
                    STATA, ALL_METHODS)

ALL = ALL_METHODS
TEXT_RE = re.compile(r'<text x="([-\d.]+)" y="([-\d.]+)" style="[^"]*font-size:([\d.]+)px[^"]*"( text-anchor="(\w+)")?>([^<]*)</text>')
HA = {None: "left", "start": "left", "middle": "center", "end": "right"}
# A label touches a marker when its box comes closer than this to a data point: the marker's radius
# less a 0.25 pt tolerance. Stata draws msize(6pt) as a disc of radius 3.24 pt whose outer 0.5 pt is a
# white outline, so its coloured part ends at about 2.74 pt. marker_sensitivity.py rescores with other values.
MARKER_TOL = 0.25
MARKER_HIT = MARKER_PT / 2 - MARKER_TOL
LEADER_MIN = 1.0          # a drawn leader shorter than this (outside its own label box) is not counted
NEAR_EM = 3.0
GEO_FIELDS = ["set", "scenario", "design", "seed", "method", "n_points", "n_labels", "W", "H", "px0", "py0",
              "px1", "py1", "xA", "xB", "yA", "yB", "fit", "fa", "fb", "fx0", "fx1", "label_pt", "marker_pt",
              "seconds", "iterations", "iterations_drawn", "stop", "rc", "font"]
POS_FIELDS = ["set", "scenario", "method", "label", "x0", "y0", "x1", "y1", "lx0", "ly0", "lx1", "ly1"]


def read_csv(path):
    with open(path, encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


# ---------------------------------------------------------------- geometry helpers
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


def clip_range(p, q, b):
    """Liang-Barsky: the parameter range (t0, t1) of segment pq inside box b, or None."""
    x0, y0 = p
    dx, dy = q[0] - x0, q[1] - y0
    t0, t1 = 0.0, 1.0
    for pp, qq in ((-dx, x0 - b[0]), (dx, b[2] - x0), (-dy, y0 - b[1]), (dy, b[3] - y0)):
        if pp == 0:
            if qq < 0:
                return None
        else:
            t = qq / pp
            if pp < 0:
                t0 = max(t0, t)
            else:
                t1 = min(t1, t)
            if t0 > t1:
                return None
    return t0, t1


def seg_hits_box(p, q, b):
    return clip_range(p, q, b) is not None


def dist_seg(px, py, s):
    x0, y0, x1, y1 = s
    dx, dy = x1 - x0, y1 - y0
    L = dx * dx + dy * dy
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / L))
    return math.hypot(px - x0 - t * dx, py - y0 - t * dy)


def segs_cross(a, b):
    """True when two segments properly intersect (touching end points do not count)."""
    def orient(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    p1, p2, p3, p4 = (a[0], a[1]), (a[2], a[3]), (b[0], b[1]), (b[2], b[3])
    d1, d2 = orient(p3, p4, p1), orient(p3, p4, p2)
    d3, d4 = orient(p1, p2, p3), orient(p1, p2, p4)
    return ((d1 > 0 > d2) or (d1 < 0 < d2)) and ((d3 > 0 > d4) or (d3 < 0 < d4))


def visible_leader(seg, box, own):
    """The part of a drawn leader outside its own label box, on the side of its own point."""
    if seg is None:
        return None
    p, q = (seg[0], seg[1]), (seg[2], seg[3])
    r = clip_range(p, q, box)
    if r is not None:
        t0, t1 = r
        # keep the piece that holds the end nearer the label's own point
        if math.hypot(p[0] - own[0], p[1] - own[1]) <= math.hypot(q[0] - own[0], q[1] - own[1]):
            q = (p[0] + t0 * (q[0] - p[0]), p[1] + t0 * (q[1] - p[1]))
        else:
            p = (p[0] + t1 * (q[0] - p[0]), p[1] + t1 * (q[1] - p[1]))
    s = (p[0], p[1], q[0], q[1])
    return s if math.hypot(s[2] - s[0], s[3] - s[1]) >= LEADER_MIN else None


def score_graph(boxes, pts, idx, line, plot, near_em=NEAR_EM, marker_hit=MARKER_HIT, label_pt=LABEL_PT,
                leaders=None):
    """Per-label scores. boxes and leaders map label -> box / drawn segment (points, y up)."""
    leaders = leaders or {}
    names = list(boxes)
    vis = {s: visible_leader(leaders.get(s), boxes[s], pts[idx[s]]) for s in names}
    rows = []
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
        own = idx[s]
        hits = [k for k, (px, py) in enumerate(pts) if dist_box(px, py, b) < marker_hit]
        on_mark = len(hits)
        on_other = sum(1 for k in hits if k != own)
        on_line = bool(line) and seg_hits_box(line[0], line[1], (b[0] + 0.5, b[1] + 0.5, b[2] - 0.5, b[3] - 0.5))
        outside = b[0] < plot[0] - 0.5 or b[1] < plot[1] - 0.5 or b[2] > plot[2] + 0.5 or b[3] > plot[3] + 0.5
        ax, ay = pts[own]
        d_own = dist_box(ax, ay, b)
        d_other = min((dist_box(px, py, b) for k, (px, py) in enumerate(pts) if k != own), default=1e9)
        base = o_n == 0 and not on_line and not outside
        v = vis[s]
        lx_lab = lx_mark = lx_lead = 0
        if v:
            p, q = (v[0], v[1]), (v[2], v[3])
            lx_lab = sum(1 for t in names if t != s and
                         seg_hits_box(p, q, (boxes[t][0] + 0.5, boxes[t][1] + 0.5, boxes[t][2] - 0.5, boxes[t][3] - 0.5)))
            lx_mark = sum(1 for k, (px, py) in enumerate(pts) if k != own and dist_seg(px, py, v) < marker_hit)
            lx_lead = sum(1 for t in names if t != s and vis[t] and segs_cross(v, vis[t]))
        rows.append(dict(label=s, area=area, overlap_area=o_area, overlap_n=o_n, on_marker=on_mark,
                         on_marker_other=on_other, on_line=int(on_line), outside=int(outside),
                         dist_em=d_own / label_pt, ambiguous=int(d_other < d_own - 1.0),
                         clean=int(base and on_mark == 0),
                         clean_near=int(base and on_mark == 0 and d_own / label_pt <= near_em),
                         clean_xown=int(base and on_other == 0),
                         leader=int(v is not None),
                         leader_len=math.hypot(v[2] - v[0], v[3] - v[1]) if v else 0.0,
                         lead_x_label=lx_lab, lead_x_marker=lx_mark, lead_x_leader=lx_lead))
    return rows


# ---------------------------------------------------------------- stage 1: collect from out/
def method_outputs():
    """Timing and output tables of every method that has run."""
    times, at, gg, at_lead, iters = {}, {}, {}, {}, {}
    leads = {}
    for f in sorted(glob.glob("out/stata/leaders_*.csv")):
        meth = re.match(r"out/stata/leaders_(.+)_[a-z]+\.csv", f).group(1)
        for r in read_csv(f):
            leads.setdefault((r["scenario"], meth), {})[r["label"]] = tuple(float(r[k]) for k in ("x0", "y0", "x1", "y1"))
    for (scen, meth), g in geometry_table().items():
        times[(scen, meth)] = g["seconds"]
    for f in sorted(glob.glob("out/adjusttext/results_*.csv")):
        for r in read_csv(f):
            # the text anchor and alignment when the output has them, else adjustText's own box
            if r.get("tx", "") != "":
                at.setdefault(r["scenario"], {})[r["label"]] = ("anchor", float(r["tx"]), float(r["ty"]), r["ha"], r["va"])
            else:
                at.setdefault(r["scenario"], {})[r["label"]] = tuple(float(r[k]) for k in ("x0", "y0", "x1", "y1"))
            if r["lx0"] != "":
                at_lead.setdefault(r["scenario"], {})[r["label"]] = tuple(float(r[k]) for k in ("lx0", "ly0", "lx1", "ly1"))
    for meth in ("ggrepel", "ggrepel_inf"):
        for f in sorted(glob.glob(f"out/{meth}/results_*.csv")):
            for r in read_csv(f):
                gg.setdefault((r["scenario"], meth), []).append(r)
    for meth in ("adjusttext", "ggrepel", "ggrepel_inf"):
        for f in sorted(glob.glob(f"out/{meth}/timing_*.csv")):
            for r in read_csv(f):
                times[(r["scenario"], meth)] = float(r["seconds"])
                # adjustText: iterations run; ggrepel: iterations in the run read back and in the drawn
                # run, and why the run read back stopped
                iters[(r["scenario"], meth)] = (r.get("iterations_read") or r.get("iterations") or "",
                                                r.get("iterations", "") if "iterations_read" in r else "",
                                                r.get("stop", ""))
    return times, at, at_lead, gg, leads, iters


def ggrepel_box(meas, label, cx, cy, vjust=0.5, by=None, size=None):
    """The box of a ggrepel label, measured by the same baseline-anchored rule as the Stata labels.
    grid applies vjust to the string height, which it takes from the ascent of "M" (no descent), so
    the baseline is cy - vjust * that height. run_ggrepel.R writes this baseline (by); for output
    without it, the height is the ink ascent of "M" in the same font and size."""
    if by in (None, "", "NA"):
        by = cy - vjust * meas.m_ascent(size)
    return meas.box(label, cx, float(by), ha="center", va="baseline", size=size)


def collect(only=None):
    """Measures every method's labels. Returns geometry rows, position rows and point rows."""
    times, at, at_lead, gg, leads, iters = method_outputs()
    geo_rows, pos_rows, pt_rows = [], [], []
    for m in manifest():
        scen = m["scenario"]
        if only and scen not in only:
            continue
        d = data(scen)
        labels = {r["label"] for r in d if r["lab"]}
        lpt = float(m["label_pt"])
        meths = [mm for mm in methods_for(m["set"]) if (scen, mm) in times]
        # the default method's geometry (the one adjustText and ggrepel were drawn on), or, when
        # only some Stata methods were run, the first one present
        g0 = next((geometry(scen, mm) for mm in STATA if (scen, mm) in times), None)
        if g0 is None:
            continue
        for i, r in enumerate(d):
            pt_rows.append(dict(set=m["set"], scenario=scen, i=i, x=repr(r["x"]), y=repr(r["y"]), lab=r["lab"], label=r["label"]))
        meas = Measurer(g0["W"], g0["H"], lpt)
        for meth in meths:
            g = geometry(scen, meth) if meth in STATA else g0
            lead = {}
            if meth in STATA:
                boxes = stata_boxes(scen, meth, labels, meas, g["H"])
                for s, (x0, y0, x1, y1) in leads.get((scen, meth), {}).items():
                    lead[s] = (g["xA"] + g["xB"] * x0, g["yA"] + g["yB"] * y0, g["xA"] + g["xB"] * x1, g["yA"] + g["yB"] * y1)
            elif meth == "adjusttext":
                boxes = {s: (meas.box(s, b[1], b[2], ha=b[3], va=b[4]) if b[0] == "anchor" else b)
                         for s, b in at.get(scen, {}).items() if s in labels}
                lead = dict(at_lead.get(scen, {}))
            else:
                boxes = {}
                for r in gg.get((scen, meth), []):
                    if r["label"] in labels:
                        boxes[r["label"]] = ggrepel_box(meas, r["label"], float(r["cx"]), float(r["cy"]),
                                                          float(r.get("vjust") or 0.5), r.get("by"))
                        if r["lx0"] not in ("", "NA"):
                            lead[r["label"]] = tuple(float(r[k]) for k in ("lx0", "ly0", "lx1", "ly1"))
            geo_rows.append(dict(set=m["set"], scenario=scen, design=m["design"], seed=m["seed"], method=meth,
                                 n_points=len(d), n_labels=len(labels),
                                 **{k: repr(g[k]) for k in ("W", "H", "px0", "py0", "px1", "py1", "xA", "xB", "yA", "yB")},
                                 fit=m["fit"], fa=m["fa"], fb=m["fb"], fx0=m["fx0"], fx1=m["fx1"],
                                 label_pt=m["label_pt"], marker_pt=m["marker_pt"],
                                 seconds=repr(times[(scen, meth)]),
                                 iterations=iters.get((scen, meth), ("", "", ""))[0],
                                 iterations_drawn=iters.get((scen, meth), ("", "", ""))[1],
                                 stop=iters.get((scen, meth), ("", "", ""))[2], rc=int(g.get("rc", 0)) if meth in STATA else 0,
                                 font=g.get("font", "") if meth in STATA else ""))
            for s in sorted(boxes):
                b = boxes[s]
                l = lead.get(s)
                pos_rows.append(dict(set=m["set"], scenario=scen, method=meth, label=s,
                                     **{k: f"{v:.3f}" for k, v in zip(("x0", "y0", "x1", "y1"), b)},
                                     **({k: f"{v:.3f}" for k, v in zip(("lx0", "ly0", "lx1", "ly1"), l)} if l else
                                        {k: "" for k in ("lx0", "ly0", "lx1", "ly1")})))
        meas.close()
    return geo_rows, pos_rows, pt_rows


def write_rows(path, rows, fields=None):
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields or list(rows[0]), lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


# ---------------------------------------------------------------- stage 2: score from the archive
def load_archive():
    geo = read_csv("results/geometry.csv")
    pos, pts = {}, {}
    for r in read_csv("results/positions.csv"):
        pos.setdefault((r["scenario"], r["method"]), []).append(r)
    for r in read_csv("results/points.csv"):
        pts.setdefault(r["scenario"], []).append(r)
    return geo, pos, pts


def fmt(v):
    return f"{v:.4f}" if isinstance(v, float) else v


def score_all(geo, pos, pts, marker_hit=None, sets=None):
    """Scores every graph in the archive. marker_hit overrides the marker distance (points)."""
    label_rows, graph_rows = [], []
    for g in geo:
        if sets and g["set"] not in sets:
            continue
        scen, meth = g["scenario"], g["method"]
        G = {k: float(g[k]) for k in ("W", "H", "px0", "py0", "px1", "py1", "xA", "xB", "yA", "yB")}
        lpt, mpt = float(g["label_pt"]), float(g["marker_pt"])
        mh = marker_hit if marker_hit is not None else mpt / 2 - MARKER_TOL
        prow = pts[scen]
        P = [(G["xA"] + G["xB"] * float(r["x"]), G["yA"] + G["yB"] * float(r["y"])) for r in prow]
        idx = {r["label"]: i for i, r in enumerate(prow)}
        line = None
        if g["fit"] == "1":
            fa, fb, x0, x1 = (float(g[k]) for k in ("fa", "fb", "fx0", "fx1"))
            line = [(G["xA"] + G["xB"] * x, G["yA"] + G["yB"] * (fa + fb * x)) for x in (x0, x1)]
        plot = (G["px0"], G["py0"], G["px1"], G["py1"])
        boxes, leads = {}, {}
        for r in pos.get((scen, meth), []):
            boxes[r["label"]] = tuple(float(r[k]) for k in ("x0", "y0", "x1", "y1"))
            if r["lx0"] != "":
                leads[r["label"]] = tuple(float(r[k]) for k in ("lx0", "ly0", "lx1", "ly1"))
        rows = score_graph(boxes, P, idx, line, plot, marker_hit=mh, label_pt=lpt, leaders=leads)
        for r in rows:
            label_rows.append(dict(set=g["set"], scenario=scen, design=g["design"], method=meth,
                                   **{k: fmt(v) for k, v in r.items()}))
        n = int(g["n_labels"])
        tot_area = sum(r["area"] for r in rows) or 1
        lead = [r for r in rows if r["leader"]]
        nolead = [r for r in rows if not r["leader"]]
        graph_rows.append(dict(
            set=g["set"], scenario=scen, design=g["design"], seed=g["seed"], method=meth,
            n_points=int(g["n_points"]), n_labels=n, drawn=len(rows),
            clean_share=sum(r["clean"] for r in rows) / n,
            clean_near_share=sum(r["clean_near"] for r in rows) / n,
            clean_xown_share=sum(r["clean_xown"] for r in rows) / n,
            overlap_pairs=sum(r["overlap_n"] for r in rows) / 2,
            overlap_area_share=sum(r["overlap_area"] for r in rows) / 2 / tot_area,
            on_marker_share=sum(r["on_marker"] > 0 for r in rows) / n,
            on_marker_other_share=sum(r["on_marker_other"] > 0 for r in rows) / n,
            on_line_share=sum(r["on_line"] for r in rows) / n,
            outside_share=sum(r["outside"] for r in rows) / n,
            ambiguous_share=sum(r["ambiguous"] for r in rows) / n,
            mean_dist_em=sum(r["dist_em"] for r in rows) / max(len(rows), 1),
            leaders=len(lead),
            lead_x_label=sum(r["lead_x_label"] > 0 for r in lead),
            lead_x_marker=sum(r["lead_x_marker"] > 0 for r in lead),
            lead_x_leader=sum(r["lead_x_leader"] > 0 for r in lead),
            lead_x_any=sum((r["lead_x_label"] + r["lead_x_marker"] + r["lead_x_leader"]) > 0 for r in lead),
            amb_lead=sum(r["ambiguous"] for r in lead), amb_nolead=sum(r["ambiguous"] for r in nolead),
            nolead=len(nolead),
            seconds=float(g["seconds"]), rc=int(g["rc"])))
    return label_rows, graph_rows


def write_scores(label_rows, graph_rows):
    write_rows("results/labels.csv", label_rows)
    write_rows("results/graphs.csv", [{k: fmt(v) if k != "seconds" else f"{v:.4f}" for k, v in r.items()}
                                      for r in graph_rows])


def main(argv):
    if argv[:1] == ["--check"]:
        geo, pos, pts = collect(argv[1:])
        if not geo:
            sys.exit("no graphs to check")
        for scen in argv[1:]:
            draw_check(scen, [g for g in geo if g["scenario"] == scen], pos, pts)
        return
    os.makedirs("results", exist_ok=True)
    if argv[:1] != ["--rescore"]:
        geo, pos, pts = collect()
        if not geo:
            sys.exit("no graphs to score: run the drawing steps first")
        missing = [m for m in ALL if not any(g["method"] == m for g in geo)]
        if missing:
            print(f"note: no output for {', '.join(missing)}; left out")
        write_rows("results/geometry.csv", geo, GEO_FIELDS)
        write_rows("results/positions.csv", pos, POS_FIELDS)
        write_rows("results/points.csv", pts)
    label_rows, graph_rows = score_all(*load_archive())
    write_scores(label_rows, graph_rows)
    print(len(graph_rows), "graphs scored")


def rendered_png(scen, meth):
    """The image each method drew for this scenario (kept for main-set real-data scenarios and seed 1)."""
    f = f"out/stata/{scen}__{meth}.png" if meth in STATA else f"out/{meth}/{scen}.png"
    return f if os.path.exists(f) else None


def draw_check(scen, geos, pos_rows, pt_rows):
    """Each method's rendered image, with measured boxes (red), leaders (green) and data points (blue rings)."""
    import matplotlib.pyplot as plt
    from matplotlib.patches import Rectangle
    fig, axes = plt.subplots(2, 4, figsize=(20, 7))
    pts = [r for r in pt_rows if r["scenario"] == scen]
    for ax, g in zip(axes.flat, geos):
        meth = g["method"]
        G = {k: float(g[k]) for k in ("W", "H", "px0", "py0", "px1", "py1", "xA", "xB", "yA", "yB")}
        png = rendered_png(scen, meth)
        if png:
            ax.imshow(plt.imread(png), extent=[0, G["W"], 0, G["H"]], interpolation="antialiased")
        ax.add_patch(Rectangle((G["px0"], G["py0"]), G["px1"] - G["px0"], G["py1"] - G["py0"], fill=False, ec="0.7"))
        ax.scatter([G["xA"] + G["xB"] * float(r["x"]) for r in pts], [G["yA"] + G["yB"] * float(r["y"]) for r in pts],
                   s=10, facecolor="none", edgecolor="tab:blue", lw=0.5)
        for r in pos_rows:
            if r["scenario"] != scen or r["method"] != meth:
                continue
            b = [float(r[k]) for k in ("x0", "y0", "x1", "y1")]
            ax.add_patch(Rectangle(b[:2], b[2] - b[0], b[3] - b[1], fill=False, ec="tab:red", lw=0.6))
            if r["lx0"]:
                ax.plot([float(r["lx0"]), float(r["lx1"])], [float(r["ly0"]), float(r["ly1"])], color="tab:green", lw=0.6)
            if not png:
                ax.text(b[0], b[1], r["label"], fontsize=5)
        ax.set_title(meth if png else f"{meth} (no rendered image kept for this scenario)", fontsize=9)
        ax.set_xlim(0, G["W"])
        ax.set_ylim(0, G["H"])
        ax.set_aspect("equal")
    for ax in list(axes.flat)[len(geos):]:
        ax.axis("off")
    fig.tight_layout()
    fig.savefig(f"out/check_{scen}.png", dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    main(sys.argv[1:])
