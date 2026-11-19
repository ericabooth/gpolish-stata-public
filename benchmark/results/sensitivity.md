# Sensitivity to the hand-set constants

Written by `sensitivity.py`. Tuning scenarios only (synthetic seeds 101 to 110 of the three designs, 30 graphs). Each row changes one constant of `src/gpolish.ado` and keeps everything else, including the six tuned settings. Shares are means over the three designs; the change is against the unchanged code (clean and near 0.941, clean 0.958). These runs report; no setting was chosen from them.

| Constant | Value in src | Value tried | Clean and near | Change | Clean | Change | Mean distance (em) |
|---|---|---|---|---|---|---|---|
| obstacle | 2 | 1 | 0.930 | -0.011 | 0.947 | -0.011 | 0.85 |
| obstacle | 2 | 4 | 0.957 | +0.016 | 0.972 | +0.014 | 0.85 |
| labels | 4 | 2 | 0.942 | +0.002 | 0.959 | +0.001 | 0.85 |
| labels | 4 | 8 | 0.943 | +0.003 | 0.962 | +0.004 | 0.85 |
| edge | 1000 | 500 | 0.941 | +0.000 | 0.958 | +0.000 | 0.85 |
| edge | 1000 | 2000 | 0.941 | +0.000 | 0.958 | +0.000 | 0.85 |
| position | 1 | 0.5 | 0.945 | +0.004 | 0.960 | +0.002 | 0.84 |
| position | 1 | 2 | 0.948 | +0.007 | 0.964 | +0.006 | 0.87 |
| lead_lab | 2 | 1 | 0.944 | +0.003 | 0.966 | +0.008 | 0.86 |
| lead_lab | 2 | 4 | 0.941 | +0.000 | 0.959 | +0.001 | 0.84 |
| lead_lead | 1.5 | 0.75 | 0.940 | -0.001 | 0.957 | -0.001 | 0.85 |
| lead_lead | 1.5 | 3 | 0.939 | -0.001 | 0.958 | +0.000 | 0.85 |
| lead_obs | 0.15 | 0.075 | 0.940 | -0.001 | 0.958 | +0.001 | 0.85 |
| lead_obs | 0.15 | 0.3 | 0.942 | +0.002 | 0.961 | +0.003 | 0.85 |
| trigger | 0.02 | 0.01 | 0.954 | +0.014 | 0.971 | +0.013 | 0.85 |
| trigger | 0.02 | 0.04 | 0.928 | -0.012 | 0.948 | -0.010 | 0.84 |
| dirs | 22.5 | 45 | 0.928 | -0.012 | 0.944 | -0.013 | 0.85 |
| dirs | 22.5 | 11.25 | 0.951 | +0.010 | 0.966 | +0.008 | 0.85 |
| passes | 4 | 1 | 0.932 | -0.008 | 0.949 | -0.009 | 0.85 |
| passes | 4 | 2 | 0.935 | -0.006 | 0.951 | -0.007 | 0.84 |
| passes | 4 | 3 | 0.939 | -0.001 | 0.958 | +0.000 | 0.85 |
| passes | 4 | 5 | 0.939 | -0.001 | 0.957 | -0.001 | 0.85 |
| passes | 4 | 6 | 0.943 | +0.002 | 0.959 | +0.002 | 0.85 |
| passes | 4 | 7 | 0.942 | +0.002 | 0.959 | +0.002 | 0.85 |
| passes | 4 | 8 | 0.943 | +0.003 | 0.960 | +0.002 | 0.85 |

Largest change in the mean clean share from halving or doubling one cost constant: 0.014; over every row: 0.014 (obstacle_4).

## Convergence of the four passes

The search always runs four passes. A label moved in the fourth pass is one whose drawn position differs between the 3-pass and the 4-pass drawing; the same comparison is made for 4 against 8 passes.

| Design | Labels | Moved in pass 4 | Share | Differ, 8 passes against 4 | Share |
|---|---|---|---|---|---|
| all | 1100 | 20 | 0.018 | 14 | 0.013 |
| syn30all | 300 | 1 | 0.003 | 0 | 0.000 |
| syn60all | 600 | 19 | 0.032 | 14 | 0.023 |
| syn60sub | 200 | 0 | 0.000 | 0 | 0.000 |

Eight passes against four: mean clean share 0.960 against 0.958 (+0.002); clean and near 0.943 against 0.941 (+0.003).
