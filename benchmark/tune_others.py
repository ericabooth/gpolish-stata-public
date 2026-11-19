"""Tune ggrepel and adjustText on the same tuning scenarios, with the same objective, as tune.py tuned gpolish.

tune.py chose gpolish ptlabel's six placement settings from 566 candidates on the tuning scenarios
(data/manifest_tuning.csv: synthetic seeds 101 to 110 of the three designs, 30 graphs, never used for
reporting), by the mean over the three designs of the share of labels that are clean and within 3 ems of
their point. This script gives ggrepel and adjustText a search of about the same size on the same 30
graphs with the same objective and the same scoring rule (score.py), so that the benchmark can report
each of them tuned beside its defaults.

  ggrepel     the informed call of run_ggrepel.R (every point given, point.size set to the marker size,
              max.overlaps = Inf, max.iter = 10000, max.time = Inf, seed 12345), with 256 settings in two
              stages (GG_STAGES): box.padding x point.padding x force x force_pull (lengths in lines)
  adjustText  the call of run_adjusttext.py (every point given, time_lim=None), with a grid of 512
              settings: expand x force_text x force_static x force_pull x iter_lim. force_text,
              force_static and force_pull are adjustText's default (x, y) pairs times a factor

The best setting of each is the one with the highest objective on the tuning scenarios; ties go to the
setting listed first in the grid. Nothing from the test scenarios is used. Writes
results/tuning_ggrepel.csv and results/tuning_adjusttext.csv (every setting, best first) and
results/tuned_settings.md (the chosen settings, to be passed to run_ggrepel.R as BENCH_GG_PARMS and to
run_adjusttext.py as BENCH_AT_PARMS; extra.py reads them from there).

Run from the benchmark folder after make_synthetic.py and
    BENCH_SETS=tuning BENCH_METHODS=default stata-mp -b do run_stata.do
(which draws the tuning graphs with Stata's own labels, to fix their plot geometry):
    python tune_others.py [ggrepel|adjusttext ...] [--workers N] [--budget seconds]
Each setting's output goes to out/tune_ggrepel/<tag>/ or out/tune_adjusttext/<tag>/; a setting whose
output exists is not drawn again.
"""
import concurrent.futures as cf
import csv
import itertools
import os
import statistics as st
import subprocess
import sys
import time
from common import data, geometry, Measurer
import score

NEAR_EM = 3.0
# ggrepel in two stages. Stage 1 was planned as box.padding 0 to 1 lines, but a ggrepel run with
# box.padding 0.5 or more took 15 to 30 minutes for the 30 tuning graphs (it runs its full 10,000
# iterations without settling), so stage 1 was cut to box.padding 0, 0.1 and 0.25 (240 settings). Its best
# setting had box.padding and force at the top of their ranges, so stage 2 extends both around it.
GG_STAGES = [
    {"box.padding": [0, 0.1, 0.25], "point.padding": [0, 0.1, 0.25, 0.5, 1.0],
     "force": [0.5, 1, 2, 4], "force_pull": [0.25, 0.5, 1, 2]},
    {"box.padding": [0.35, 0.5], "point.padding": [0, 0.1], "force": [4, 8], "force_pull": [0.5, 1]},
]
AT_EXPAND = [(1.0, 1.0), (1.05, 1.2), (1.1, 1.4), (1.2, 1.6)]
AT_FACTOR = [0.5, 1, 2, 4]
AT_ITER = [100, 300]
AT_DEFAULT = {"force_text": (0.1, 0.2), "force_static": (0.1, 0.2), "force_pull": (0.01, 0.01)}


def fnum(v):
    return f"{v:g}"


def gg_configs():
    for stage, grid in enumerate(GG_STAGES, 1):
        yield from gg_stage(stage, grid)


def gg_stage(stage, grid):
    keys = list(grid)
    for vals in itertools.product(*grid.values()):
        p = dict(zip(keys, vals))
        tag = "_".join(f"{k.replace('.', '')}{fnum(v)}" for k, v in p.items())
        yield tag, dict(p, stage=stage), ";".join(f"{k}={fnum(v)}" for k, v in p.items())


