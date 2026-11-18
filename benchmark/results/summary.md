# Label-placement benchmark: results

Each cell is one graph for the real-data scenarios, and the mean ± 95% interval over 20 random
seeds for the synthetic designs. A *clean* label overlaps no other label, no data marker and
not the fit line, and stays inside the plot region. See README.md for the design.

## Clean labels (share)

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.58 | 0.00 | 1.00 | 0.42 | 0.67 |
| Auto, 19 of 74 labelled | 0.05 | 0.00 | 0.89 | 0.26 | 0.37 |
| Life expectancy, all 63 labelled | 0.22 | 0.02 | 0.54 | 0.29 | 0.60 |
| Auto, all 74 labelled | 0.05 | 0.00 | 0.47 | 0.23 | 0.59 |
| Synthetic, 30 of 30 labelled | 0.58 ± 0.06 | 0.40 ± 0.04 | 0.90 ± 0.04 | 0.41 ± 0.04 | 0.95 ± 0.03 |
| Synthetic, 20 of 60 labelled | 0.45 ± 0.05 | 0.37 ± 0.08 | 0.77 ± 0.06 | 0.35 ± 0.05 | 0.68 ± 0.05 |
| Synthetic, 60 of 60 labelled | 0.30 ± 0.03 | 0.22 ± 0.03 | 0.68 ± 0.05 | 0.45 ± 0.03 | 0.86 ± 0.03 |

## Overlapping label pairs

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| Auto, 19 of 74 labelled | 15.0 | 11.0 | 0.0 | 0.0 | 0.0 |
| Life expectancy, all 63 labelled | 47.0 | 74.0 | 12.0 | 20.0 | 6.0 |
| Auto, all 74 labelled | 237.0 | 187.0 | 22.0 | 31.0 | 16.0 |
| Synthetic, 30 of 30 labelled | 7.2 ± 1.9 | 9.2 ± 1.1 | 0.6 ± 0.4 | 0.2 ± 0.2 | 0.2 ± 0.2 |
| Synthetic, 20 of 60 labelled | 4.3 ± 1.0 | 4.3 ± 1.1 | 0.5 ± 0.3 | 0.1 ± 0.1 | 0.1 ± 0.1 |
| Synthetic, 60 of 60 labelled | 38.8 ± 5.5 | 38.5 ± 4.5 | 7.5 ± 1.9 | 2.9 ± 1.2 | 2.2 ± 0.6 |

## Labels touching a marker (share)

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.17 | 1.00 | 0.00 | 0.58 | 0.25 |
| Auto, 19 of 74 labelled | 0.68 | 1.00 | 0.11 | 0.74 | 0.58 |
| Life expectancy, all 63 labelled | 0.54 | 0.97 | 0.22 | 0.48 | 0.21 |
| Auto, all 74 labelled | 0.64 | 0.99 | 0.28 | 0.41 | 0.20 |
| Synthetic, 30 of 30 labelled | 0.19 ± 0.04 | 0.26 ± 0.05 | 0.07 ± 0.02 | 0.58 ± 0.03 | 0.04 ± 0.02 |
| Synthetic, 20 of 60 labelled | 0.41 ± 0.05 | 0.44 ± 0.06 | 0.17 ± 0.05 | 0.65 ± 0.05 | 0.32 ± 0.05 |
| Synthetic, 60 of 60 labelled | 0.40 ± 0.03 | 0.44 ± 0.04 | 0.18 ± 0.03 | 0.52 ± 0.02 | 0.10 ± 0.02 |

## Labels crossing the fit line (share)

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.08 | 0.17 | 0.00 | 0.08 | 0.17 |
| Auto, 19 of 74 labelled | 0.53 | 0.53 | 0.00 | 0.21 | 0.32 |
| Life expectancy, all 63 labelled | 0.38 | 0.35 | 0.00 | 0.22 | 0.19 |
| Auto, all 74 labelled | 0.54 | 0.54 | 0.15 | 0.20 | 0.18 |
| Synthetic, 30 of 30 labelled | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 |
| Synthetic, 20 of 60 labelled | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 |
| Synthetic, 60 of 60 labelled | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 | 0.00 ± 0.00 |

