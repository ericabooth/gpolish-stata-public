"""Reference chart 2: polished labelled scatter with log axis, matplotlib only."""
import pandas as pd, numpy as np, matplotlib as mpl, matplotlib.pyplot as plt, sys
import matplotlib.patheffects as pe
out = sys.argv[1] if len(sys.argv) > 1 else "ref_scatter.png"
d = pd.read_csv("lifeexp.csv").dropna(subset=["gnppc", "lexp"])
mpl.rcParams.update({"font.family": "Open Sans", "font.size": 9.5})
INK, MUTE, GRID = "#1a1a1a", "#6b6b6b", "#e4e4e4"
COL = {"Europe & C. Asia": "#0b5d7a", "North America": "#b8430f", "South America": "#e0a100"}
NAME = {"Europe & C. Asia": "Europe & Central Asia", "North America": "North America", "South America": "South America"}
fig = plt.figure(figsize=(7.5, 5.0), dpi=200)
ax = fig.add_axes([0.075, 0.175, 0.885, 0.58])
# fit: life expectancy on log income
b = np.polyfit(np.log(d.gnppc), d.lexp, 1)
xs = np.geomspace(350, 45000, 100)
ax.plot(xs, b[0] * np.log(xs) + b[1], color="#9a9a9a", lw=1.2, ls=(0, (4, 3)), zorder=2)
for r, c in COL.items():
    s = d[d.regionname == r]
    ax.scatter(s.gnppc, s.lexp, s=42, color=c, alpha=0.85, ec="white", lw=0.7, zorder=3)
ax.set_xscale("log"); ax.set_xlim(300, 52000); ax.set_ylim(52.5, 81.5)
ax.set_xticks([500, 1000, 2000, 5000, 10000, 20000, 40000])
ax.set_xticklabels(["$500", "$1,000", "$2,000", "$5,000", "$10,000", "$20,000", "$40,000"])
ax.minorticks_off()
ax.set_yticks(range(55, 81, 5))
ax.tick_params(axis="y", length=0, pad=6, labelcolor=MUTE)
ax.tick_params(axis="x", length=4, color="#9a9a9a", labelcolor=MUTE, pad=4)
ax.grid(axis="y", color=GRID, lw=0.8, zorder=0); ax.set_axisbelow(True)
for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color("#9a9a9a")
ax.set_xlabel("GNP per capita, 1998 (log scale)", color=MUTE, labelpad=6)
# selected labels: (country, dx, dy, ha)
LAB = {"Haiti": (8, 0, "left"), "United States": (-6, -11, "right"), "Switzerland": (0, 10, "center"),
       "Bolivia": (8, -2, "left"), "Russian Federation": (-8, -6, "right"), "Moldova": (4, -11, "center"),
       "Armenia": (-8, 5, "right"), "Brazil": (8, -6, "left"), "Kazakhstan": (8, -3, "left"),
       "Canada": (-8, 5, "right"), "Guatemala": (8, -4, "left"), "Denmark": (6, -10, "center")}
for k, (dx, dy, ha) in LAB.items():
    r = d[d.country == k].iloc[0]
    ax.annotate(k, (r.gnppc, r.lexp), xytext=(dx, dy), textcoords="offset points", ha=ha, va="center",
                fontsize=8.6, color=INK, path_effects=[pe.withStroke(linewidth=2.2, foreground="white")], zorder=5)
ax.text(7300, 75.5, "Log-linear fit", fontsize=8.6, color=MUTE, rotation=11, ha="center")
# titles + colour key
fig.text(0.04, 0.945, "Richer countries live longer, but income explains less at the top",
         fontsize=14.5, fontweight="bold", color=INK, va="top")
fig.text(0.04, 0.878, "Life expectancy at birth (years) and GNP per capita, 63 countries, 1998", fontsize=10.5, color=MUTE, va="top")
x = 0.04
for r, c in COL.items():
    fig.patches.append(mpl.patches.Circle((x + 0.008, 0.807), 0.0065, transform=fig.transFigure, color=c, figure=fig))
    t = fig.text(x + 0.022, 0.807, NAME[r], color=c, fontweight="bold", fontsize=9.5, va="center")
    fig.canvas.draw(); x = t.get_window_extent().x1 / fig.bbox.width + 0.03
fig.text(0.04, 0.03, "Source: World Bank Group, World Development Indicators (Stata dataset lifeexp).", fontsize=8, color=MUTE, va="bottom")
fig.savefig(out, dpi=200, facecolor="white")
