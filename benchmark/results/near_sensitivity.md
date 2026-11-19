# Label-placement benchmark: sensitivity to the 3-em cutoff

Main set. Each cell gives a method's mean clean-and-near share with the cutoff at 2, 3, 4, 6 ems, in that order. The 3-em value matches results/summary.md.

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | gpolish 0.6.0 settings | adjustText (Python) | ggrepel (R) | ggrepel (informed) |
|---|---|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.58 / 0.58 / 0.58 / 0.58 | 0.00 / 0.00 / 0.00 / 0.00 | 1.00 / 1.00 / 1.00 / 1.00 | 0.83 / 0.92 / 0.92 / 0.92 | 0.50 / 0.50 / 0.50 / 0.50 | 0.33 / 0.33 / 0.33 / 0.33 | 0.75 / 0.75 / 0.75 / 0.75 |
| Auto, 19 of 74 labelled | 0.16 / 0.16 / 0.16 / 0.16 | 0.00 / 0.00 / 0.00 / 0.00 | 0.68 / 0.68 / 0.84 / 0.84 | 0.68 / 0.68 / 0.74 / 0.74 | 0.32 / 0.37 / 0.37 / 0.37 | 0.16 / 0.16 / 0.16 / 0.16 | 0.63 / 0.63 / 0.63 / 0.63 |
| Life expectancy, all 63 labelled | 0.24 / 0.24 / 0.24 / 0.24 | 0.00 / 0.02 / 0.02 / 0.02 | 0.49 / 0.63 / 0.67 / 0.75 | 0.57 / 0.59 / 0.68 / 0.73 | 0.21 / 0.24 / 0.25 / 0.29 | 0.44 / 0.56 / 0.56 / 0.57 | 0.49 / 0.59 / 0.63 / 0.67 |
| Auto, all 74 labelled | 0.09 / 0.09 / 0.09 / 0.09 | 0.00 / 0.00 / 0.00 / 0.00 | 0.22 / 0.35 / 0.47 / 0.59 | 0.19 / 0.22 / 0.28 / 0.35 | 0.15 / 0.22 / 0.24 / 0.30 | 0.24 / 0.31 / 0.34 / 0.39 | 0.24 / 0.34 / 0.38 / 0.49 |
| Synthetic, 30 of 30 labelled | 0.61 / 0.61 / 0.61 / 0.61 | 0.10 / 0.32 / 0.45 / 0.46 | 0.98 / 0.99 / 0.99 / 0.99 | 0.93 / 0.95 / 0.95 / 0.95 | 0.58 / 0.59 / 0.60 / 0.60 | 0.58 / 0.58 / 0.58 / 0.59 | 0.95 / 0.95 / 0.95 / 0.95 |
| Synthetic, 20 of 60 labelled | 0.47 / 0.47 / 0.47 / 0.47 | 0.14 / 0.29 / 0.35 / 0.35 | 0.94 / 0.95 / 0.95 / 0.96 | 0.84 / 0.84 / 0.85 / 0.86 | 0.48 / 0.49 / 0.49 / 0.49 | 0.40 / 0.40 / 0.40 / 0.40 | 0.85 / 0.86 / 0.86 / 0.86 |
| Synthetic, 60 of 60 labelled | 0.33 / 0.33 / 0.33 / 0.33 | 0.05 / 0.16 / 0.24 / 0.25 | 0.86 / 0.88 / 0.90 / 0.92 | 0.73 / 0.76 / 0.78 / 0.80 | 0.49 / 0.53 / 0.54 / 0.55 | 0.56 / 0.58 / 0.59 / 0.60 | 0.80 / 0.84 / 0.85 / 0.86 |

## Order of the methods

Methods ranked by unrounded mean share, highest first. Ties at four decimals are joined with =.

