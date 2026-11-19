"""Measure how closely gr2mpl places text compared with Stata's own export.

For each gallery graph, gallery/fidelity.do writes Stata's SVG export and the
gr2mpl spec folder (keepspec). This script redraws each spec with
gr2mpl_render.py, reads where every text item was placed, reads the same
items from Stata's SVG, matches them by string and reports the distance
between the two anchor points in points (1/72 inch).

The anchor is the point Stata's SVG gives for a text item: the left, centre or
right end of its baseline, as set by the item's text-anchor. The same point is
computed for the matplotlib item from its laid-out baseline and width, so the
two are compared like for like, including rotated tick labels.

Run from the repository root, after gallery/fidelity.do:
    python gallery/fidelity.py
Writes gallery/fidelity.csv (one row per text item) and gallery/fidelity.md.
"""
import csv
import glob
import html
import json
import math
import os
import re
import statistics
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, "src")
import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot  # noqa: E402
import gr2mpl_render as g  # noqa: E402

WORK = "gallery/fidelity_work"
CATS = ["title", "axis title", "tick label", "legend", "annotation", "other"]
CAT_NOTE = {
    "title": "titles, subtitles, notes, captions and panel titles",
    "axis title": "axis titles",
    "tick label": "tick labels, including category-axis labels",
    "legend": "legend entries and legend titles",
    "annotation": "gpolish annotations and other added text",
    "other": "text not named in the spec, mostly marker labels",
}


def norm(s):
    s = html.unescape(s).replace("−", "-").replace(" ", " ")
    return re.sub(r"\s+", " ", s).strip()


def stata_items(path):
    """(text, x, y) in points, y measured down from the top, from Stata's SVG."""
    root = ET.parse(path).getroot()
    vb = [float(v) for v in root.get("viewBox").split()]
    width_in = float(root.get("width").replace("in", ""))
    scale = width_in * 72 / vb[2]
    out = []
    for el in root.iter():
        if not el.tag.endswith("text"):
            continue
        t = norm("".join(el.itertext()))
        if t:
            out.append((t, float(el.get("x")) * scale, float(el.get("y")) * scale,
                        el.get("text-anchor") or "start"))
    return out


def mpl_items(spec_path):
    """(text, x, y, artist) in points from gr2mpl's render: Stata's anchor
    convention is applied later, once the Stata item's text-anchor is known."""
    with open(spec_path, encoding="utf-8") as fh:
        spec = json.load(fh, strict=False)
    spec["specdir"] = os.path.dirname(spec_path)
    held = {}
    g.Figure.save = lambda self: held.setdefault("fig", self.fig)
    g.Figure(spec).render()
    fig = held["fig"]
    drawn = set()                       # only text matplotlib actually draws
    orig = matplotlib.text.Text.draw

    def draw(self, renderer):
        drawn.add(id(self))
        return orig(self, renderer)
    matplotlib.text.Text.draw = draw
    try:
        fig.canvas.draw()
    finally:
        matplotlib.text.Text.draw = orig
    r = fig.canvas.get_renderer()
    k = 72 / fig.dpi
    h_pt = fig.get_figheight() * 72
    out = []
    for t in fig.findobj(matplotlib.text.Text):
        if not t.get_visible() or not t.get_text().strip():
            continue
        if t.get_alpha() == 0 or id(t) not in drawn:
            continue
        _, info, _ = t._get_layout(r)
        posx, posy = t.get_transform().transform(t.get_unitless_position())
        ang = math.radians(t.get_rotation())
        for line, wad, (x, y) in info:
            # mathtext: drop unescaped $ delimiters, keep escaped \$ as $
            s = norm(re.sub(r"(?<!\\)\$", "", line).replace("\\$", "$"))
            if not s:
                continue
            bx, by = posx + x, posy + y            # baseline, left end
            w = wad[0]
            out.append({"text": s, "w": w * k, "ang": ang,
                        "x": bx * k, "y": h_pt - by * k})
    matplotlib.pyplot.close(fig)
    return out, spec


