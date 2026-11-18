"""Regression checks for the benchmark pipeline itself (not for the placement results).

Works on a copy of this folder in a temporary directory, so data/, out/ and results/ here are
left alone. It needs a finished run (data/, out/ and results/ present). It checks that:
  1. run_adjusttext.py gives identical label positions on two runs, and a run of run_adjusttext.py or
     run_ggrepel.R limited to some scenarios reproduces the full run's rows and keeps the others;
     run_adjusttext.py runs while another Stata method's geometry file is still being written; and
     results/geometry.csv records ggrepel's iteration counts and stopping reason;
  2. score.py --rescore, which reads only results/positions.csv, geometry.csv and points.csv,
     gives the same labels.csv and graphs.csv byte for byte as the full scoring run;
  3. score.py, summarize.py, marker_sensitivity.py and score.py --check still work when a
     method (labrepel) was skipped, and leave that method out;
  4. with a Stata executable given: run_stata.do uses this package's src copy of gpolish even
     when BENCH_PLUS names a folder holding another gpolish; gpolish060 uses the 0.6.0-settings
     copy and refuses to share a session with gpolish; gpolish uses its Open Sans width table;
     graph set svg fontface is the same after a run as before it, also when the run stops with an
     error; and labrepel's result for a graph does not depend on which scenarios ran before it.
Run from the benchmark folder:  python selftest.py [stata executable]
"""
import csv
import filecmp
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable
passed = 0


def check(cond, what):
    global passed
    if not cond:
        sys.exit(f"FAILED: {what}")
    passed += 1
    print(f"ok: {what}")


def run(cmd, cwd, env=None):
    e = dict(os.environ, **(env or {}))
    for k in ("BENCH_SCENARIOS", "BENCH_SETS", "BENCH_METHODS"):
        if k not in (env or {}):
            e.pop(k, None)
    return subprocess.run(cmd, cwd=cwd, env=e, capture_output=True, text=True)


def copy_bench(root):
    bench = os.path.join(root, "benchmark")
    os.makedirs(bench)
    for f in glob.glob(os.path.join(HERE, "*.py")) + glob.glob(os.path.join(HERE, "*.do")) \
            + glob.glob(os.path.join(HERE, "*.R")):
        shutil.copy(f, bench)
    for d in ("data", "out", "results"):
        shutil.copytree(os.path.join(HERE, d), os.path.join(bench, d),
                        ignore=shutil.ignore_patterns("*.png", "check_*"))
    shutil.copytree(os.path.join(HERE, "..", "src"), os.path.join(root, "src"))
    return bench


def svg_font(stata, cwd):
    with open(os.path.join(cwd, "font_q.do"), "w") as fh:
        fh.write('mata: st_rclear()\nquietly graph set svg\ndi "SVGFONT=[`r(fontface)\']"\n')
    run([stata, "-b", "do", "font_q.do"], cwd)
    log = open(os.path.join(cwd, "font_q.log"), encoding="utf-8", errors="replace").read()
    m = re.search(r"^SVGFONT=\[(.*)\]", log, re.M)
    return m.group(1) if m else None


def stata_log(bench):
    return open(os.path.join(bench, "run_stata.log"), encoding="utf-8", errors="replace").read()


