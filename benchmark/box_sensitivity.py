"""How much of gpolish's real-data result depends on the box its search uses.

gpolish's search (_gpl_place in gpolish.ado) treats each label as a box whose core is as wide as the
text and 0.4 times the font size tall, padded by 3 points on every side (the tuned settings in
_gpl_placeparms()). The benchmark scores the box of the drawn text, measured with matplotlib, which is
about as wide as the search's core box and about 2.5 times as tall. This script rescores gpolish's
labels in the main and perm sets from the archive with three boxes, each centred where the scored
box is centred:

  scored   the measured text box (the box behind every other table);
  core     the scored box's width and 0.4 times the font size tall (the search's box without padding);
  padded   the core box widened and heightened by 3 points on every side (the box the search tests).

Everything else in the rule (markers, fit line, plot edges, other labels' boxes) is unchanged; only
gpolish's own boxes are swapped, and the other methods keep their measured boxes. The core and padded
boxes approximate the search's box: its width comes from gpolish's width table rather than from the
measured text, and its vertical centre follows the text's alignment. This is a post hoc check, run
after the test results were seen; it changes no setting. Writes results/box_sensitivity.md.
Run from the benchmark folder after score.py:
    python box_sensitivity.py
"""
import statistics as st
import score
from summarize import DESIGNS, NAMES

PAD = 3.0
CORE_H = 0.4
REAL = DESIGNS[:4]


def swap(pos, geo, kind):
    """A copy of the positions with gpolish's boxes replaced by the given kind of box."""
    lpt = {g["scenario"]: float(g["label_pt"]) for g in geo if g["method"] == "gpolish"}
    out = {}
    for key, rows in pos.items():
        if key[1] != "gpolish" or kind == "scored":
            out[key] = rows
            continue
        new = []
        for r in rows:
            x0, y0, x1, y1 = (float(r[k]) for k in ("x0", "y0", "x1", "y1"))
            cy = (y0 + y1) / 2
            hh = CORE_H * lpt[key[0]] / 2
            p = PAD if kind == "padded" else 0.0
            q = dict(r)
            q.update(x0=x0 - p, x1=x1 + p, y0=cy - hh - p, y1=cy + hh + p)
            new.append(q)
        out[key] = new
    return out


def main():
    geo, pos, pts = score.load_archive()
    res = {}
    for kind in ("scored", "core", "padded"):
        g = [r for r in score.score_all(geo, swap(pos, geo, kind), pts, sets={"main", "perm"})[1]
             if r["method"] in ("gpolish", "ggrepel_inf", "gpolish060")]
        for r in g:
            res.setdefault((kind, r["set"], r["design"], r["method"]), []).append(r)
    out = ["# Label-placement benchmark: gpolish scored with its search's box", "",
           "Post hoc check; no setting was changed. gpolish's labels rescored with the measured text box",
           "(scored), the search's core box (as wide as the text, 0.4 times the font size tall) and that core",
           "box padded by 3 points on every side (padded). See box_sensitivity.py for the construction.",
           "Main-set cells are the single graph in the original row order; perm cells give the median and",
           "range over 10 row orders. The informed ggrepel and gpolish 0.6.0 columns keep their measured boxes.", ""]
    for key, title in (("clean_share", "Clean labels (share)"),
                       ("clean_near_share", "Clean labels within 3 ems of their point (share)")):
        out += [f"## {title}", "",
                "| Scenario | Rows | gpolish, scored box | gpolish, core box | gpolish, padded box | "
                + f"{NAMES['gpolish060']} | {NAMES['ggrepel_inf']} |", "|---|---|---|---|---|---|---|"]
        for d, dname in REAL:
            for sname, lab in (("main", "original order"), ("perm", "10 orders")):
                cells = []
                for kind, m in (("scored", "gpolish"), ("core", "gpolish"), ("padded", "gpolish"),
                                ("scored", "gpolish060"), ("scored", "ggrepel_inf")):
                    v = [float(score.fmt(r[key])) for r in res.get((kind, sname, d, m), [])]
                    if not v:
                        cells.append("n/a")
                    elif sname == "main":
                        cells.append(f"{v[0]:.2f}")
                    else:
                        cells.append(f"{st.median(v):.2f} ({min(v):.2f} to {max(v):.2f})")
                out.append(f"| {dname} | {lab} | " + " | ".join(cells) + " |")
        out.append("")
    open("results/box_sensitivity.md", "w").write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
