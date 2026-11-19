"""Further runs of the benchmark, each in its own working copy, with results in results/extra/.

The main pipeline (README, "Running it") fixes every method's settings. These runs change one thing
at a time and keep everything else, including the seeds, so their results can be set beside the main
ones. Each run copies this folder's scripts and data/ into out/extra/<run>/, draws only what the run
changes there, scores it with score.py, and copies the rows of the methods it changed to
results/extra/graphs_<run>.csv, positions_<run>.csv and geometry_<run>.csv.

    raised    adjustText with iter_lim=1000 and both ggrepel columns with max.iter=100000 (tenfold
              limits), main set
    fitline   adjustText and informed ggrepel given the fitted line as points every 4 points along it
              (BENCH_LINEPTS=1), the four real-data graphs
    holdout   every method on synthetic seeds 201 to 220 (set "holdout", drawn after the main results
              were fixed) and on the rule-based list of the 12 countries farthest from the fitted line
              (set "rule")
    seeds     ggrepel, informed ggrepel and labrepel on the four real-data graphs with seeds 1 to 20
              instead of 12345 (BENCH_SEED); graphs_seeds.csv has a run_seed column

    python extra.py [run ...]          (default: all four; then writes results/extra/extra.md)
    python extra.py --report           (only rewrites results/extra/extra.md)

STATA names the Stata executable (default stata-mp); BENCH_PLUS is passed on to find labrepel.
Run from the benchmark folder after make_real.do and make_synthetic.py.
"""
import csv
import glob
import os
import shutil
import statistics as st
import subprocess
import sys

HERE = os.path.abspath(os.path.dirname(__file__))
STATA = os.environ.get("STATA", "stata-mp")
REAL = "life12 autosub lifeall autoall"
SCRIPTS = ["common.py", "score.py", "make_synthetic.py", "make_gpolish060.py", "run_adjusttext.py",
           "run_ggrepel.R", "run_stata.do", "make_real.do"]
RUNS = {
    # run: (sets kept, methods kept)
    "raised": ({"main"}, {"adjusttext", "ggrepel", "ggrepel_inf"}),
    "fitline": ({"main"}, {"adjusttext", "ggrepel_inf"}),
    "holdout": ({"holdout", "rule"}, {"default", "labrepel", "gpolish", "gpolish060", "adjusttext", "ggrepel",
                                      "ggrepel_inf"}),
    "seeds": ({"main"}, {"labrepel", "ggrepel", "ggrepel_inf"}),
}
SEEDS = range(1, 21)


def sandbox(run):
    d = os.path.join(HERE, "out", "extra", run)
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    src = os.path.join(HERE, "out", "extra", "src")      # run_stata.do and make_gpolish060.py read ../src
    if not os.path.lexists(src):
        os.symlink(os.path.join(HERE, "..", "src"), src)
    for f in SCRIPTS:
        shutil.copy(os.path.join(HERE, f), d)
    shutil.copytree(os.path.join(HERE, "data"), os.path.join(d, "data"))
    return d


def sh(d, cmd, **env):
    e = dict(os.environ, **{k: str(v) for k, v in env.items()})
    print(f"[{os.path.basename(d)}] {' '.join(cmd)}  {' '.join(f'{k}={v}' for k, v in env.items())}", flush=True)
    r = subprocess.run(cmd, cwd=d, env=e)
    if cmd[0] == STATA:          # Stata -b returns 0 even after an error; read the log
        log = os.path.join(d, os.path.splitext(os.path.basename(cmd[-1]))[0] + ".log")
        tail = open(log, errors="replace").read()[-3000:]
        if "\nr(" in tail.split("end of do-file")[-1] or "end of do-file" not in tail:
            sys.exit(f"Stata step failed; see {log}")
    elif r.returncode:
        sys.exit(f"step failed: {' '.join(cmd)}")


def stata(d, do, **env):
    sh(d, [STATA, "-b", "do", do], **env)


def read(path):
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def write(path, rows, fields=None):
    if not rows:
        return
    with open(path, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields or list(rows[0]))
        w.writeheader()
        w.writerows(rows)


def keep(d, run, extra=None):
    """The rows of the methods and sets this run changed, from the working copy's results/."""
    sets, meths = RUNS[run]
    out = {}
    for name in ("graphs", "positions", "geometry"):
        rows = [r for r in read(os.path.join(d, "results", f"{name}.csv"))
                if r["set"] in sets and r["method"] in meths]
        if extra:
            rows = [dict(extra, **r) for r in rows]
        out[name] = rows
    if run == "holdout":
        out["points"] = [r for r in read(os.path.join(d, "results", "points.csv")) if r["set"] in sets]
    return out


def score(d, **env):
    sh(d, [sys.executable, "score.py"], **env)