def spec_roles(spec):
    """string -> category, from where the string sits in the spec."""
    roles = {}

    def put(s, cat):
        if not isinstance(s, str):
            return
        for line in re.split(r"\n", s):
            for v in (g.clean_text(line), g.tick_text(line)):
                v = norm(v)
                if v:
                    roles.setdefault(v, cat)

    def walk(o, path):
        if isinstance(o, dict):
            for key, v in o.items():
                walk(v, path + [key])
        elif isinstance(o, list):
            for v in o:
                walk(v, path)
        elif isinstance(o, str):
            p = path
            last = p[-1] if p else ""
            if "legend" in p and last in ("entries", "title"):
                put(o, "legend")
            elif "added_text" in p and last == "text":
                put(o, "annotation")
            elif last in ("ticks", "grpaxis", "supaxis"):
                put(o, "tick label")
            elif (("xaxis" in p or "yaxis" in p) and last == "title") or re.match(r"[lrbt][12]title$", last):
                put(o, "axis title")
            elif last in ("title", "subtitle", "note", "caption", "ptitle"):
                put(o, "title")

    walk(spec, [])
    return roles


def match(st, mp):
    """Pair Stata and matplotlib items with the same string. A string that
    occurs more than once (a 0 tick label on both axes, repeated marker
    labels) is paired to minimize the total distance within that string."""
    from scipy.optimize import linear_sum_assignment
    pairs, used_s, used_m = [], set(), set()
    for text in sorted({t[0] for t in st}):
        si = [i for i, t in enumerate(st) if t[0] == text]
        mj = [j for j, m in enumerate(mp) if m["text"] == text]
        if not mj:
            continue
        cost, delta = [], {}
        for i in si:
            f = {"start": 0, "middle": 0.5, "end": 1}.get(st[i][3], 0)
            row = []
            for j in mj:
                m = mp[j]
                # move the matplotlib anchor along its baseline to Stata's anchor
                dx = m["x"] + f * m["w"] * math.cos(m["ang"]) - st[i][1]
                dy = m["y"] - f * m["w"] * math.sin(m["ang"]) - st[i][2]
                delta[i, j] = (dx, dy)
                row.append(math.hypot(dx, dy))
            cost.append(row)
        for a, b in zip(*linear_sum_assignment(cost)):
            i, j = si[a], mj[b]
            used_s.add(i)
            used_m.add(j)
            pairs.append((i, j, cost[a][b]) + delta[i, j])
    return pairs, used_s, used_m


def q(v, p):
    v = sorted(v)
    if not v:
        return float("nan")
    i = (len(v) - 1) * p
    lo = math.floor(i)
    hi = math.ceil(i)
    return v[lo] + (v[hi] - v[lo]) * (i - lo)


def fmt(v):
    return "" if v != v else f"{v:.1f}"


