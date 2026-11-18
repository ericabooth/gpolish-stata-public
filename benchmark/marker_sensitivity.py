"""How much the scores depend on the marker rule.

score.py counts a label as touching a marker when its box comes closer than 2.75 pt to a data
point (a 6 pt marker's radius less a 0.25 pt tolerance). This script rescores every graph with
that distance set to 2.75 pt, to 3.0 pt (the radius exactly) and to 3.24 pt (the full radius
Stata draws for msize(6pt), white outline included), and reports the clean and clean-and-near
shares of each method at each value.
Writes results/marker_sensitivity.md.  Run from the benchmark folder after score.py:
    python marker_sensitivity.py
"""
import statistics as st
import score
from summarize import DESIGNS, METHODS, NAMES

THRESHOLDS = [(2.75, "2.75 pt (the rule used)"), (3.0, "3.0 pt (the radius)"),
              (3.24, "3.24 pt (Stata's drawn radius)")]


def main():
    res = {}
    for t, _ in THRESHOLDS:
        for r in score.main([], marker_hit=t, write=False):
            res.setdefault((t, r["design"], r["method"]), []).append(r)
    methods = [m for m in METHODS if any(k[2] == m for k in res)]
    designs = [(d, n) for d, n in DESIGNS if any(k[1] == d for k in res)]
    out = ["# Label-placement benchmark: sensitivity to the marker rule", "",
           "Each cell gives a method's mean share for the marker distance "
           + ", ".join(lab for _, lab in THRESHOLDS) + ", in that order.", ""]
    for key, title in (("clean_share", "Clean labels (share)"),
                       ("clean_near_share", "Clean labels within 3 ems of their point (share)")):
        out += [f"## {title}", "", "| Scenario | " + " | ".join(NAMES[m] for m in methods) + " |",
                "|---|" + "---|" * len(methods)]
        for d, dname in designs:
            cells = []
            for m in methods:
                vals = [st.mean(r[key] for r in res[(t, d, m)]) if (t, d, m) in res else float("nan")
                        for t, _ in THRESHOLDS]
                cells.append(" / ".join(f"{v:.2f}" for v in vals))
            out.append(f"| {dname} | " + " | ".join(cells) + " |")
        out.append("")
    open("results/marker_sensitivity.md", "w").write("\n".join(out) + "\n")
    print("\n".join(out))


if __name__ == "__main__":
    main()
