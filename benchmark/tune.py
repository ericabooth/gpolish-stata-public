"""Choose gpolish ptlabel's placement settings on held-out tuning scenarios.

The settings live in one Mata function in src/gpolish.ado, _gpl_placeparms(). For each
candidate in the grid below this script writes a copy of gpolish.ado with that setting,
draws every tuning scenario (data/manifest_tuning.csv: synthetic seeds 101-110, never used
for reporting) with tune.do, and scores the labels with the same rule as score.py.
The chosen setting maximises the mean share of labels that are clean and near: clean, and no more
than NEAR_EM ems from their own point. A first version of this script optimised the clean share
alone, which rewarded sending labels far out on long leader lines; the distance cap prevents that.
Writes results/tuning.csv.  Run from the benchmark folder after make_synthetic.py:
    python tune.py [stata executable] [parallel workers]
"""
import concurrent.futures as cf
import csv
import html
import itertools
import os
import re
import statistics as st
import subprocess
import sys
from common import data, Measurer
import score

STATA = sys.argv[1] if len(sys.argv) > 1 else "stata-mp"
WORKERS = int(sys.argv[2]) if len(sys.argv) > 2 else 4
# Five stages, all on the tuning seeds only. Stage 1 is a wide grid. Later stages extended ranges
# whose best value sat at an edge and narrowed or fixed the others; stage 3 also added an
# intermediate distance cost, (0.05, 0.005), and stage 4 first varied the ring spacing. The
# chosen setting is the best over all stages.
STAGES = [
    {"rings": [6, 9, 12], "step": [0.9],
     "base": [(0.8, 0.12), (0.6, 0.08), (0.4, 0.04), (0.3, 0.03), (0.2, 0.02), (0.1, 0.01), (0.0, 0.0)],
     "height": [1.0, 1.15, 1.3, 1.4], "pad": [0.0, 0.6, 1.0, 1.5, 2.0]},
    {"rings": [9, 12], "step": [0.9], "base": [(0.1, 0.01), (0.0, 0.0)],
     "height": [0.85, 1.0, 1.15], "pad": [2.0, 2.5, 3.0, 4.0]},
    # stage 3: the box-height factor was still best at its lowest value, so lower values are tried
    {"rings": [9], "step": [0.9], "base": [(0.1, 0.01), (0.05, 0.005)],
     "height": [0.6, 0.7, 0.85], "pad": [1.5, 2.0, 2.5]},
    # stage 4: lower box heights again, and the first variation of the ring spacing
    {"rings": [9], "step": [0.6, 0.9, 1.2], "base": [(0.1, 0.01), (0.05, 0.005)],
     "height": [0.4, 0.5, 0.6, 0.7], "pad": [2.0, 2.5, 3.0]},
    # stage 5: stage 4's best ring spacing, height and padding were again at edges; extend once more.
    # Stopping rule, set before this stage: stop when extending gains less than 0.01.
    {"rings": [9], "step": [0.4, 0.5, 0.6], "base": [(0.05, 0.005)],
     "height": [0.2, 0.3, 0.4], "pad": [3.0, 3.5, 4.0]},
]
NEAR_EM = 3.0
PARM_RE = re.compile(r"(real rowvector _gpl_placeparms\(\)\n\{\n    return\(\()[^)]*(\)\))")


def configs():
    seen = set()
    for stage, g in enumerate(STAGES, 1):
        for r, s, (b, dw), hh, p in itertools.product(g["rings"], g["step"], g["base"], g["height"], g["pad"]):
            tag = f"r{r}_s{s}_b{b}_d{dw}_h{hh}_p{p}"
            if tag not in seen:
                seen.add(tag)
                yield tag, (r, s, b, dw, hh, p), stage


def run(tag, parms):
    d = os.path.abspath(f"out/tune/{tag}")
    os.makedirs(d, exist_ok=True)
    src = open("../src/gpolish.ado", encoding="utf-8").read()
    new, n = PARM_RE.subn(lambda m: m.group(1) + ", ".join(str(v) for v in parms) + m.group(2), src)
    assert n == 1, "settings function not found"
    open(os.path.join(d, "gpolish.ado"), "w", encoding="utf-8").write(new)
    env = dict(os.environ, TUNE_DIR=d)
    subprocess.run([STATA, "-b", "do", os.path.abspath("tune.do")], cwd=os.getcwd(), env=env,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return tag, parms


def score_dir(tag):
    d = f"out/tune/{tag}"
    man = {r["scenario"]: r for r in csv.DictReader(open("data/manifest_tuning.csv"))}
    by = {}
    for g in csv.DictReader(open(f"{d}/geometry_gpolish.csv")):
        scen = g["scenario"]
        g = {k: (float(v) if k not in ("scenario", "method") else v) for k, v in g.items()}
        rows = data(scen)
        labels = {r["label"] for r in rows if r["lab"]}
        meas = Measurer(g["W"], g["H"])
        svg = open(f"{d}/{scen}__gpolish.svg", encoding="utf-8").read()
        k = float(re.search(r'viewBox="0 0 ([\d.]+)', svg).group(1)) / meas.W
        boxes = {}
        for m in score.TEXT_RE.finditer(svg):
            s = html.unescape(m.group(6))
            if s in labels and s not in boxes:
                boxes[s] = meas.box(s, float(m.group(1)) / k, g["H"] - float(m.group(2)) / k,
                                    ha=score.HA[m.group(5)], va="baseline", size=float(m.group(3)) / k)
        meas.close()
        pts = [(g["xA"] + g["xB"] * r["x"], g["yA"] + g["yB"] * r["y"]) for r in rows]
        idx = {r["label"]: i for i, r in enumerate(rows)}
        sc = score.score_graph(boxes, pts, idx, None, (g["px0"], g["py0"], g["px1"], g["py1"]))
        n = len(labels)
        by.setdefault(man[scen]["design"], []).append((
            sum(r["clean"] and r["dist_em"] <= NEAR_EM for r in sc) / n, sum(r["clean"] for r in sc) / n,
            st.mean(r["dist_em"] for r in sc), g["seconds"]))
    return {des: tuple(st.mean(x[k] for x in v) for k in range(4)) for des, v in by.items()}


def main():
    cfgs = list(configs())
    # a setting already drawn (its geometry file exists) is not drawn again
    todo = [c for c in cfgs if not os.path.exists(f"out/tune/{c[0]}/geometry_gpolish.csv")]
    with cf.ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(lambda c: run(c[0], c[1]), todo))
    out = []
    with cf.ProcessPoolExecutor(WORKERS) as ex:
        scored = list(ex.map(score_dir, [c[0] for c in cfgs]))
    for (tag, parms, stage), res in zip(cfgs, scored):
        designs = sorted(res)
        overall = st.mean(res[d][0] for d in designs)
        secs = st.mean(res[d][3] for d in designs)
        out.append(dict(config=tag, stage=stage, rings=parms[0], step=parms[1], base=parms[2], dist=parms[3], height=parms[4],
                        pad=parms[5], **{f"near_{d}": round(res[d][0], 4) for d in designs},
                        near_mean=round(overall, 4), clean_mean=round(st.mean(res[d][1] for d in designs), 4),
                        dist_em=round(st.mean(res[d][2] for d in designs), 3), seconds=round(secs, 3)))
    out.sort(key=lambda r: (-r["near_mean"], r["seconds"]))
    os.makedirs("results", exist_ok=True)
    with open("results/tuning.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0]))
        w.writeheader()
        w.writerows(out)
    for r in out[:8]:
        print(r)
    print("chosen:", out[0]["config"])


if __name__ == "__main__":
    main()
