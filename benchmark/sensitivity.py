"""Sensitivity of gpolish ptlabel to its hand-set constants, and convergence of its four passes.

Besides the six tuned settings in _gpl_placeparms(), the placement search in src/gpolish.ado uses
constants that were set by hand during development, with the benchmark in view, and were not tuned:
    obstacle   weight 2 on overlap with markers, lines and other obstacles     (_gpl_hard)
    labels     weight 4 on overlap with other labels                            (_gpl_hard)
    edge       weight 1000 on a box beyond the plot region                      (_gpl_hard)
    position   the penalties 0.15 to 0.5 label heights squared of the eight adjacent spots (_gpl_place)
    lead_lab   2 label heights squared per label box a leader line crosses      (_gpl_leadcost)
    lead_lead  1.5 per other leader line it crosses                             (_gpl_leadcost)
    lead_obs   0.15 per obstacle it crosses                                     (_gpl_leadcost)
    trigger    a leader is tried when the best adjacent spot's overlap exceeds 2 percent of its box
    dirs       16 directions on each ring (every 22.5 degrees)
    passes     4 passes over the labels, with no other stopping rule
(The 35 percent threshold only decides which labels the note reports as still overlapping; it does not
move any label, so it is not varied.)
Each constant is halved and doubled on its own (directions: 8 and 32; passes: 1, 2, 3, 5, 6, 7 and 8), with
everything else as in src. Every variant draws the 30 tuning scenarios (seeds 101 to 110, never the
test seeds) with tune.do and is scored as tune.py scores them. This run reports; it does not choose
settings, and src/gpolish.ado is not changed.
Convergence: the search is deterministic, so a label moved in the fourth pass is a label whose position
differs between the 3-pass and the 4-pass drawing. The same comparison is made for 4 against 8 passes.
Writes results/sensitivity.csv and results/sensitivity.md.  Run from the benchmark folder after
make_synthetic.py:   python sensitivity.py [stata executable] [parallel workers] [--only variant,variant]
With --only, only the named variants are drawn and scored; their rows replace or join the rows already in
results/sensitivity.csv, and the convergence section of results/sensitivity.md is kept from the full run.
With more than one worker, graph set svg fontface must already be Open Sans (as for tune.py).
"""
import concurrent.futures as cf
import csv
import html
import os
import re
import statistics as st
import subprocess
import sys

import score
import tune

ONLY = None
if "--only" in sys.argv:
    i = sys.argv.index("--only")
    ONLY = set(sys.argv[i + 1].split(","))
    del sys.argv[i:i + 2]
STATA = sys.argv[1] if len(sys.argv) > 1 else "stata-mp"
WORKERS = int(sys.argv[2]) if len(sys.argv) > 2 else 4

# name: (function whose text is changed, text, format of the replacement with {v}, value in src)
CONSTS = {
    "obstacle": ("_gpl_hard", "hardc = 2*(_gpl_obscost", "hardc = {v}*(_gpl_obscost", 2),
    "labels": ("_gpl_hard", "hardc + 4*sum(", "hardc + {v}*sum(", 4),
    "edge": ("_gpl_hard", "1000*", "{v}*", 1000),
    "position": ("_gpl_place", "c = hardc + C[k,5]*h*h", "c = hardc + {v}*C[k,5]*h*h", 1),
    "lead_lab": ("_gpl_leadcost", "c = c + 2*h*h*_gpl_seghitn", "c = c + {v}*h*h*_gpl_seghitn", 2),
    "lead_lead": ("_gpl_leadcost", "c = c + 1.5*h*h", "c = c + {v}*h*h", 1.5),
    "lead_obs": ("_gpl_leadcost", "c = c + 0.15*h*h*_gpl_seghitn(s, O)", "c = c + {v}*h*h*_gpl_seghitn(s, O)", 0.15),
    "trigger": ("_gpl_place", "resid[i] > 0.02*w[i]*h", "resid[i] > {v}*w[i]*h", 0.02),
    "dirs": ("_gpl_place", "a=a+22.5", "a=a+{v}", 22.5),
    "passes": ("_gpl_place", "pass<=4", "pass<={v}", 4),
}
COUNTS = {"edge": 4}          # occurrences expected inside the function; 1 for the others


