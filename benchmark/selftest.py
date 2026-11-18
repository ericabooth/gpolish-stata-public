"""Regression checks for the benchmark pipeline itself (not for the placement results).

Works on a copy of this folder in a temporary directory, so data/, out/ and results/ here are
left alone. It needs a finished run (data/ and out/ present). It checks that:
  1. run_adjusttext.py gives identical label positions on two runs;
  2. score.py, summarize.py, marker_sensitivity.py and score.py --check still work when a
     method (labrepel) was skipped, and leave that method out;
  3. with a Stata executable given, run_stata.do uses this package's src copy of gpolish even
     when BENCH_PLUS names a folder holding another gpolish, and labrepel's result for a graph
     does not depend on which scenarios ran before it.
Run from the benchmark folder:  python selftest.py [stata executable]
"""
import filecmp
import glob
import os
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
    return subprocess.run(cmd, cwd=cwd, env=e, capture_output=True, text=True)


def copy_bench(root):
    bench = os.path.join(root, "benchmark")
    os.makedirs(bench)
    for f in glob.glob(os.path.join(HERE, "*.py")) + glob.glob(os.path.join(HERE, "*.do")) \
            + glob.glob(os.path.join(HERE, "*.R")):
        shutil.copy(f, bench)
    shutil.copytree(os.path.join(HERE, "data"), os.path.join(bench, "data"))
    shutil.copytree(os.path.join(HERE, "out"), os.path.join(bench, "out"))
    os.makedirs(os.path.join(bench, "results"))
    shutil.copytree(os.path.join(HERE, "..", "src"), os.path.join(root, "src"))
    return bench


def main():
    stata = sys.argv[1] if len(sys.argv) > 1 else None
    for need in ("data/manifest_real.csv", "out/stata/geometry_default.csv"):
        if not os.path.exists(os.path.join(HERE, need)):
            sys.exit(f"{need} is missing: run the benchmark first")
    with tempfile.TemporaryDirectory() as root:
        bench = copy_bench(root)

        # 1. adjustText is deterministic
        env = {"BENCH_SCENARIOS": "lifeall life12"}
        r1 = run([PY, "run_adjusttext.py"], bench, env)
        check(r1.returncode == 0 and "iter_lim=100, time_lim=None" in r1.stdout, "run_adjusttext.py runs with iter_lim=100 and no time limit")
        shutil.copy(os.path.join(bench, "out/adjusttext/results.csv"), os.path.join(root, "at1.csv"))
        r2 = run([PY, "run_adjusttext.py"], bench, env)
        check(r2.returncode == 0 and filecmp.cmp(os.path.join(root, "at1.csv"),
                                                 os.path.join(bench, "out/adjusttext/results.csv"), shallow=False),
              "two adjustText runs give identical label positions")
        # the rest of the checks use the full adjustText output again
        shutil.rmtree(os.path.join(bench, "out/adjusttext"))
        shutil.copytree(os.path.join(HERE, "out/adjusttext"), os.path.join(bench, "out/adjusttext"))

        # 2. a skipped method
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

        # 3. Stata: the gpolish under test, and labrepel's seed
        if stata:
            decoy = os.path.join(root, "decoy", "g")
            os.makedirs(decoy)
            with open(os.path.join(decoy, "gpolish.ado"), "w") as fh:
                fh.write("*! gpolish decoy\nprogram gpolish\n    di as err \"decoy gpolish ran\"\n    exit 499\nend\n")
            env = {"BENCH_SCENARIOS": "life12", "BENCH_METHODS": "gpolish", "BENCH_PLUS": os.path.dirname(decoy)}
            run([stata, "-b", "do", "run_stata.do"], bench, env)
            log = open(os.path.join(bench, "run_stata.log"), encoding="utf-8", errors="replace").read()
            check("stata benchmark done" in log and "*! gpolish 0." in log and "gpolish decoy" not in log
                  and "decoy gpolish ran" not in log,
                  "run_stata.do uses src's gpolish when BENCH_PLUS holds another copy")
            svgs, installed = [], True
            for scen in ("life12 syn60all_s01 syn60all_s02", "syn60all_s02"):
                run([stata, "-b", "do", "run_stata.do"], bench,
                    {"BENCH_SCENARIOS": scen, "BENCH_METHODS": "labrepel"})
                log = open(os.path.join(bench, "run_stata.log"), encoding="utf-8", errors="replace").read()
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
