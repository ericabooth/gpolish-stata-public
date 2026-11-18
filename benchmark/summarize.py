"""Summary tables and figure from results/graphs.csv.

Synthetic designs: mean over the test seeds with a 95% t interval. Real-data scenarios: one graph each.
Only the methods and designs present in results/graphs.csv are shown, so a run that skipped a
method (for example labrepel when it is not installed) or ran a subset of scenarios still summarizes.
Writes results/summary.md and results/benchmark.png.  python summarize.py
"""
import csv
import math
import statistics as st
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

NUM = {1: "one", 2: "two", 3: "three", 4: "four", 5: "five"}
METHODS = ["default", "labrepel", "gpolish", "adjusttext", "ggrepel"]
NAMES = {"default": "Stata mlabel()", "labrepel": "labrepel (Stata)", "gpolish": "gpolish ptlabel (Stata)",
         "adjusttext": "adjustText (Python)", "ggrepel": "ggrepel (R)"}
COLORS = {"default": "#9a9a9a", "labrepel": "#e0a100", "gpolish": "#0b5d7a", "adjusttext": "#6fb1c7", "ggrepel": "#b8430f"}
DESIGNS = [("life12", "Life expectancy, 12 of 63 labelled"), ("autosub", "Auto, 19 of 74 labelled"),
           ("lifeall", "Life expectancy, all 63 labelled"), ("autoall", "Auto, all 74 labelled"),
           ("syn30all", "Synthetic, 30 of 30 labelled"), ("syn60sub", "Synthetic, 20 of 60 labelled"),
           ("syn60all", "Synthetic, 60 of 60 labelled")]
METRICS = [("clean_share", "Clean labels (share)", "{:.2f}"),
           ("clean_near_share", "Clean labels within 3 ems of their point (share)", "{:.2f}"), ("overlap_pairs", "Overlapping label pairs", "{:.1f}"),
           ("on_marker_share", "Labels touching a marker (share)", "{:.2f}"),
           ("on_line_share", "Labels crossing the fit line (share)", "{:.2f}"),
           ("outside_share", "Labels outside the plot (share)", "{:.3f}"),
           ("ambiguous_share", "Labels nearer another point (share)", "{:.2f}"),
           ("mean_dist_em", "Distance from own point (em)", "{:.2f}"), ("seconds", "Seconds per graph", "{:.2f}")]


# two-sided 95% critical values of Student's t, by degrees of freedom
T975 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306, 9: 2.262,
        10: 2.228, 11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145, 15: 2.131, 16: 2.120, 17: 2.110,
        18: 2.101, 19: 2.093, 20: 2.086, 25: 2.060, 30: 2.042}


def tcrit(n):
    df = n - 1
    return T975.get(df, T975[max(k for k in T975 if k <= df)] if df < 30 else 1.96)


def cell(vals, fmt):
    if not vals:
        return "n/a", float("nan"), 0.0
    m = st.mean(vals)
    if len(vals) < 2:
        return fmt.format(m), m, 0.0
    h = tcrit(len(vals)) * st.stdev(vals) / math.sqrt(len(vals))
    return fmt.format(m) + " ± " + fmt.format(h), m, h


def main():
    rows = list(csv.DictReader(open("results/graphs.csv")))
    methods = [m for m in METHODS if any(r["method"] == m for r in rows)]
    designs = [(d, n) for d, n in DESIGNS if any(r["design"] == d for r in rows)]
    seeds = sorted({int(r["seed"]) for r in rows if r["design"].startswith("syn")})
    seedrange = f"{seeds[0]}-{seeds[-1]}" if seeds else "1-20"
    out = ["# Label-placement benchmark: results", "",
           f"Each cell is one graph for the real-data scenarios, and the mean ± 95% interval over {len(seeds)} random",
           "seeds for the synthetic designs. A *clean* label overlaps no other label, no data marker and",
           "not the fit line, and stays inside the plot region; *clean and near* also requires it to be within",
           f"3 ems of its own point. Synthetic results use test seeds {seedrange}, which were not used to choose",
           "gpolish's settings. See README.md for the design.", ""]
    stats = {}
    for key, title, fmt in METRICS:
        out += [f"## {title}", "", "| Scenario | " + " | ".join(NAMES[m] for m in methods) + " |",
                "|---|" + "---|" * len(methods)]
        for d, dname in designs:
            cells = []
            for m in methods:
                v = [float(r[key]) for r in rows if r["design"] == d and r["method"] == m]
                c, mean, h = cell(v, fmt)
                stats[(key, d, m)] = (mean, h)
                cells.append(c)
            out.append(f"| {dname} | " + " | ".join(cells) + " |")
        out.append("")
    open("results/summary.md", "w").write("\n".join(out) + "\n")

    plt.rcParams.update({"font.family": "Open Sans", "font.size": 9})
    fig, axes = plt.subplots(1, 3, figsize=(13, 4.6), gridspec_kw={"width_ratios": [1.3, 1.3, 1], "wspace": 0.08})
    for ax, key, xlab, logx in ((axes[0], "clean_share", "Share of labels that are clean", False),
                                (axes[1], "clean_near_share", "Clean and within 3 ems of their point", False),
                                (axes[2], "seconds", "Seconds per graph, log scale\n(mlabel() has no placement step; drawn at 0.001)", True)):
        for j, m in enumerate(methods):
            ys = [i + (j - (len(methods) - 1) / 2) * 0.14 for i in range(len(designs))]
            xs = [stats[(key, d, m)][0] for d, _ in designs]
            hs = [stats[(key, d, m)][1] for d, _ in designs]
            if logx:
                xs = [max(x, 0.001) for x in xs]
                hs = [0 for _ in hs]
            ax.errorbar(xs, ys, xerr=hs, fmt="o", ms=5, color=COLORS[m], ecolor=COLORS[m], elinewidth=1,
                        capsize=0, label=NAMES[m])
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
    axes[0].legend(loc="lower center", bbox_to_anchor=(1.3, 1.0), ncol=len(methods), frameon=False, fontsize=8.5,
                   handletextpad=0.2, columnspacing=1.2)
    fig.suptitle(f"Label placement: clean labels, clean and near labels, and time, {NUM.get(len(methods), len(methods))} methods", x=0.01, ha="left", fontweight="bold", y=1.02)
    fig.savefig("results/benchmark.png", dpi=180, bbox_inches="tight", facecolor="white")
    print(open("results/summary.md").read())


if __name__ == "__main__":
    main()