def variants():
    yield "base", None, None, 1
    for name, (_, _, _, v) in CONSTS.items():
        if name == "passes":
            vals = [1, 2, 3, 5, 6, 7, 8]
        elif name == "dirs":
            vals = [45, 11.25]           # 8 and 32 directions
        else:
            vals = [v / 2, v * 2]
        for x in vals:
            yield f"{name}_{x:g}", name, x, x / v


def function_span(src, fn):
    m = re.search(r"\n[a-z ]+ " + re.escape(fn) + r"\(", src)
    assert m, fn
    end = src.index("\n}\n", m.end())
    return m.start(), end


def write_variant(tag, name, value):
    src = open("../src/gpolish.ado", encoding="utf-8").read()
    if name:
        fn, old, new, _ = CONSTS[name]
        a, b = function_span(src, fn)
        body = src[a:b]
        n = body.count(old)
        assert n == COUNTS.get(name, 1), f"{name}: {old!r} found {n} times in {fn}()"
        src = src[:a] + body.replace(old, new.format(v=f"{value:g}")) + src[b:]
    d = os.path.abspath(f"out/tune/sens_{tag}")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "gpolish.ado"), "w", encoding="utf-8").write(src)
    return d


def draw(tag, name, value):
    d = write_variant(tag, name, value)
    if not os.path.exists(os.path.join(d, "geometry_gpolish.csv")):
        subprocess.run([STATA, "-b", "do", os.path.abspath("tune.do")], cwd=os.getcwd(),
                       env=dict(os.environ, TUNE_DIR=d), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not os.path.exists(os.path.join(d, "geometry_gpolish.csv")):
        raise SystemExit(f"{tag}: tune.do wrote no geometry file")
    return tag


def label_anchors(tag):
    """{(scenario, label): (x, y, anchor)} from the variant's SVGs."""
    out = {}
    man = [r["scenario"] for r in csv.DictReader(open("data/manifest_tuning.csv"))]
    for scen in man:
        labels = {r["label"] for r in tune.data(scen) if r["lab"]}
        svg = open(f"out/tune/sens_{tag}/{scen}__gpolish.svg", encoding="utf-8").read()
        for m in score.TEXT_RE.finditer(svg):
            s = html.unescape(m.group(6))
            if s in labels and (scen, s) not in out:
                out[(scen, s)] = (round(float(m.group(1)), 2), round(float(m.group(2)), 2), m.group(5))
    return out


def moved(a, b):
    """Share of labels whose drawn position differs between variants a and b, by design and overall."""
    pa, pb = label_anchors(a), label_anchors(b)
    des = {r["scenario"]: r["design"] for r in csv.DictReader(open("data/manifest_tuning.csv"))}
    by = {}
    for k in pa:
        by.setdefault(des[k[0]], []).append(pa[k] != pb.get(k))
    allv = [x for v in by.values() for x in v]
    return {d: (sum(v), len(v)) for d, v in by.items()} | {"all": (sum(allv), len(allv))}


def main():
    if WORKERS > 1 and tune.svg_font() != "Open Sans":
        sys.exit("graph set svg fontface is not Open Sans: set it first, or run with 1 worker")
    allvs = list(variants())
    vs = [v for v in allvs if ONLY is None or v[0] in ONLY]
    if ONLY and len(vs) != len(ONLY):
        sys.exit(f"unknown variant in --only: {sorted(ONLY - {v[0] for v in vs})}")
    with cf.ThreadPoolExecutor(WORKERS) as ex:
        list(ex.map(lambda v: draw(v[0], v[1], v[2]), vs))
    with cf.ProcessPoolExecutor(WORKERS) as ex:
        scored = list(ex.map(tune.score_dir, [f"sens_{v[0]}" for v in vs]))
    rows = []
    for (tag, name, value, factor), res in zip(vs, scored):
        designs = sorted(res)
        rows.append(dict(variant=tag, constant=name or "", value="" if value is None else f"{value:g}",
                         factor=f"{factor:g}",
                         **{f"near_{d}": round(res[d][0], 4) for d in designs},
                         near_mean=round(st.mean(res[d][0] for d in designs), 4),
                         **{f"clean_{d}": round(res[d][1], 4) for d in designs},
                         clean_mean=round(st.mean(res[d][1] for d in designs), 4),
                         dist_em=round(st.mean(res[d][2] for d in designs), 3)))
    if ONLY:
        old = {r["variant"]: r for r in csv.DictReader(open("results/sensitivity.csv"))}
        for r in old.values():
            for k in r:
                if k not in ("variant", "constant", "value", "factor"):
                    r[k] = float(r[k])
        new = {r["variant"]: r for r in rows}
        rows = [new.get(v[0]) or old[v[0]] for v in allvs if v[0] in new or v[0] in old]
    with open("results/sensitivity.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    base = rows[0]
    L = ["# Sensitivity to the hand-set constants", "",
         "Written by `sensitivity.py`. Tuning scenarios only (synthetic seeds 101 to 110 of the three designs, 30 "
         "graphs). Each row changes one constant of `src/gpolish.ado` and keeps everything else, including the six "
         "tuned settings. Shares are means over the three designs; the change is against the unchanged code "
         f"(clean and near {base['near_mean']:.3f}, clean {base['clean_mean']:.3f}). These runs report; no setting "
         "was chosen from them.", "",
         "| Constant | Value in src | Value tried | Clean and near | Change | Clean | Change | Mean distance (em) |",
         "|---|---|---|---|---|---|---|---|"]
    for r in rows[1:]:
        L.append(f"| {r['constant']} | {CONSTS[r['constant']][3]:g} | {r['value']} | {r['near_mean']:.3f} | "
                 f"{r['near_mean'] - base['near_mean']:+.3f} | {r['clean_mean']:.3f} | "
                 f"{r['clean_mean'] - base['clean_mean']:+.3f} | {r['dist_em']:.2f} |")
    big = max(rows[1:], key=lambda r: abs(r["clean_mean"] - base["clean_mean"]))
    halfdouble = [r for r in rows[1:] if r["constant"] not in ("passes", "dirs")]
    L += ["", f"Largest change in the mean clean share from halving or doubling one cost constant: "
          f"{max(abs(r['clean_mean'] - base['clean_mean']) for r in halfdouble):.3f}; over every row: "
          f"{abs(big['clean_mean'] - base['clean_mean']):.3f} ({big['variant']}).", ""]
    if ONLY:
        prev = open("results/sensitivity.md", encoding="utf-8").read()
        L.append(prev[prev.index("## Convergence"):].rstrip("\n"))
        L.append("")
        open("results/sensitivity.md", "w", encoding="utf-8").write("\n".join(L))
        print("\n".join(L))
        return
    m34, m48 = moved("passes_3", "base"), moved("base", "passes_8")
    L += ["## Convergence of the four passes", "",
          "The search always runs four passes. A label moved in the fourth pass is one whose drawn position "
          "differs between the 3-pass and the 4-pass drawing; the same comparison is made for 4 against 8 passes.", "",
          "| Design | Labels | Moved in pass 4 | Share | Differ, 8 passes against 4 | Share |", "|---|---|---|---|---|---|"]
    for d in sorted(m34):
        a, n = m34[d]
        b, _ = m48[d]
        L.append(f"| {d} | {n} | {a} | {a / n:.3f} | {b} | {b / n:.3f} |")
    p8 = next(r for r in rows if r["variant"] == "passes_8")
    L += ["", f"Eight passes against four: mean clean share {p8['clean_mean']:.3f} against {base['clean_mean']:.3f} "
          f"({p8['clean_mean'] - base['clean_mean']:+.3f}); clean and near {p8['near_mean']:.3f} against "
          f"{base['near_mean']:.3f} ({p8['near_mean'] - base['near_mean']:+.3f}).", ""]
    open("results/sensitivity.md", "w", encoding="utf-8").write("\n".join(L))
    print("\n".join(L))


if __name__ == "__main__":
    main()