def run_raised(d):
    stata(d, "run_stata.do", BENCH_METHODS="default", BENCH_SETS="main")
    sh(d, [sys.executable, "run_adjusttext.py", "1000"], BENCH_SETS="main")
    sh(d, ["Rscript", "run_ggrepel.R"], BENCH_SETS="main", BENCH_MAXITER=100000)
    score(d, BENCH_SETS="main")
    return keep(d, "raised")


def run_fitline(d):
    stata(d, "run_stata.do", BENCH_METHODS="default", BENCH_SETS="main", BENCH_SCENARIOS=REAL)
    sh(d, [sys.executable, "run_adjusttext.py"], BENCH_SETS="main", BENCH_SCENARIOS=REAL, BENCH_LINEPTS=1)
    sh(d, ["Rscript", "run_ggrepel.R"], BENCH_SETS="main", BENCH_SCENARIOS=REAL, BENCH_METHODS="ggrepel_inf",
       BENCH_LINEPTS=1)
    score(d, BENCH_SETS="main", BENCH_SCENARIOS=REAL)
    return keep(d, "fitline")


def run_holdout(d):
    stata(d, "make_real.do", BENCH_EXTRA=1)
    sh(d, [sys.executable, "make_synthetic.py"], BENCH_EXTRA=1)
    sh(d, [sys.executable, "make_gpolish060.py"])
    stata(d, "run_stata.do", BENCH_SETS="holdout rule")
    stata(d, "run_stata.do", BENCH_SETS="holdout rule", BENCH_METHODS="gpolish060")
    sh(d, [sys.executable, "run_adjusttext.py"], BENCH_SETS="holdout rule")
    sh(d, ["Rscript", "run_ggrepel.R"], BENCH_SETS="holdout rule")
    score(d, BENCH_SETS="holdout rule")
    return keep(d, "holdout")


def run_seeds(d):
    stata(d, "run_stata.do", BENCH_METHODS="default", BENCH_SETS="main", BENCH_SCENARIOS=REAL)
    out = {}
    for s in SEEDS:
        stata(d, "run_stata.do", BENCH_METHODS="labrepel", BENCH_SETS="main", BENCH_SCENARIOS=REAL, BENCH_SEED=s)
        sh(d, ["Rscript", "run_ggrepel.R"], BENCH_SETS="main", BENCH_SCENARIOS=REAL, BENCH_SEED=s)
        score(d, BENCH_SETS="main", BENCH_SCENARIOS=REAL)
        for k, v in keep(d, "seeds", {"run_seed": s}).items():
            out.setdefault(k, []).extend(v)
    return out


