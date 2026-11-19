"""Ink audit: do the label boxes in results/positions.csv match the text each method drew?

For each method and scenario, the drawn image is read at high resolution: the Stata SVGs are
rasterised with headless Chrome, and the ggrepel and adjustText images are the ones run_ggrepel.R and
run_adjusttext.py keep when BENCH_PNG_DPI is set. For each label, the bounding box of its ink (dark,
grey pixels) is found inside its measured box widened by 1.5 points. The same is done on a reference
image in which matplotlib draws the label so that its layout box, at the audit resolution, starts at
the measured box's lower left corner. The difference between the two gives, for each edge of the
measured box, how far it lies outside the place an exact box would have (negative: the box cuts into
the text), and from those the box's offset from the text (dx, dy) and its excess width and height.
Only labels whose window holds no marker, no plot edge and no other label are used, since those
would add or hide ink.

Run from the benchmark folder after score.py:
    AUDIT="life12 lifeall autosub autoall syn30all_s01 syn60all_s01 syn60sub_s01 syn60all_f7_s01 syn60all_f11_s01 syn60all_m9_s01"
    BENCH_PNG_DPI=600 BENCH_SCENARIOS="$AUDIT" Rscript run_ggrepel.R
    BENCH_PNG_DPI=600 BENCH_SCENARIOS="$AUDIT" python run_adjusttext.py
    python audit_ink.py $AUDIT
These are the 10 scenarios of the archived results/ink_audit.md; a shorter list rewrites both result files
with fewer labels.
Runs with BENCH_PNG_DPI give the same positions as the reported run (both tools are deterministic) and
do not rewrite the timing files. The Chrome executable is found on the PATH (google-chrome, chromium,
chrome) or in the usual macOS location; BENCH_CHROME names another. AUDIT_DPI (default 600) must
match BENCH_PNG_DPI.
Writes results/ink_audit.csv (one row per label checked) and results/ink_audit.md (per method).
Images go to out/ink_audit/.
"""
import csv
import math
import os
import shutil
import subprocess
import sys
import tempfile
import numpy as np
from PIL import Image
from common import FONT, STATA, ALL_METHODS
import matplotlib.pyplot as plt

DPI = float(os.environ.get("AUDIT_DPI", 600))
S = DPI / 72
PAD = 1.5          # window around a box, points
ISO = 2.0          # no other label box within this many points
OUT = "out/ink_audit"
NAMES = {"default": "Stata mlabel()", "labrepel": "labrepel", "gpolish": "gpolish ptlabel",
         "gpolish060": "gpolish 0.6.0 settings", "adjusttext": "adjustText", "ggrepel": "ggrepel",
         "ggrepel_inf": "ggrepel (informed)"}