def main():
    rows = []
    graphs = sorted(os.path.basename(p)[:-4] for p in glob.glob(f"{WORK}/*.svg"))
    if not graphs:
        raise SystemExit("no SVG files in gallery/fidelity_work: run gallery/fidelity.do first")
    for tag in graphs:
        st = stata_items(f"{WORK}/{tag}.svg")
        mp, spec = mpl_items(f"{WORK}/{tag}/spec.json")
        roles = spec_roles(spec)
        pairs, us, um = match(st, mp)
        for i, j, d, dx, dy in pairs:
            t = st[i][0]
            rows.append([tag, roles.get(t, "other"), "both", t, f"{d:.2f}", f"{dx:.2f}", f"{dy:.2f}"])
        for i, s in enumerate(st):
            if i not in us:
                rows.append([tag, roles.get(s[0], "other"), "Stata only", s[0], "", "", ""])
        for j, m in enumerate(mp):
            if j not in um:
                rows.append([tag, roles.get(m["text"], "other"), "gr2mpl only", m["text"], "", "", ""])
    with open("gallery/fidelity.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, lineterminator="\n")
        w.writerow(["graph", "category", "found_in", "text", "distance_pt", "dx_pt", "dy_pt"])
        w.writerows(rows)
    write_md(rows, graphs)


def summarize(rs):
    d = [float(r[4]) for r in rs if r[2] == "both"]
    return {
        "n": len(d), "med": q(d, 0.5), "p90": q(d, 0.9), "max": max(d) if d else float("nan"),
        "le2": sum(x <= 2 for x in d), "le5": sum(x <= 5 for x in d),
        "sonly": sum(r[2] == "Stata only" for r in rs),
        "monly": sum(r[2] == "gr2mpl only" for r in rs),
        "dx": q([float(r[5]) for r in rs if r[2] == "both"], 0.5),
        "dy": q([float(r[6]) for r in rs if r[2] == "both"], 0.5),
    }


def write_md(rows, graphs):
    allm = summarize(rows)
    L = ["# gr2mpl text placement compared with Stata", ""]
    L += ["This page measures how far each text item in a `gr2mpl` image sits from the same item in Stata's own export, for all "
          f"{len(graphs)} gallery graphs. [fidelity.do](fidelity.do) exports each polished graph from Stata as SVG and keeps the "
          "`gr2mpl` spec; [fidelity.py](fidelity.py) redraws the spec, reads where matplotlib placed each line of text, and pairs "
          "it with the Stata line that has the same string. Distances are in points (1/72 inch) on the 7 by 4.6 inch graph, "
          "measured between the anchor points Stata's SVG uses: the left end, centre or right end of the baseline. "
          "Every item is listed in [fidelity.csv](fidelity.csv).", ""]
    L += ["## Overall", ""]
    L += [f"Of {allm['n']} matched text items, half sit within {fmt(allm['med'])} points of Stata's position and 90 percent "
          f"within {fmt(allm['p90'])} points; the largest distance is {fmt(allm['max'])} points. "
          f"{allm['le2']} items ({100*allm['le2']/max(allm['n'],1):.0f} percent) are within 2 points and "
          f"{allm['le5']} ({100*allm['le5']/max(allm['n'],1):.0f} percent) within 5 points. "
          f"{allm['sonly']} items appear only in Stata's export and {allm['monly']} only in the `gr2mpl` image.", ""]
    L += ["## By kind of text", ""]
    L += ["The two shift columns give the median signed offset of the `gr2mpl` item: positive across means further "
          "right than in Stata, positive down means lower on the page.", ""]
    L += ["| Kind | Matched | Median (pt) | 90th pct (pt) | Max (pt) | Within 5 pt | Shift across (pt) | Shift down (pt) | Stata only | gr2mpl only |",
          "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for c in CATS:
        rs = [r for r in rows if r[1] == c]
        if not rs:
            continue
        m = summarize(rs)
        L.append(f"| {CAT_NOTE[c].capitalize()} | {m['n']} | {fmt(m['med'])} | {fmt(m['p90'])} | {fmt(m['max'])} | "
                 f"{m['le5']} | {fmt(m['dx'])} | {fmt(m['dy'])} | {m['sonly']} | {m['monly']} |")
    L += ["", "## By graph", ""]
    L += ["| Graph | Matched | Median (pt) | Max (pt) | Largest item | Stata only | gr2mpl only |",
          "|---|---:|---:|---:|---|---:|---:|"]
    for tag in graphs:
        rs = [r for r in rows if r[0] == tag]
        m = summarize(rs)
        both = [r for r in rs if r[2] == "both"]
        top = max(both, key=lambda r: float(r[4]), default=None)
        big = f"{top[1]}: {top[3][:40]}" if top else ""
        big = big.replace("|", "\\|")
        L.append(f"| {tag} | {m['n']} | {fmt(m['med'])} | {fmt(m['max'])} | {big} | {m['sonly']} | {m['monly']} |")
    L += ["", "## Reading the numbers", ""]
    L += ["A matched item is one whose string appears in both images. An item found in only one image is either text one "
          "program draws and the other does not, or a string the two programs write differently (for example a label "
          "that `gr2mpl` wraps onto two lines where Stata keeps one); the CSV lists each such item. Repeated strings, "
          "such as a 0 tick label on both axes, are paired so that the total distance within that string is as small as possible; where a whole block of repeated labels is shifted, as in the correlation heatmap, this can still pair a label with a neighbour's position. The distance measures position only: it does "
          "not compare font size or the width of the text, so two labels with the same anchor can still differ in "
          "length. Results depend on the fonts installed; these were measured with Open Sans in both programs.", ""]
    with open("gallery/fidelity.md", "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))


if __name__ == "__main__":
    main()