def report():
    """results/extra/extra.md: mean shares by scenario or design and method, beside the main results."""
    res = os.path.join(HERE, "results")
    main = read(os.path.join(res, "graphs.csv"))
    names = {"life12": "Life expectancy, 12 of 63", "autosub": "Auto, 19 of 74", "lifeall": "Life expectancy, all 63",
             "autoall": "Auto, all 74", "syn30all": "Synthetic, 30 of 30", "syn60sub": "Synthetic, 20 of 60",
             "syn60all": "Synthetic, 60 of 60", "liferes12": "Life expectancy, 12 farthest from the line"}
    order = list(names)
    cols = ["default", "labrepel", "gpolish", "gpolish060", "adjusttext", "ggrepel", "ggrepel_inf"]
    head = {"default": "`mlabel()`", "labrepel": "`labrepel`", "gpolish": "`gpolish`", "gpolish060": "`gpolish` 0.6.0",
            "adjusttext": "adjustText", "ggrepel": "ggrepel", "ggrepel_inf": "ggrepel (informed)"}

    def means(rows, sets):
        by = {}
        for r in rows:
            if r["set"] in sets:
                by.setdefault((r["design"], r["method"]), []).append(
                    (float(r["clean_share"]), float(r["clean_near_share"])))
        return {k: (st.mean(a for a, _ in v), st.mean(b for _, b in v), len(v)) for k, v in by.items()}

    def table(cells, designs, meths, note=""):
        out = ["| Scenario | " + " | ".join(head[m] + note for m in meths) + " |", "|---" * (len(meths) + 1) + "|"]
        for des in designs:
            out.append(f"| {names.get(des, des)} | " + " | ".join(
                f"{cells[(des, m)][0]:.2f} / {cells[(des, m)][1]:.2f}" if (des, m) in cells else "" for m in meths) + " |")
        return out

    mm = means(main, {"main"})
    L = ["# Further runs", "",
         "Written by `extra.py`. Each cell is the clean share / clean-and-near share (synthetic designs: mean over "
         "seeds). The main run's values for the same methods are shown for comparison; every setting not named "
         "is the same as in the main run.", ""]
    f = os.path.join(res, "extra", "graphs_raised.csv")
    if os.path.exists(f):
        rr = means(read(f), {"main"})
        L += ["## Raised iteration limits", "",
              "adjustText `iter_lim=1000` (main run 100); both ggrepel columns `max.iter = 100000` (main run 10000). "
              "`gpolish` is from the main run.", ""]
        cells = {(d, m + "_r"): v for (d, m), v in rr.items()}
        cells.update(mm)
        for m in ("adjusttext", "ggrepel", "ggrepel_inf"):
            head[m + "_r"] = head[m] + ", raised"
        L += table(cells, [d for d in order if (d, "gpolish") in mm],
                   ["gpolish", "adjusttext", "adjusttext_r", "ggrepel", "ggrepel_r", "ggrepel_inf", "ggrepel_inf_r"]) + [""]
        it = {}
        for r in read(os.path.join(res, "extra", "geometry_raised.csv")):
            if r.get("iterations", "") != "":
                it.setdefault(r["method"], []).append(float(r["iterations"]))
        for m, v in sorted(it.items()):
            L.append(f"- {head[m]}: iterations {min(v):,.0f} to {max(v):,.0f} (median {st.median(v):,.0f}) over {len(v)} graphs.")
        L.append("")
    f = os.path.join(res, "extra", "graphs_fitline.csv")
    if os.path.exists(f):
        fl = means(read(f), {"main"})
        L += ["## Fitted line given as an obstacle", "",
              "adjustText and informed ggrepel are given the fitted line as extra points every 4 points along it "
              "(`BENCH_LINEPTS=1`), so their labels avoid the line as `gpolish`'s do. Only the four real-data graphs "
              "have a fitted line.", ""]
        cells = {(d, m + "_l"): v for (d, m), v in fl.items()}
        cells.update(mm)
        head["adjusttext_l"] = "adjustText, line given"
        head["ggrepel_inf_l"] = "ggrepel (informed), line given"
        L += table(cells, ["life12", "autosub", "lifeall", "autoall"],
                   ["gpolish", "adjusttext", "adjusttext_l", "ggrepel_inf", "ggrepel_inf_l"]) + [""]
    f = os.path.join(res, "extra", "graphs_holdout.csv")
    if os.path.exists(f):
        rows = read(f)
        ho = means(rows, {"holdout"})
        ru = means(rows, {"rule"})
        L += ["## Holdout seeds and a rule-based subset", "",
              "Synthetic seeds 201 to 220 of the three designs (20 graphs each), drawn after the main results were "
              "fixed, and the 12 countries farthest from the fitted line (largest absolute residual), a rule fixed "
              "before the run. Every method at the main run's settings.", ""]
        L += table({**ho, **ru}, ["syn30all", "syn60sub", "syn60all", "liferes12"], cols) + [""]
    f = os.path.join(res, "extra", "graphs_seeds.csv")
    if os.path.exists(f):
        rows = read(f)
        L += ["## Random seeds", "",
              "ggrepel, informed ggrepel and `labrepel` on the four real-data graphs with seeds 1 to 20 (the main "
              "run uses 12345). Clean share: median (minimum to maximum) over the 20 seeds, then the main run's "
              "value for that method and `gpolish`'s, which has no random seed.", ""]
        L += ["| Scenario | Method | Median clean | Range | Seed 12345 | `gpolish` | Median clean and near | Range |",
              "|---|---|---|---|---|---|---|---|"]
        for des in ["life12", "autosub", "lifeall", "autoall"]:
            for m in ("labrepel", "ggrepel", "ggrepel_inf"):
                v = [float(r["clean_share"]) for r in rows if r["design"] == des and r["method"] == m]
                w = [float(r["clean_near_share"]) for r in rows if r["design"] == des and r["method"] == m]
                if not v:
                    continue
                L.append(f"| {names[des]} | {head[m]} | {st.median(v):.2f} | {min(v):.2f} to {max(v):.2f} | "
                         f"{mm[(des, m)][0]:.2f} | {mm[(des, 'gpolish')][0]:.2f} | {st.median(w):.2f} | "
                         f"{min(w):.2f} to {max(w):.2f} |")
        L.append("")
    with open(os.path.join(res, "extra", "extra.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))
    print("results/extra/extra.md written")


def main(argv):
    if argv[:1] != ["--report"]:
        runs = argv or list(RUNS)
        os.makedirs(os.path.join(HERE, "results", "extra"), exist_ok=True)
        for run in runs:
            d = sandbox(run)
            out = globals()[f"run_{run}"](d)
            for name, rows in out.items():
                write(os.path.join(HERE, "results", "extra", f"{name}_{run}.csv"), rows)
            print(run, len(out["graphs"]), "graph rows kept", flush=True)
    report()


if __name__ == "__main__":
    main(sys.argv[1:])