def main():
    stata = sys.argv[1] if len(sys.argv) > 1 else None
    for need in ("data/manifest_real.csv", "out/stata/geometry_default_main.csv", "results/positions.csv"):
        if not os.path.exists(os.path.join(HERE, need)):
            sys.exit(f"{need} is missing: run the benchmark first")
    with tempfile.TemporaryDirectory() as root:
        bench = copy_bench(root)

        # 1. adjustText is deterministic
        env = {"BENCH_SCENARIOS": "lifeall life12"}
        r1 = run([PY, "run_adjusttext.py"], bench, env)
        check(r1.returncode == 0 and "iter_lim=100, time_lim=None" in r1.stdout, "run_adjusttext.py runs with iter_lim=100 and no time limit")
        shutil.copy(os.path.join(bench, "out/adjusttext/results_main.csv"), os.path.join(root, "at1.csv"))
        r2 = run([PY, "run_adjusttext.py"], bench, env)
        check(r2.returncode == 0 and filecmp.cmp(os.path.join(root, "at1.csv"),
                                                 os.path.join(bench, "out/adjusttext/results_main.csv"), shallow=False),
              "two adjustText runs give identical label positions")
        check(filecmp.cmp(os.path.join(HERE, "out/adjusttext/results_main.csv"),
                          os.path.join(bench, "out/adjusttext/results_main.csv"), shallow=False),
              "a run limited to two scenarios keeps the other scenarios' rows and matches the full run")

        if shutil.which("Rscript"):
            rg = run(["Rscript", "run_ggrepel.R"], bench, {"BENCH_SCENARIOS": "lifeall life12"})
            same = all(filecmp.cmp(os.path.join(HERE, f"out/{m}/results_main.csv"),
                                   os.path.join(bench, f"out/{m}/results_main.csv"), shallow=False)
                       for m in ("ggrepel", "ggrepel_inf"))
            check(rg.returncode == 0 and same,
                  "a ggrepel run limited to two scenarios gives the same label positions and keeps the other rows")
        else:
            print("note: Rscript not found; the ggrepel check is skipped")

        # 1b. adjustText and ggrepel read only the default method's geometry, so another Stata run
        # still writing its own geometry file (here a half-written line) does not stop them
        part = os.path.join(bench, "out/stata/geometry_labrepel_main.csv")
        keep = open(part).read() if os.path.exists(part) else None
        with open(part, "a") as fh:
            fh.write("life12,labrepel,504,331")
        r3 = run([PY, "run_adjusttext.py"], bench, {"BENCH_SCENARIOS": "life12"})
        check(r3.returncode == 0, "run_adjusttext.py runs while another method's geometry file is half written")
        if keep is None:
            os.remove(part)
        else:
            open(part, "w").write(keep)
        geo = list(csv.DictReader(open(os.path.join(HERE, "results/geometry.csv"))))
        gg = [g for g in geo if g["method"] in ("ggrepel", "ggrepel_inf")]
        check(gg and all(g["iterations"] and g["iterations_drawn"] and
                         g["stop"] in ("iteration limit", "settled", "time limit") for g in gg),
              "results/geometry.csv records ggrepel's iterations and why it stopped for every graph")

        # the reruns above wrote new timings; the rest of the checks use the full run's output again
        for m in ("adjusttext", "ggrepel", "ggrepel_inf"):
            shutil.rmtree(os.path.join(bench, "out", m), ignore_errors=True)
            shutil.copytree(os.path.join(HERE, "out", m), os.path.join(bench, "out", m),
                            ignore=shutil.ignore_patterns("*.png"))

        # 2. rescoring from the archive alone
        sc = run([PY, "score.py"], bench)
        same = all(filecmp.cmp(os.path.join(HERE, "results", f), os.path.join(bench, "results", f), shallow=False)
                   for f in ("positions.csv", "geometry.csv", "points.csv", "labels.csv", "graphs.csv"))
        check(sc.returncode == 0 and same, "score.py on the same out/ reproduces every results/ file")
        arch = os.path.join(root, "archive")
        os.makedirs(os.path.join(arch, "results"))
        for f in ("positions.csv", "geometry.csv", "points.csv"):
            shutil.copy(os.path.join(HERE, "results", f), os.path.join(arch, "results", f))
        shutil.copy(os.path.join(bench, "score.py"), arch)
        shutil.copy(os.path.join(bench, "common.py"), arch)
        rs = run([PY, "score.py", "--rescore"], arch)
        same = all(filecmp.cmp(os.path.join(HERE, "results", f), os.path.join(arch, "results", f), shallow=False)
                   for f in ("labels.csv", "graphs.csv"))
        check(rs.returncode == 0 and same, "score.py --rescore with only the three archive files reproduces labels.csv and graphs.csv")

        # 3. a skipped method
        for f in glob.glob(os.path.join(bench, "out/stata/*labrepel*")):
            os.remove(f)
        sc = run([PY, "score.py"], bench)
        check(sc.returncode == 0 and "labrepel" in sc.stdout, "score.py runs and notes the skipped method")
        sm = run([PY, "summarize.py"], bench)
        summary = open(os.path.join(bench, "results/summary.md")).read() if sm.returncode == 0 else ""
        check(sm.returncode == 0 and "labrepel" not in summary and "gpolish" in summary,
              "summarize.py runs and leaves the skipped method out")
        ms = run([PY, "marker_sensitivity.py"], bench)
        check(ms.returncode == 0, "marker_sensitivity.py runs with a skipped method")
        ck = run([PY, "score.py", "--check", "life12"], bench)
        check(ck.returncode == 0 and os.path.exists(os.path.join(bench, "out/check_life12.png")),
              "score.py --check runs with a skipped method")

        # 4. Stata
        if stata:
            before = svg_font(stata, bench)
            decoy = os.path.join(root, "decoy", "g")
            os.makedirs(decoy)
            with open(os.path.join(decoy, "gpolish.ado"), "w") as fh:
                fh.write("*! gpolish decoy\nprogram gpolish\n    di as err \"decoy gpolish ran\"\n    exit 499\nend\n")
            env = {"BENCH_SCENARIOS": "life12", "BENCH_METHODS": "gpolish", "BENCH_PLUS": os.path.dirname(decoy)}
            run([stata, "-b", "do", "run_stata.do"], bench, env)
            log = stata_log(bench)
            check("stata benchmark done" in log and "*! gpolish 0." in log and "gpolish decoy" not in log
                  and "decoy gpolish ran" not in log,
                  "run_stata.do uses src's gpolish when BENCH_PLUS holds another copy")
            check("gpolish width table: open sans" in log, "gpolish measures labels with its Open Sans width table")
            check(svg_font(stata, bench) == before, f"graph set svg fontface is still [{before}] after a run")
            run([stata, "-b", "do", "run_stata.do"], bench, {"BENCH_SCENARIOS": "life12", "BENCH_METHODS": "gpolish060"})
            log = stata_log(bench)
            v = os.path.join(bench, "out", "gpolish060", "gpolish.ado")
            check("stata benchmark done" in log and v in log.replace("\n> ", ""),
                  "gpolish060 runs the 0.6.0-settings copy of gpolish")
            run([stata, "-b", "do", "run_stata.do"], bench, {"BENCH_SCENARIOS": "life12", "BENCH_METHODS": "gpolish gpolish060"})
            check("must be run on its own" in stata_log(bench), "gpolish060 refuses to share a session with gpolish")
            os.rename(os.path.join(bench, "data", "life12.csv"), os.path.join(bench, "data", "life12.bak"))
            run([stata, "-b", "do", "run_stata.do"], bench, {"BENCH_SCENARIOS": "life12", "BENCH_METHODS": "default"})
            os.rename(os.path.join(bench, "data", "life12.bak"), os.path.join(bench, "data", "life12.csv"))
            log = stata_log(bench)
            check("stata benchmark done" not in log and svg_font(stata, bench) == before,
                  f"graph set svg fontface is still [{before}] after a run that stopped with an error")
            svgs, installed = [], True
            for scen in ("life12 syn60all_s01 syn60all_s02", "syn60all_s02"):
                run([stata, "-b", "do", "run_stata.do"], bench,
                    {"BENCH_SCENARIOS": scen, "BENCH_METHODS": "labrepel"})
                log = stata_log(bench)
                installed = installed and not any(ln.startswith("note: labrepel is not installed")
                                                  for ln in log.splitlines())
                f = os.path.join(bench, "out/stata/syn60all_s02__labrepel.svg")
                svgs.append(open(f, "rb").read() if os.path.exists(f) else None)
                if os.path.exists(f):
                    os.remove(f)
            if not installed:
                print("note: labrepel is not installed (set BENCH_PLUS to find it); its seed check is skipped")
            else:
                check(svgs[0] is not None and svgs[0] == svgs[1],
                      "labrepel's result for a graph does not depend on the scenarios run before it")
            for f in glob.glob(os.path.join(bench, "*.log")):
                os.remove(f)
    print(f"{passed} checks passed")


if __name__ == "__main__":
    main()
