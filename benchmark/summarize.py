"""Summary tables and figure from results/graphs.csv.

Main set: synthetic designs give the mean over the test seeds with a 95% t interval; real-data
scenarios are one graph each (their rows in the original order). Then: leader lines and their
crossings, ambiguity with and without leaders, paired seed-level differences (gpolish minus each
other method), sort-order sensitivity (perm set), scaling (scale set) and font and marker sizes
(fontmark set). Only the methods, designs and sets present in results/graphs.csv are shown.
Writes results/summary.md, results/benchmark.png and results/benchmark.pdf.  python summarize.py
"""
import csv
import math
import statistics as st
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import re


def _hu(x, nd):
    """Round half up on the value as printed to 9 decimals, so 0.855 (513/600) gives 0.86."""
    from decimal import Decimal, ROUND_HALF_UP
    try:
        if x != x or x in (float("inf"), float("-inf")):
            return x
        return float(Decimal(repr(round(float(x), 9))).quantize(Decimal(1).scaleb(-nd), rounding=ROUND_HALF_UP))
    except (TypeError, ValueError):
        return x


SHARE_COUNTS = ("clean_share", "clean_near_share", "clean_xown_share", "on_marker_share",
                "on_marker_other_share", "on_line_share", "outside_share", "ambiguous_share")


def _exact_share(v, n):
    """graphs*.csv stores each share to 4 decimals; a share of labels is a count over n_labels, so
    recover the exact fraction before averaging (513/600 must print as 0.86, not 0.85)."""
    try:
        v, n = float(v), float(n)
    except (TypeError, ValueError):
        return v
    if n <= 0 or v != v:
        return v
    k = round(v * n)
    return k / n if abs(v * n - k) < 0.02 else v


def _fmt(fmt, x):
    m = re.search(r"\.(\d+)f", fmt)
    return fmt.format(_hu(x, int(m.group(1))) if m else x)


METHODS = ["default", "labrepel", "gpolish", "gpolish060", "adjusttext", "ggrepel", "ggrepel_inf"]
NAMES = {"default": "Stata mlabel()", "labrepel": "labrepel (Stata)", "gpolish": "gpolish ptlabel (Stata)",
         "gpolish060": "gpolish 0.6.0 settings", "adjusttext": "adjustText (Python)", "ggrepel": "ggrepel (R)",
         "ggrepel_inf": "ggrepel (informed)"}
COLORS = {"default": "#9a9a9a", "labrepel": "#e0a100", "gpolish": "#0b5d7a", "gpolish060": "#0b5d7a",
          "adjusttext": "#6fb1c7", "ggrepel": "#b8430f", "ggrepel_inf": "#b8430f"}
OPEN = {"gpolish060", "ggrepel_inf"}      # variants are drawn as open circles in their parent's colour
DESIGNS = [("life12", "Life expectancy, 12 of 63 labelled"), ("autosub", "Auto, 19 of 74 labelled"),
           ("lifeall", "Life expectancy, all 63 labelled"), ("autoall", "Auto, all 74 labelled"),
           ("syn30all", "Synthetic, 30 of 30 labelled"), ("syn60sub", "Synthetic, 20 of 60 labelled"),
           ("syn60all", "Synthetic, 60 of 60 labelled")]
SYN = ["syn30all", "syn60sub", "syn60all"]
METRICS = [("clean_share", "Clean labels (share)", "{:.2f}"),
           ("clean_near_share", "Clean labels within 3 ems of their point (share)", "{:.2f}"),
           ("clean_xown_share", "Clean labels, not counting the label's own marker (share)", "{:.2f}"),
           ("overlap_pairs", "Overlapping label pairs", "{:.1f}"),
           ("on_marker_share", "Labels touching a marker, own marker included (share)", "{:.2f}"),
           ("on_marker_other_share", "Labels touching another point's marker (share)", "{:.2f}"),
           ("on_line_share", "Labels crossing the fit line (share)", "{:.2f}"),
           ("outside_share", "Labels outside the plot (share)", "{:.3f}"),
           ("ambiguous_share", "Labels nearer another point (share)", "{:.2f}"),
           ("mean_dist_em", "Distance from own point (em)", "{:.2f}"),
           ("seconds", "Seconds per graph", "{:.2f}")]