| Scenario | Cutoff (em) | Order | Same as at 3 ems |
|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 2 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings > ggrepel (informed) > Stata mlabel() > adjustText (Python) > ggrepel (R) > labrepel (Stata) | yes |
| Life expectancy, 12 of 63 labelled | 3 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings > ggrepel (informed) > Stata mlabel() > adjustText (Python) > ggrepel (R) > labrepel (Stata) | yes |
| Life expectancy, 12 of 63 labelled | 4 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings > ggrepel (informed) > Stata mlabel() > adjustText (Python) > ggrepel (R) > labrepel (Stata) | yes |
| Life expectancy, 12 of 63 labelled | 6 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings > ggrepel (informed) > Stata mlabel() > adjustText (Python) > ggrepel (R) > labrepel (Stata) | yes |
| Auto, 19 of 74 labelled | 2 | gpolish ptlabel (Stata) = gpolish 0.6.0 settings > ggrepel (informed) > adjustText (Python) > Stata mlabel() = ggrepel (R) > labrepel (Stata) | yes |
| Auto, 19 of 74 labelled | 3 | gpolish ptlabel (Stata) = gpolish 0.6.0 settings > ggrepel (informed) > adjustText (Python) > Stata mlabel() = ggrepel (R) > labrepel (Stata) | yes |
| Auto, 19 of 74 labelled | 4 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings > ggrepel (informed) > adjustText (Python) > Stata mlabel() = ggrepel (R) > labrepel (Stata) | no |
| Auto, 19 of 74 labelled | 6 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings > ggrepel (informed) > adjustText (Python) > Stata mlabel() = ggrepel (R) > labrepel (Stata) | no |
| Life expectancy, all 63 labelled | 2 | gpolish 0.6.0 settings > gpolish ptlabel (Stata) = ggrepel (informed) > ggrepel (R) > Stata mlabel() > adjustText (Python) > labrepel (Stata) | no |
| Life expectancy, all 63 labelled | 3 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings = ggrepel (informed) > ggrepel (R) > Stata mlabel() = adjustText (Python) > labrepel (Stata) | yes |
| Life expectancy, all 63 labelled | 4 | gpolish 0.6.0 settings > gpolish ptlabel (Stata) > ggrepel (informed) > ggrepel (R) > adjustText (Python) > Stata mlabel() > labrepel (Stata) | no |
| Life expectancy, all 63 labelled | 6 | gpolish ptlabel (Stata) > gpolish 0.6.0 settings > ggrepel (informed) > ggrepel (R) > adjustText (Python) > Stata mlabel() > labrepel (Stata) | no |
| Auto, all 74 labelled | 2 | ggrepel (R) = ggrepel (informed) > gpolish ptlabel (Stata) > gpolish 0.6.0 settings > adjustText (Python) > Stata mlabel() > labrepel (Stata) | no |
| Auto, all 74 labelled | 3 | gpolish ptlabel (Stata) > ggrepel (informed) > ggrepel (R) > gpolish 0.6.0 settings = adjustText (Python) > Stata mlabel() > labrepel (Stata) | yes |
| Auto, all 74 labelled | 4 | gpolish ptlabel (Stata) > ggrepel (informed) > ggrepel (R) > gpolish 0.6.0 settings > adjustText (Python) > Stata mlabel() > labrepel (Stata) | no |
| Auto, all 74 labelled | 6 | gpolish ptlabel (Stata) > ggrepel (informed) > ggrepel (R) > gpolish 0.6.0 settings > adjustText (Python) > Stata mlabel() > labrepel (Stata) | no |
| Synthetic, 30 of 30 labelled | 2 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > Stata mlabel() > ggrepel (R) > adjustText (Python) > labrepel (Stata) | no |
| Synthetic, 30 of 30 labelled | 3 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > Stata mlabel() > adjustText (Python) > ggrepel (R) > labrepel (Stata) | yes |
| Synthetic, 30 of 30 labelled | 4 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > Stata mlabel() > adjustText (Python) > ggrepel (R) > labrepel (Stata) | yes |
| Synthetic, 30 of 30 labelled | 6 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > Stata mlabel() > adjustText (Python) > ggrepel (R) > labrepel (Stata) | yes |
| Synthetic, 20 of 60 labelled | 2 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > adjustText (Python) > Stata mlabel() > ggrepel (R) > labrepel (Stata) | yes |
| Synthetic, 20 of 60 labelled | 3 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > adjustText (Python) > Stata mlabel() > ggrepel (R) > labrepel (Stata) | yes |
| Synthetic, 20 of 60 labelled | 4 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > adjustText (Python) > Stata mlabel() > ggrepel (R) > labrepel (Stata) | yes |
| Synthetic, 20 of 60 labelled | 6 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > adjustText (Python) > Stata mlabel() > ggrepel (R) > labrepel (Stata) | yes |
| Synthetic, 60 of 60 labelled | 2 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > ggrepel (R) > adjustText (Python) > Stata mlabel() > labrepel (Stata) | yes |
| Synthetic, 60 of 60 labelled | 3 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > ggrepel (R) > adjustText (Python) > Stata mlabel() > labrepel (Stata) | yes |
| Synthetic, 60 of 60 labelled | 4 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > ggrepel (R) > adjustText (Python) > Stata mlabel() > labrepel (Stata) | yes |
| Synthetic, 60 of 60 labelled | 6 | gpolish ptlabel (Stata) > ggrepel (informed) > gpolish 0.6.0 settings > ggrepel (R) > adjustText (Python) > Stata mlabel() > labrepel (Stata) | yes |

Rows whose order differs from the 3-em order: 9.