def read(p):
    with open(p, encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def chrome():
    c = os.environ.get("BENCH_CHROME")
    if c:
        return c
    for name in ("google-chrome", "chromium", "chromium-browser", "chrome"):
        if shutil.which(name):
            return shutil.which(name)
    mac = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if os.path.exists(mac):
        return mac
    sys.exit("Chrome not found: set BENCH_CHROME")


def svg_png(svg, out, W, H, prof):
    """Rasterises a Stata SVG at DPI with headless Chrome, using a throwaway profile folder."""
    html = os.path.abspath(out + ".html")
    with open(html, "w", encoding="utf-8") as fh:
        fh.write(f'<html><body style="margin:0;background:#fff"><img src="file://{os.path.abspath(svg)}" '
                 f'style="display:block;width:{W}px;height:{H}px"></body></html>')
    subprocess.run([chrome(), "--headless=new", "--disable-gpu", "--hide-scrollbars",
                    f"--user-data-dir={prof}",
                    f"--force-device-scale-factor={S}", f"--window-size={math.ceil(W)},{math.ceil(H)}",
                    f"--screenshot={os.path.abspath(out)}", "file://" + html],
                   check=True, capture_output=True, timeout=120)
    os.remove(html)


def ref_png(boxes, out, W, H, lpt):
    """Draws each label from its box's lower left corner; returns each layout box at DPI (points)."""
    fig = plt.figure(figsize=(W / 72, H / 72), dpi=DPI)
    ts = {s: fig.text(b[0] / W, b[1] / H, s, fontsize=lpt, family=FONT, ha="left", va="bottom", color="black")
          for s, b in boxes.items()}
    r = fig.canvas.get_renderer()
    ext = {}
    for s, t in ts.items():
        e = t.get_window_extent(r)
        ext[s] = (e.x0 / S, e.y0 / S, e.x1 / S, e.y1 / S)
    fig.savefig(out, dpi=DPI, facecolor="white")
    plt.close(fig)
    return ext


def ink_mask(png, W, H):
    a = np.asarray(Image.open(png).convert("RGB")).astype(int)[: int(round(H * S)), : int(round(W * S))]
    mx, mn = a.max(axis=2), a.min(axis=2)
    return (mx < 120) & (mx - mn < 40)          # dark and grey: text, not the blue markers or grey lines


def ink_box(mask, b, H):
    c0, c1 = max(int((b[0] - PAD) * S), 0), min(int((b[2] + PAD) * S) + 1, mask.shape[1])
    r0, r1 = max(int((H - b[3] - PAD) * S), 0), min(int((H - b[1] + PAD) * S) + 1, mask.shape[0])
    rr, cc = np.nonzero(mask[r0:r1, c0:c1])
    if not len(rr):
        return None
    return ((cc.min() + c0) / S, H - (rr.max() + r0 + 1) / S, (cc.max() + c0 + 1) / S, H - (rr.min() + r0) / S)


def usable(s, b, boxes, P, rm, G):
    if any(max(b[0] - PAD - px, 0, px - b[2] - PAD) ** 2 + max(b[1] - PAD - py, 0, py - b[3] - PAD) ** 2 < rm * rm
           for px, py in P):
        return False
    if b[0] - PAD < G["px0"] + 1 or b[1] - PAD < G["py0"] + 1 or b[2] + PAD > G["px1"] - 1 or b[3] + PAD > G["py1"] - 1:
        return False
    return all(t == s or c[0] > b[2] + ISO or c[2] < b[0] - ISO or c[1] > b[3] + ISO or c[3] < b[1] - ISO
               for t, c in boxes.items())


def main(scens):
    if not scens:
        sys.exit("name the scenarios to audit")
    os.makedirs(OUT, exist_ok=True)
    geo = {(g["scenario"], g["method"]): g for g in read("results/geometry.csv")}
    pos, pts = {}, {}
    for r in read("results/positions.csv"):
        if r["scenario"] in scens:
            pos.setdefault((r["scenario"], r["method"]), {})[r["label"]] = tuple(float(r[k]) for k in ("x0", "y0", "x1", "y1"))
    for r in read("results/points.csv"):
        if r["scenario"] in scens:
            pts.setdefault(r["scenario"], []).append((float(r["x"]), float(r["y"])))
    rows = []
    prof = tempfile.mkdtemp(prefix="audit_chrome_")
    try:
        audit(pos, pts, geo, rows, prof)
    finally:
        shutil.rmtree(prof, ignore_errors=True)
    write(rows, scens)


def audit(pos, pts, geo, rows, prof):
    for (scen, meth), boxes in sorted(pos.items()):
        g = geo[(scen, meth)]
        W, H, lpt = float(g["W"]), float(g["H"]), float(g["label_pt"])
        if meth in STATA:
            img = os.path.join(OUT, f"{scen}__{meth}.png")
            svg_png(f"out/stata/{scen}__{meth}.svg", img, W, H, prof)
        else:
            img = f"out/{meth}/{scen}.png"
            if not os.path.exists(img) or Image.open(img).size[0] != int(round(W * S)):
                print(f"note: no {DPI:g} dpi image for {meth} {scen}; run it with BENCH_PNG_DPI={DPI:g}")
                continue
        ref = os.path.join(OUT, f"{scen}__{meth}__ref.png")
        ext = ref_png(boxes, ref, W, H, lpt)
        m_img, m_ref = ink_mask(img, W, H), ink_mask(ref, W, H)
        G = {k: float(g[k]) for k in ("xA", "xB", "yA", "yB", "px0", "py0", "px1", "py1")}
        P = [(G["xA"] + G["xB"] * x, G["yA"] + G["yB"] * y) for x, y in pts[scen]]
        rm = float(g["marker_pt"]) / 2 + 0.5
        for s, b in boxes.items():
            if not usable(s, b, boxes, P, rm, G):
                continue
            a, r, e = ink_box(m_img, b, H), ink_box(m_ref, b, H), ext[s]
            if a is None or r is None:
                rows.append(dict(set=g["set"], scenario=scen, method=meth, label=s, found=0))
                continue
            el = (a[0] - b[0]) - (r[0] - e[0])
            er = (b[2] - a[2]) - (e[2] - r[2])
            eb = (a[1] - b[1]) - (r[1] - e[1])
            et = (b[3] - a[3]) - (e[3] - r[3])
            rows.append(dict(set=g["set"], scenario=scen, method=meth, label=s, found=1,
                             left=f"{el:.3f}", right=f"{er:.3f}", bottom=f"{eb:.3f}", top=f"{et:.3f}",
                             dx=f"{(er - el) / 2:.3f}", dy=f"{(et - eb) / 2:.3f}",
                             dw=f"{el + er:.3f}", dh=f"{eb + et:.3f}"))


def write(rows, scens):
    keys = ["set", "scenario", "method", "label", "found", "left", "right", "bottom", "top", "dx", "dy", "dw", "dh"]
    with open("results/ink_audit.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=keys, lineterminator="\n")
        w.writeheader()
        w.writerows(rows)
    lines = ["# Ink audit", "",
             f"Generated by audit_ink.py at {DPI:g} dpi for: {', '.join(scens)}. Each cell is the median and, in brackets,",
             "the 5th and 95th percentiles over the labels checked, in points. dx and dy are the measured box's offset",
             "from the drawn text (positive: box to the right of or above the text); dw and dh are how much wider and",
             "taller the box is than an exact box for the drawn text. A raster pixel at this resolution is "
             f"{72 / DPI:.2f} points.", "",
             "| Method | Labels checked | Not found | dx | dy | dw | dh |", "|---|---|---|---|---|---|---|"]
    for meth in ALL_METHODS:
        rr = [r for r in rows if r["method"] == meth and r["found"]]
        if not rr:
            continue
        miss = sum(1 for r in rows if r["method"] == meth and not r["found"])
        cells = []
        for k in ("dx", "dy", "dw", "dh"):
            v = np.array([float(r[k]) for r in rr])
            cells.append(f"{np.median(v):+.2f} [{np.percentile(v, 5):+.2f}, {np.percentile(v, 95):+.2f}]")
        lines.append(f"| {NAMES[meth]} | {len(rr)} | {miss} | " + " | ".join(cells) + " |")
    open("results/ink_audit.md", "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("\n".join(lines[-9:]))


if __name__ == "__main__":
    main(sys.argv[1:])