FONTMARK = [("syn60all", "8.6 pt labels, 6 pt markers (main set, seeds 1 to 10)"),
            ("syn60all_f7", "7 pt labels, 6 pt markers"), ("syn60all_f11", "11 pt labels, 6 pt markers"),
            ("syn60all_m4", "8.6 pt labels, 4 pt markers"), ("syn60all_m9", "8.6 pt labels, 9 pt markers")]

# two-sided 95% critical values of Student's t, by degrees of freedom
T975 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262,
        10: 2.228, 11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145, 15: 2.131, 16: 2.120, 17: 2.110,
        18: 2.101, 19: 2.093, 20: 2.086, 25: 2.060, 30: 2.042}


def tcrit(n):
    df = n - 1
    return T975.get(df, T975[max(k for k in T975 if k <= df)] if df < 30 else 1.96)


def ci(vals):
    m = st.mean(vals)
    h = tcrit(len(vals)) * st.stdev(vals) / math.sqrt(len(vals)) if len(vals) > 1 else 0.0
    return m, h


def cell(vals, fmt):
    if not vals:
        return "n/a", float("nan"), 0.0
    m, h = ci(vals)
    if len(vals) < 2:
        return _fmt(fmt, m), m, 0.0
    return _fmt(fmt, m) + " ± " + _fmt(fmt, h), m, h


def rng(vals, fmt="{:.2f}"):
    return f"{_fmt(fmt, st.median(vals))} ({_fmt(fmt, min(vals))} to {_fmt(fmt, max(vals))})"


def table(head, rows):
    return ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)] + ["| " + " | ".join(r) + " |" for r in rows] + [""]