## Labels outside the plot (share)

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.083 | 0.083 | 0.000 | 0.000 | 0.000 |
| Auto, 19 of 74 labelled | 0.053 | 0.053 | 0.000 | 0.000 | 0.000 |
| Life expectancy, all 63 labelled | 0.016 | 0.032 | 0.000 | 0.032 | 0.000 |
| Auto, all 74 labelled | 0.027 | 0.014 | 0.000 | 0.027 | 0.000 |
| Synthetic, 30 of 30 labelled | 0.042 ± 0.022 | 0.022 ± 0.015 | 0.003 ± 0.005 | 0.000 ± 0.000 | 0.000 ± 0.000 |
| Synthetic, 20 of 60 labelled | 0.028 ± 0.016 | 0.033 ± 0.016 | 0.008 ± 0.009 | 0.000 ± 0.000 | 0.000 ± 0.000 |
| Synthetic, 60 of 60 labelled | 0.020 ± 0.011 | 0.013 ± 0.007 | 0.001 ± 0.002 | 0.000 ± 0.000 | 0.000 ± 0.000 |

## Labels nearer another point (share)

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.17 | 0.00 | 0.25 | 0.00 | 0.17 |
| Auto, 19 of 74 labelled | 0.84 | 0.05 | 0.74 | 0.53 | 0.58 |
| Life expectancy, all 63 labelled | 0.54 | 0.16 | 0.56 | 0.44 | 0.41 |
| Auto, all 74 labelled | 0.81 | 0.22 | 0.78 | 0.64 | 0.61 |
| Synthetic, 30 of 30 labelled | 0.24 ± 0.05 | 0.64 ± 0.03 | 0.17 ± 0.04 | 0.12 ± 0.04 | 0.03 ± 0.02 |
| Synthetic, 20 of 60 labelled | 0.48 ± 0.03 | 0.73 ± 0.05 | 0.36 ± 0.06 | 0.24 ± 0.04 | 0.28 ± 0.04 |
| Synthetic, 60 of 60 labelled | 0.47 ± 0.03 | 0.82 ± 0.02 | 0.35 ± 0.04 | 0.34 ± 0.03 | 0.20 ± 0.04 |

## Distance from own point (em)

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.61 | 0.00 | 0.81 | 0.28 | 0.33 |
| Auto, 19 of 74 labelled | 0.61 | 0.01 | 2.12 | 1.14 | 0.39 |
| Life expectancy, all 63 labelled | 0.61 | 0.19 | 1.92 | 1.54 | 1.04 |
| Auto, all 74 labelled | 0.61 | 0.18 | 3.31 | 2.54 | 2.43 |
| Synthetic, 30 of 30 labelled | 0.61 ± 0.00 | 2.30 ± 0.13 | 0.77 ± 0.06 | 0.48 ± 0.07 | 0.39 ± 0.02 |
| Synthetic, 20 of 60 labelled | 0.61 ± 0.00 | 1.88 ± 0.14 | 0.78 ± 0.06 | 0.47 ± 0.05 | 0.38 ± 0.01 |
| Synthetic, 60 of 60 labelled | 0.61 ± 0.00 | 2.46 ± 0.09 | 0.99 ± 0.06 | 0.93 ± 0.09 | 0.62 ± 0.08 |

## Seconds per graph

| Scenario | Stata mlabel() | labrepel (Stata) | gpolish ptlabel (Stata) | adjustText (Python) | ggrepel (R) |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 labelled | 0.00 | 0.00 | 0.11 | 0.02 | 0.12 |
| Auto, 19 of 74 labelled | 0.00 | 0.20 | 0.23 | 1.03 | 0.18 |
| Life expectancy, all 63 labelled | 0.00 | 0.34 | 1.00 | 1.09 | 0.91 |
| Auto, all 74 labelled | 0.00 | 2.85 | 1.60 | 1.12 | 1.17 |
| Synthetic, 30 of 30 labelled | 0.00 ± 0.00 | 0.06 ± 0.01 | 0.16 ± 0.00 | 0.50 ± 0.23 | 0.28 ± 0.01 |
| Synthetic, 20 of 60 labelled | 0.00 ± 0.00 | 0.03 ± 0.00 | 0.12 ± 0.00 | 0.93 ± 0.14 | 0.18 ± 0.00 |
| Synthetic, 60 of 60 labelled | 0.00 ± 0.00 | 0.31 ± 0.03 | 0.37 ± 0.02 | 1.07 ± 0.00 | 0.79 ± 0.01 |

