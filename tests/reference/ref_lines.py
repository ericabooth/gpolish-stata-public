"""Reference chart 1: polished multi-series line chart, matplotlib only."""
import pandas as pd, numpy as np, matplotlib as mpl, matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch
import sys
out = sys.argv[1] if len(sys.argv) > 1 else "ref_lines.png"
d = pd.read_csv("uslifeexp.csv")
mpl.rcParams.update({"font.family": "Open Sans", "font.size": 9.5,
                     "svg.fonttype": "none"})
INK, MUTE, GRID = "#1a1a1a", "#6b6b6b", "#e4e4e4"
S = [("le_wfemale", "White women", "#0b5d7a"),
     ("le_wmale",   "White men",   "#6fb1c7"),
     ("le_bfemale", "Black women", "#b8430f"),
     ("le_bmale",   "Black men",   "#f0a35e")]
fig = plt.figure(figsize=(7.5, 5.0), dpi=200)
ax = fig.add_axes([0.075, 0.125, 0.735, 0.665])
for v, lab, c in S:
    ax.plot(d.year, d[v], color=c, lw=2.0, solid_capstyle="round", zorder=3)
    ax.plot(d.year.iloc[-1], d[v].iloc[-1], "o", ms=5.5, color=c, mec="white", mew=1.0, zorder=4)
# axes
ax.set_xlim(1895.5, 2000.5); ax.set_ylim(28, 83)
ax.set_yticks(range(30, 81, 10))
ax.tick_params(axis="y", length=0, pad=6, labelcolor=MUTE)
ax.set_xticks([1900, 1920, 1940, 1960, 1980, 1999])
ax.tick_params(axis="x", length=4, color="#9a9a9a", labelcolor=MUTE, pad=4)
ax.grid(axis="y", color=GRID, lw=0.8, zorder=0); ax.set_axisbelow(True)
for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color("#9a9a9a")
# end labels with repel
ends = sorted([(d[v].iloc[-1], lab, c) for v, lab, c in S])
ys = [e[0] for e in ends]; sep = 3.1
for _ in range(200):
    moved = False
    for i in range(len(ys) - 1):
        gap = sep - (ys[i + 1] - ys[i])
        if gap > 1e-6: ys[i] -= gap / 2; ys[i + 1] += gap / 2; moved = True
    if not moved: break
for (val, lab, c), y in zip(ends, ys):
    ax.annotate(lab, (1999, y), xytext=(9, 0), textcoords="offset points", color=c,
                fontweight="bold", va="center", fontsize=9.5, annotation_clip=False)
    ax.annotate(f"{val:.1f}", (1999, y), xytext=(96, 0), textcoords="offset points", color=c,
                va="center", ha="right", fontsize=9.5, annotation_clip=False)
AR = dict(arrowstyle="-|>,head_length=0.5,head_width=0.22", color="#555555", lw=0.8, shrinkA=3, shrinkB=2)
# annotation: 1918
ax.annotate("1918 influenza\npandemic", xy=(1918.7, 31.2), xytext=(1929, 33.5), color=INK,
            fontsize=8.8, va="center", linespacing=1.25, arrowprops=dict(connectionstyle="arc3,rad=-0.3", **AR))
# annotation: gap bracket at 1900
y0, y1 = d.le_bfemale.iloc[0], d.le_wfemale.iloc[0]
ax.plot([1898.2, 1897.4, 1897.4, 1898.2], [y0, y0, y1, y1], color="#555555", lw=0.8, zorder=2)
ax.annotate(f"In 1900, white women\noutlived Black women\nby {y1 - y0:.0f} years",
            xy=(1897.4, 49.4), xytext=(1896.6, 66.5), color=INK, fontsize=8.8, va="center", linespacing=1.25,
            arrowprops=dict(connectionstyle="arc3,rad=0.0", relpos=(0.035, 0.0), **AR))
g99 = d.le_wfemale.iloc[-1] - d.le_bfemale.iloc[-1]
ax.annotate(f"By 1999 the gap\nwas {g99:.0f} years", xy=(1997.2, 77.3), xytext=(1972, 57.5), color=INK,
            fontsize=8.8, va="center", ha="left", linespacing=1.25,
            arrowprops=dict(connectionstyle="arc3,rad=0.3", relpos=(1.0, 0.75), **AR))
# titles
fig.text(0.04, 0.945, "Life expectancy rose for every group, but the racial gap never closed",
         fontsize=14.5, fontweight="bold", color=INK, va="top")
fig.text(0.04, 0.878, "Life expectancy at birth in the United States, 1900–1999, in years", fontsize=10.5, color=MUTE, va="top")
fig.text(0.04, 0.03, "Source: National Vital Statistics Reports, Vol. 50, No. 6 (Stata dataset uslifeexp).",
         fontsize=8, color=MUTE, va="bottom")
fig.savefig(out, dpi=200, facecolor="white")