def at_configs():
    for e, ft, fs, fp, it in itertools.product(AT_EXPAND, AT_FACTOR, AT_FACTOR, AT_FACTOR, AT_ITER):
        p = {"expand": e, "force_text": tuple(fnum(ft * v) for v in AT_DEFAULT["force_text"]),
             "force_static": tuple(fnum(fs * v) for v in AT_DEFAULT["force_static"]),
             "force_pull": tuple(fnum(fp * v) for v in AT_DEFAULT["force_pull"]), "iter_lim": it}
        tag = f"e{fnum(e[0])}-{fnum(e[1])}_ft{fnum(ft)}_fs{fnum(fs)}_fp{fnum(fp)}_it{it}"
        env = ";".join([f"expand={fnum(e[0])},{fnum(e[1])}", f"force_text={','.join(p['force_text'])}",
                        f"force_static={','.join(p['force_static'])}", f"force_pull={','.join(p['force_pull'])}",
                        f"iter_lim={it}"])
        yield tag, dict(expand=f"{fnum(e[0])},{fnum(e[1])}", text_factor=ft, static_factor=fs, pull_factor=fp,
                        iter_lim=it), env


def draw(tool, tag, env_parms):
    d = os.path.join("out", f"tune_{tool}", tag)
    if os.path.exists(os.path.join(d, "timing_tuning.csv")):      # written last
        return
    os.makedirs(d, exist_ok=True)
    env = dict(os.environ, BENCH_SETS="tuning", BENCH_OUTDIR=d)
    env.pop("BENCH_SCENARIOS", None)
    if tool == "ggrepel":
        env.update(BENCH_METHODS="ggrepel_tuned", BENCH_GG_PARMS=env_parms)
        cmd = ["Rscript", "run_ggrepel.R"]
    else:
        env.update(BENCH_AT_METHOD="adjusttext_tuned", BENCH_AT_PARMS=env_parms)
        env.pop("BENCH_METHODS", None)
        cmd = [sys.executable, "run_adjusttext.py"]
    r = subprocess.run(cmd, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if r.returncode or not os.path.exists(os.path.join(d, "results_tuning.csv")):
        raise SystemExit(f"{tool} {tag} failed:\n{r.stderr[-2000:]}")


def score_dir(tool, tag):
    """Mean clean-and-near share, clean share and seconds per design, scored as score.py scores."""
    d = os.path.join("out", f"tune_{tool}", tag)
    man = {r["scenario"]: r for r in csv.DictReader(open("data/manifest_tuning.csv"))}
    res, secs = {}, {}
    for r in csv.DictReader(open(os.path.join(d, "results_tuning.csv"), encoding="utf-8")):
        res.setdefault(r["scenario"], []).append(r)
    for r in csv.DictReader(open(os.path.join(d, "timing_tuning.csv"), encoding="utf-8")):
        secs[r["scenario"]] = float(r["seconds"])
    by = {}
    for scen, m in man.items():
        g = geometry(scen)
        rows = data(scen)
        labels = {r["label"] for r in rows if r["lab"]}
        meas = Measurer(g["W"], g["H"])
        boxes = {}
        for r in res[scen]:
            if r["label"] not in labels:
                continue
            if tool == "ggrepel":
                boxes[r["label"]] = score.ggrepel_box(meas, r["label"], float(r["cx"]), float(r["cy"]),
                                                      float(r.get("vjust") or 0.5), r.get("by"))
            else:
                boxes[r["label"]] = meas.box(r["label"], float(r["tx"]), float(r["ty"]), ha=r["ha"], va=r["va"])
        meas.close()
        pts = [(g["xA"] + g["xB"] * r["x"], g["yA"] + g["yB"] * r["y"]) for r in rows]
        idx = {r["label"]: i for i, r in enumerate(rows)}
        sc = score.score_graph(boxes, pts, idx, None, (g["px0"], g["py0"], g["px1"], g["py1"]))
        n = len(labels)
        by.setdefault(m["design"], []).append((sum(r["clean_near"] for r in sc) / n, sum(r["clean"] for r in sc) / n,
                                               st.mean(r["dist_em"] for r in sc), secs[scen]))
    return {des: tuple(st.mean(x[k] for x in v) for k in range(4)) for des, v in by.items()}


def tune(tool, workers, budget=None):
    cfgs = list(gg_configs() if tool == "ggrepel" else at_configs())
    print(f"{tool}: {len(cfgs)} settings on the tuning scenarios", flush=True)
    t0 = time.time()

    def job(tag, env):
        if budget and time.time() - t0 > budget:
            return False
        draw(tool, tag, env)
        return True

    with cf.ThreadPoolExecutor(workers) as ex:
        futs = [ex.submit(job, tag, env) for tag, _, env in cfgs]
        done = sum(f.result() for f in futs)
    left = [c[0] for c in cfgs if not os.path.exists(os.path.join("out", f"tune_{tool}", c[0], "timing_tuning.csv"))]
    if left:
        print(f"{tool}: {len(left)} settings still to draw; run again to continue", flush=True)
        return None
    with cf.ProcessPoolExecutor(workers) as ex:
        scored = list(ex.map(score_dir, [tool] * len(cfgs), [c[0] for c in cfgs]))
    out = []
    for order, ((tag, parms, env), res) in enumerate(zip(cfgs, scored)):
        designs = sorted(res)
        out.append(dict(config=tag, order=order, **parms, parms=env,
                        **{f"near_{d}": round(res[d][0], 4) for d in designs},
                        near_mean=round(st.mean(res[d][0] for d in designs), 4),
                        clean_mean=round(st.mean(res[d][1] for d in designs), 4),
                        dist_em=round(st.mean(res[d][2] for d in designs), 3),
                        seconds=round(st.mean(res[d][3] for d in designs), 3)))
    # the objective alone; ties go to the setting listed first in the grid
    out.sort(key=lambda r: (-r["near_mean"], r["order"]))
    with open(f"results/tuning_{tool}.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(out[0]), lineterminator="\n")
        w.writeheader()
        w.writerows(out)
    for r in out[:5]:
        print(r)
    return out


def write_settings():
    lines = ["# Tuned settings for ggrepel and adjustText", "",
             "Written by `tune_others.py`: the setting with the highest mean clean-and-near share on the tuning "
             "scenarios (synthetic seeds 101 to 110), the objective `tune.py` used for `gpolish`.", ""]
    for tool, var in (("ggrepel", "BENCH_GG_PARMS"), ("adjusttext", "BENCH_AT_PARMS")):
        f = f"results/tuning_{tool}.csv"
        if not os.path.exists(f):
            continue
        rows = list(csv.DictReader(open(f)))
        b = rows[0]
        lines += [f"- {tool}: `{var}=\"{b['parms']}\"` (objective {float(b['near_mean']):.4f}, clean share "
                  f"{float(b['clean_mean']):.4f}, {len(rows)} settings)"]
    lines.append("")
    open("results/tuned_settings.md", "w").write("\n".join(lines))


def chosen(tool):
    """The chosen setting string for run_ggrepel.R or run_adjusttext.py."""
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "results", f"tuning_{tool}.csv")) as fh:
        return next(csv.DictReader(fh))["parms"]


def main(argv):
    workers, budget = 8, None
    if "--budget" in argv:          # stop starting new settings after this many seconds (a later run continues)
        i = argv.index("--budget")
        budget = float(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    if "--workers" in argv:
        i = argv.index("--workers")
        workers = int(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    if not os.path.exists("out/stata/geometry_default_tuning.csv"):
        sys.exit("no tuning geometry: run  BENCH_SETS=tuning BENCH_METHODS=default stata-mp -b do run_stata.do  first")
    os.makedirs("results", exist_ok=True)
    for tool in argv or ["ggrepel", "adjusttext"]:
        if tune(tool, workers, budget) is None:
            return
    write_settings()


if __name__ == "__main__":
    main(sys.argv[1:])