def main():
    rows = list(csv.DictReader(open("results/graphs.csv")))
    for r in rows:
        for k, v in r.items():
            if k not in ("set", "scenario", "design", "method"):
                r[k] = float(v)
        for k in SHARE_COUNTS:
            if k in r and "n_labels" in r:
                r[k] = _exact_share(r[k], r["n_labels"])
    main_rows = [r for r in rows if r["set"] == "main"]
    methods = [m for m in METHODS if any(r["method"] == m for r in main_rows)]
    designs = [(d, n) for d, n in DESIGNS if any(r["design"] == d for r in main_rows)]
    seeds = sorted({int(r["seed"]) for r in main_rows if r["design"] in SYN})
    sel = lambda d, m, rs=main_rows: [r for r in rs if r["design"] == d and r["method"] == m]
    fonts = sorted({r.get("font", "") for r in csv.DictReader(open("results/geometry.csv"))
                    if r["method"] in ("gpolish", "gpolish060")})
    out = ["# Label-placement benchmark: results", "",
           "Generated by summarize.py from results/graphs.csv. See README.md for the design and the definitions.", "",
           f"Main set: each cell is one graph for the real-data scenarios (rows in their original order), and the mean ± 95% t",
           f"interval over {len(seeds)} test seeds ({seeds[0] if seeds else 1} to {seeds[-1] if seeds else 20}) for the synthetic designs. "
           "A *clean* label overlaps no other label, no data marker and",
           "not the fit line, and stays inside the plot region; *clean and near* also requires it to be within",
           "3 ems of its own point. The test seeds were not used in the final choice of gpolish's settings,",
           "but seeds 1 to 6 of the 60-of-60 design were among the graphs used to hand-set release 0.6.0's settings.",
           f"gpolish measured label widths with its width table for: {', '.join(fonts) or 'n/a'}.", ""]
    stats = {}
    for key, title, fmt in METRICS:
        body = []
        for d, dname in designs:
            cells = []
            for m in methods:
                c, mean, h = cell([r[key] for r in sel(d, m)], fmt)
                stats[(key, d, m)] = (mean, h)
                cells.append(c)
            body.append([dname] + cells)
        out += [f"## {title}", ""] + table(["Scenario"] + [NAMES[m] for m in methods], body)

    # leader lines
    lmeth = [m for m in methods if any(r["leaders"] > 0 for r in main_rows if r["method"] == m)]
    out += ["## Leader lines", "",
            "Leaders drawn, and leaders that cross another label's box, come within the marker distance of another point,",
            "or cross another leader (any of the three in the last column), as counts. Synthetic designs give totals over the",
            "test seeds. A leader is the part of a drawn segment outside the label's own box, when at least 1 pt long.", ""]
    for m in lmeth:
        body = []
        for d, dname in designs:
            rs = sel(d, m)
            L, lab = sum(r["leaders"] for r in rs), sum(r["n_labels"] for r in rs)
            def pc(k):
                v = sum(r[k] for r in rs)
                return f"{_hu(v, 0):.0f} ({_hu(v / L, 2):.2f})" if L else "0"
            body.append([dname, f"{_hu(L, 0):.0f} of {_hu(lab, 0):.0f}", pc("lead_x_label"), pc("lead_x_marker"),
                         pc("lead_x_leader"), pc("lead_x_any")])
        out += [f"### {NAMES[m]}", ""] + table(["Scenario", "Leaders (of labels)", "Cross a label (share)",
                                                 "Cross a marker (share)", "Cross a leader (share)",
                                                 "Any crossing (share)"], body)

    # ambiguity split by leader
    out += ["## Ambiguity, labels with and without a leader", "",
            "Share of labels nearer another point than their own, among labels with a leader and among labels without one",
            "(synthetic designs pooled over the test seeds; n/a when there are none).", ""]
    body = []
    for d, dname in designs:
        cells = []
        for m in methods:
            rs = sel(d, m)
            L, NL = sum(r["leaders"] for r in rs), sum(r["nolead"] for r in rs)
            a = f"{_hu(sum(r['amb_lead'] for r in rs) / L, 2):.2f}" if L else "n/a"
            b = f"{_hu(sum(r['amb_nolead'] for r in rs) / NL, 2):.2f}" if NL else "n/a"
            cells.append(f"{a} / {b}")
        body.append([dname] + cells)
    out += table(["Scenario (with / without)"] + [NAMES[m] for m in methods], body)

    # paired differences on the synthetic designs
    others = [m for m in methods if m != "gpolish"]
    paired = {}
    if "gpolish" in methods:
        out += ["## Paired differences on the synthetic designs: gpolish minus each other method", "",
                "For each test seed, gpolish's share minus the other method's share on the same graph. Cells give the mean",
                "difference with its 95% t interval, then the number of seeds where gpolish is higher / equal / lower.", ""]
        for key, title in (("clean_share", "Clean"), ("clean_near_share", "Clean and near"),
                           ("clean_xown_share", "Clean except own marker")):
            body = []
            for d, dname in designs:
                if d not in SYN:
                    continue
                g = {r["seed"]: r[key] for r in sel(d, "gpolish")}
                cells = []
                for m in others:
                    o = {r["seed"]: r[key] for r in sel(d, m)}
                    diffs = [g[s] - o[s] for s in sorted(g) if s in o]
                    if not diffs:
                        cells.append("n/a")
                        continue
                    mn, h = ci(diffs)
                    w = sum(x > 1e-12 for x in diffs)
                    t = sum(abs(x) <= 1e-12 for x in diffs)
                    paired[(key, d, m)] = (mn, mn - h, mn + h, w, t, len(diffs) - w - t)
                    cells.append(f"{_hu(mn, 3):+.3f} ({_hu(mn - h, 3):+.3f} to {_hu(mn + h, 3):+.3f}); {w}/{t}/{len(diffs) - w - t}")
                body.append([dname] + cells)
            out += [f"### {title}", ""] + table(["Design"] + [NAMES[m] for m in others], body)

    # sort-order sensitivity
    perm = [r for r in rows if r["set"] == "perm"]
    if perm:
        pm = [m for m in METHODS if any(r["method"] == m for r in perm)]
        nperm = len({r["seed"] for r in perm})
        seeded = [n for m, n in (("ggrepel", "ggrepel"), ("labrepel", "labrepel")) if m in pm]
        keep = f"; {' and '.join(seeded)} keep{'s' if len(seeded) == 1 else ''} {'its' if len(seeded) == 1 else 'their'} fixed seed" if seeded else ""
        out += ["## Sort-order sensitivity (real data)", "",
                f"Each real-data scenario with its rows in {nperm} random orders (permutation seeds 1 to {nperm}){keep}.",
                "Cells give the median over the orders with the range in brackets; the original order is",
                "the main-set value above.", ""]
        for key, title in (("clean_share", "Clean"), ("clean_near_share", "Clean and near")):
            body = []
            for d, dname in DESIGNS[:4]:
                cells = []
                for m in pm:
                    v = [r[key] for r in perm if r["design"] == d and r["method"] == m]
                    cells.append(rng(v) if v else "n/a")
                body.append([dname] + cells)
            out += [f"### {title}", ""] + table(["Scenario"] + [NAMES[m] for m in pm], body)
        # the main tables give one graph per real-data scenario, in the original row order; this table
        # sets that value beside the median over the orders, so a reader can see where the original falls
        out += ["### Original order against the median over the orders", "",
                "Each cell gives the main-set value (original row order), then the median over the orders",
                "with the range in brackets (clean, then clean and near).", ""]
        body = []
        for d, dname in DESIGNS[:4]:
            cells = []
            for m in pm:
                cc = []
                for key in ("clean_share", "clean_near_share"):
                    o = [r[key] for r in main_rows if r["design"] == d and r["method"] == m]
                    v = [r[key] for r in perm if r["design"] == d and r["method"] == m]
                    cc.append(f"{_hu(o[0], 2):.2f} vs {rng(v)}" if o and v else "n/a")
                cells.append("; ".join(cc))
            body.append([dname] + cells)
        out += table(["Scenario"] + [NAMES[m] for m in pm], body)
        if "gpolish" in pm:
            out += ["### gpolish against each other method, order by order", "",
                    "Number of row orders in which gpolish's share is higher / equal / lower than the other method's",
                    "on the same order (clean, then clean and near).", ""]
            body = []
            for d, dname in DESIGNS[:4]:
                cells = []
                for m in [m for m in pm if m != "gpolish"]:
                    cc = []
                    for key in ("clean_share", "clean_near_share"):
                        g = {r["seed"]: r[key] for r in perm if r["design"] == d and r["method"] == "gpolish"}
                        o = {r["seed"]: r[key] for r in perm if r["design"] == d and r["method"] == m}
                        diffs = [g[k] - o[k] for k in g if k in o]
                        w = sum(x > 1e-12 for x in diffs)
                        t = sum(abs(x) <= 1e-12 for x in diffs)
                        cc.append(f"{w}/{t}/{len(diffs) - w - t}")
                    cells.append("; ".join(cc))
                body.append([dname] + cells)
            out += table(["Scenario"] + [NAMES[m] for m in pm if m != "gpolish"], body)

    # scaling
    sc = [r for r in rows if r["set"] == "scale"]
    if sc:
        sm = [m for m in METHODS if m != "default" and any(r["method"] == m for r in sc)]
        out += ["## Scaling: 150 and 300 points, all labelled", "",
                "Mean over 5 seeds, with the range in brackets. Seconds are for the placement step as defined in README.md.", ""]
        body = []
        for d, dname in (("syn150all", "150 points"), ("syn300all", "300 points")):
            for key, lab, f in (("clean_share", "clean share", "{:.2f}"), ("clean_near_share", "clean and near", "{:.2f}"),
                                ("seconds", "seconds", "{:.1f}")):
                cells = []
                for m in sm:
                    v = [r[key] for r in sc if r["design"] == d and r["method"] == m]
                    cells.append(f"{_fmt(f, st.mean(v))} ({_fmt(f, min(v))} to {_fmt(f, max(v))})" if v else "n/a")
                body.append([f"{dname}, {lab}"] + cells)
        out += table(["Design, measure"] + [NAMES[m] for m in sm], body)

    # font and marker sizes
    fm = [r for r in rows if r["set"] == "fontmark"]
    if fm:
        fmm = [m for m in METHODS if m != "default" and any(r["method"] == m for r in fm)]
        base = [r for r in main_rows if r["design"] == "syn60all" and r["seed"] <= 10]
        out += ["## Font and marker sizes: the 60-of-60 design, seeds 1 to 10", "",
                "Mean ± 95% t interval over 10 seeds. The first row is the main set's 60-of-60 design on the same seeds.",
                "The marker rule and the 3-em distance follow each condition's marker and font size.", ""]
        for key, title in (("clean_share", "Clean"), ("clean_near_share", "Clean and near")):
            body = []
            for d, dname in FONTMARK:
                src = base if d == "syn60all" else fm
                cells = []
                for m in fmm:
                    c, mean, h = cell([r[key] for r in src if r["design"] == d and r["method"] == m], "{:.2f}")
                    stats[("fm_" + key, d, m)] = (mean, h)
                    cells.append(c)
                body.append([dname] + cells)
            out += [f"### {title}", ""] + table(["Condition"] + [NAMES[m] for m in fmm], body)
    # stopping rules: iterations of adjustText and ggrepel
    geo = list(csv.DictReader(open("results/geometry.csv")))
    it_rows = []
    for m in ("adjusttext", "ggrepel", "ggrepel_inf"):
        for sname in ("main", "perm", "scale", "fontmark"):
            gs = [g for g in geo if g["method"] == m and g["set"] == sname and g.get("iterations", "") != ""]
            if not gs:
                continue
            its = [int(g["iterations"]) for g in gs]
            secs = [float(g["seconds"]) for g in gs]
            if m == "adjusttext":
                stops = f"{sum(i >= 100 for i in its)} / {sum(i < 100 for i in its)} / 0"
                differ = "n/a"
            else:
                stops = " / ".join(str(sum(g["stop"] == k for g in gs))
                                   for k in ("iteration limit", "settled", "time limit"))
                differ = str(sum(1 for g in gs if g["iterations_drawn"] != g["iterations"]))
            it_rows.append([NAMES[m], sname, str(len(gs)), f"{min(its)} to {max(its)}", stops,
                            f"{_hu(min(secs), 2):.2f} to {_hu(max(secs), 2):.2f}", differ])
    if it_rows:
        out += ["## Stopping rules: iterations of adjustText and ggrepel", "",
                "adjustText runs at most 100 iterations (iter_lim=100, no time limit) and stops earlier when its labels",
                "settle. ggrepel runs with max.iter = 10000 (its default) and max.time = Inf (its default is 0.5 seconds),",
                "so it stops at 10,000 iterations or when its labels settle, and no graph depends on the machine's speed.",
                "ggrepel's positions are read from a second run of its placement with the same seed (see run_ggrepel.R);",
                "the last column counts graphs where that run's iteration count differs from the drawn run's. Seconds are",
                "as in the tables above.", ""]
        out += table(["Method", "Set", "Graphs", "Iterations", "Stopped at the iteration limit / settled / time limit",
                      "Seconds", "Read-back run differs"], it_rows)
    open("results/summary.md", "w").write("\n".join(out))

    # figure
    plt.rcParams.update({"font.family": "Open Sans", "font.size": 9, "pdf.fonttype": 42})
    fig, axes = plt.subplots(1, 3, figsize=(13, 5.2), gridspec_kw={"width_ratios": [1.3, 1.3, 1], "wspace": 0.08})
    step = 0.8 / max(len(methods), 1)
    for ax, key, xlab, logx in ((axes[0], "clean_share", "Share of labels that are clean", False),
                                (axes[1], "clean_near_share", "Clean and within 3 ems of their point", False),
                                (axes[2], "seconds", "Seconds per graph, log scale\n(mlabel() has no placement step; drawn at 0.001)", True)):
        for j, m in enumerate(methods):
            ys = [i + (j - (len(methods) - 1) / 2) * step for i in range(len(designs))]
            xs = [stats[(key, d, m)][0] for d, _ in designs]
            hs = [stats[(key, d, m)][1] for d, _ in designs]
            if logx:
                xs = [max(x, 0.001) for x in xs]
                hs = [0 for _ in hs]
            ax.errorbar(xs, ys, xerr=hs, fmt="o", ms=4.5, color=COLORS[m], ecolor=COLORS[m], elinewidth=1,
                        capsize=0, label=NAMES[m], mfc="white" if m in OPEN else COLORS[m], mew=1.2)
        ax.set_yticks(range(len(designs)))
        ax.set_yticklabels([n for _, n in designs] if key == "clean_share" else [])
        ax.invert_yaxis()
        ax.set_xlabel(xlab, color="#555555")
        if logx:
            ax.set_xscale("log")
        else:
            ax.set_xlim(0, 1)
        ax.grid(axis="x", color="#e4e4e4")
        for s in ("top", "right", "left"):
            ax.spines[s].set_visible(False)
        ax.tick_params(axis="y", length=0)
    axes[0].legend(loc="lower center", bbox_to_anchor=(1.3, 1.0), ncol=4, frameon=False, fontsize=8.5,
                   handletextpad=0.2, columnspacing=1.2)
    fig.suptitle(f"Label placement: clean labels, clean and near labels, and time, {len(methods)} methods",
                 x=0.01, ha="left", fontweight="bold", y=1.06)
    for ext in ("png", "pdf"):
        fig.savefig(f"results/benchmark.{ext}", dpi=180, bbox_inches="tight", facecolor="white",
                    metadata={"CreationDate": None} if ext == "pdf" else None)
    print("\n".join(out[:12]))
    return stats, paired


if __name__ == "__main__":
    main()
