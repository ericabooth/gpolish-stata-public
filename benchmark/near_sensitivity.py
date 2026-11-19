"""How much the clean-and-near ranking depends on its 3-em cutoff.

Clean and near is one of the two headline measures and is also the objective gpolish's settings were
tuned on. Its 3-em cutoff was added after test-set graphs had been seen (README, Tuning). This script
rescores every main-set graph from the archive (results/positions.csv, geometry.csv, points.csv) with
the cutoff at 2, 3, 4 and 6 ems and reports each method's mean clean-and-near share and the order of
the methods in each scenario. Nothing else in the scoring changes, and no setting is chosen from it.
Writes results/near_sensitivity.md.  Run from the benchmark folder after score.py:
    python near_sensitivity.py
"""
import statistics as st
import score
from summarize import DESIGNS, METHODS, NAMES

CUTOFFS = [2.0, 3.0, 4.0, 6.0]


def main():
    arch = score.load_archive()
    res = {}
    for c in CUTOFFS:
        for r in score.score_all(*arch, sets={"main"}, near_em=c)[1]:
            res.setdefault((c, r["design"], r["method"]), []).append(float(score.fmt(r["clean_near_share"])))
    methods = [m for m in METHODS if any(k[2] == m for k in res)]
    designs = [(d, n) for d, n in DESIGNS if any(k[1] == d for k in res)]
    mean = {k: st.mean(v) for k, v in res.items()}
    out = ["# Label-placement benchmark: sensitivity to the 3-em cutoff", "",
           "Main set. Each cell gives a method's mean clean-and-near share with the cutoff at "
           + ", ".join(f"{c:g}" for c in CUTOFFS) + " ems, in that order. The 3-em value matches results/summary.md.", "",
           "| Scenario | " + " | ".join(NAMES[m] for m in methods) + " |", "|---|" + "---|" * len(methods)]
    for d, dname in designs:
        cells = [" / ".join(f"{mean[(c, d, m)]:.2f}" if (c, d, m) in mean else "nan" for c in CUTOFFS)
                 for m in methods]
        out.append(f"| {dname} | " + " | ".join(cells) + " |")
    out += ["", "## Order of the methods", "",
            "Methods ranked by unrounded mean share, highest first. Ties at four decimals are joined with =.", "",
            "| Scenario | Cutoff (em) | Order | Same as at 3 ems |", "|---|---|---|---|"]
    changed = 0
    for d, dname in designs:
        def order(c):
            ms = sorted((m for m in methods if (c, d, m) in mean), key=lambda m: -mean[(c, d, m)])
            txt, prev = "", None
            for m in ms:
                v = round(mean[(c, d, m)], 4)
                txt += ("" if prev is None else (" = " if v == prev else " > ")) + NAMES[m]
                prev = v
            return txt
        base = order(3.0)
        for c in CUTOFFS:
            o = order(c)
            same = o == base
            changed += not same
            out.append(f"| {dname} | {c:g} | {o} | {'yes' if same else 'no'} |")
    out += ["", f"Rows whose order differs from the 3-em order: {changed}.", ""]
    open("results/near_sensitivity.md", "w").write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
