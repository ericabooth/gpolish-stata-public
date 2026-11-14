"""Build one three-panel strip per gallery example, plus the README hero image.
Run from the repository root:  python gallery/make_sheets.py"""
import glob, os, matplotlib as mpl, matplotlib.pyplot as plt, matplotlib.image as mi
mpl.rcParams["font.family"] = ["Open Sans", "Helvetica", "Arial", "DejaVu Sans"]
HEADS = ["Stata default", "scheme(pypolish) + gpolish", "+ gr2mpl (matplotlib render)"]
os.makedirs("gallery/sheets", exist_ok=True)
def strip(paths, heads, out, w=6.0):
    ims = [mi.imread(p) for p in paths]
    hs = [w * im.shape[0] / im.shape[1] for im in ims]
    fig, axes = plt.subplots(1, len(ims), figsize=(w * len(ims) + 0.3, max(hs) + 0.5), dpi=150)
    for ax, t, im in zip(axes, heads, ims):
        ax.imshow(im); ax.set_axis_off(); ax.set_anchor("N")
        ax.set_title(t, fontsize=11.5, color="#444444", loc="left", pad=7, fontweight="bold")
    fig.subplots_adjust(left=0.008, right=0.992, top=1 - 0.42 / (max(hs) + 0.5), bottom=0.01, wspace=0.03)
    fig.patch.set_facecolor("#efefef")
    fig.savefig(out, dpi=150)
    plt.close(fig)
for a in sorted(glob.glob("gallery/img/*_a.png")):
    tag = os.path.basename(a)[:-6]
    strip([a, a.replace("_a.png", "_b.png"), a.replace("_a.png", "_c.png")], HEADS, f"gallery/sheets/{tag}.png")
    print(tag)
os.makedirs("images", exist_ok=True)
strip(["gallery/img/01_lines_a.png", "gallery/img/01_lines_b.png"], HEADS[:2], "images/before_after.png", w=7.0)
