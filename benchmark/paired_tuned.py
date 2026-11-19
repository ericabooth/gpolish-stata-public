"""Paired seed differences between gpolish and the tuned columns.

Reads results/graphs.csv and results/extra/graphs_tuned.csv, prints, for each
synthetic design, gpolish's share minus the tuned method's share over the 20
test seeds (mean, 95 percent t interval, seeds higher/equal/lower), and with
--check stops if the figures quoted in the READMEs, help and CHANGELOG change.

Author: Eric A. Booth.
"""
import sys
import numpy as np
import pandas as pd
from scipy import stats

QUOTED = {  # (design, method, measure): (mean, lo, hi)
    ("syn30all", "ggrepel_tuned", "clean_share"): (0.008, -0.008, 0.025),
    ("syn60sub", "ggrepel_tuned", "clean_share"): (0.070, 0.033, 0.107),
    ("syn60all", "ggrepel_tuned", "clean_share"): (0.032, 0.002, 0.062),
    ("syn60all", "ggrepel_tuned", "clean_near_share"): (0.014, -0.019, 0.048),
}

g = pd.read_csv("results/graphs.csv")
t = pd.read_csv("results/extra/graphs_tuned.csv")
a = pd.concat([g[g.set == "main"], t[t.set == "main"]])
bad = 0
for d in ["syn30all", "syn60sub", "syn60all"]:
    for o in ["ggrepel_tuned", "adjusttext_tuned"]:
        for k in ["clean_share", "clean_near_share"]:
            s = lambda m: a[(a.design == d) & (a.method == m)].set_index("seed")[k]
            x = (s("gpolish") - s(o)).dropna()
            n = len(x)
            h = stats.t.ppf(0.975, n - 1) * x.std() / np.sqrt(n)
            r = (round(x.mean(), 3), round(x.mean() - h, 3), round(x.mean() + h, 3))
            print(d, o, k, *r, (x > 1e-9).sum(), (x.abs() < 1e-9).sum(), (x < -1e-9).sum())
            q = QUOTED.get((d, o, k))
            if q and any(abs(u - v) > 0.0005 for u, v in zip(r, q)):
                print("  differs from quoted", q); bad += 1
if "--check" in sys.argv and bad:
    sys.exit(1)
