# Further runs

Written by `extra.py`. Each cell is the clean share / clean-and-near share (synthetic designs: mean over seeds). The main run's values for the same methods are shown for comparison; every setting not named is the same as in the main run.

## Raised iteration limits

adjustText `iter_lim=1000` (main run 100); both ggrepel columns `max.iter = 100000` (main run 10000). `gpolish` is from the main run.

| Scenario | `gpolish` | adjustText | adjustText, raised | ggrepel | ggrepel, raised | ggrepel (informed) | ggrepel (informed), raised |
|---|---|---|---|---|---|---|---|
| Life expectancy, 12 of 63 | 1.00 / 1.00 | 0.50 / 0.50 | 0.50 / 0.50 | 0.33 / 0.33 | 0.33 / 0.33 | 0.75 / 0.75 | 0.75 / 0.75 |
| Auto, 19 of 74 | 0.84 / 0.68 | 0.37 / 0.37 | 0.37 / 0.37 | 0.16 / 0.16 | 0.16 / 0.16 | 0.63 / 0.63 | 0.68 / 0.68 |
| Life expectancy, all 63 | 0.75 / 0.63 | 0.30 / 0.24 | 0.41 / 0.32 | 0.57 / 0.56 | 0.62 / 0.52 | 0.67 / 0.59 | 0.70 / 0.62 |
| Auto, all 74 | 0.59 / 0.35 | 0.38 / 0.22 | 0.46 / 0.23 | 0.51 / 0.31 | 0.64 / 0.32 | 0.58 / 0.34 | 0.74 / 0.41 |
| Synthetic, 30 of 30 | 0.99 / 0.99 | 0.60 / 0.59 | 0.61 / 0.60 | 0.59 / 0.58 | 0.59 / 0.59 | 0.95 / 0.95 | 0.96 / 0.96 |
| Synthetic, 20 of 60 | 0.96 / 0.95 | 0.49 / 0.49 | 0.49 / 0.49 | 0.40 / 0.40 | 0.41 / 0.41 | 0.86 / 0.86 | 0.87 / 0.86 |
| Synthetic, 60 of 60 | 0.92 / 0.88 | 0.56 / 0.53 | 0.55 / 0.51 | 0.60 / 0.58 | 0.63 / 0.60 | 0.86 / 0.84 | 0.88 / 0.85 |

- adjustText: iterations 5 to 1,000 (median 1,000) over 64 graphs.
- ggrepel: iterations 9,911 to 100,000 (median 100,000) over 64 graphs.
- ggrepel (informed): iterations 11,192 to 100,000 (median 100,000) over 64 graphs.

## Fitted line given as an obstacle

adjustText and informed ggrepel are given the fitted line as extra points every 4 points along it (`BENCH_LINEPTS=1`), so their labels avoid the line as `gpolish`'s do. Only the four real-data graphs have a fitted line.

| Scenario | `gpolish` | adjustText | adjustText, line given | ggrepel (informed) | ggrepel (informed), line given |
|---|---|---|---|---|---|
| Life expectancy, 12 of 63 | 1.00 / 1.00 | 0.50 / 0.50 | 0.58 / 0.58 | 0.75 / 0.75 | 0.92 / 0.92 |
| Auto, 19 of 74 | 0.84 / 0.68 | 0.37 / 0.37 | 0.37 / 0.37 | 0.63 / 0.63 | 0.89 / 0.84 |
| Life expectancy, all 63 | 0.75 / 0.63 | 0.30 / 0.24 | 0.40 / 0.32 | 0.67 / 0.59 | 0.65 / 0.51 |
| Auto, all 74 | 0.59 / 0.35 | 0.38 / 0.22 | 0.36 / 0.18 | 0.58 / 0.34 | 0.58 / 0.32 |

## Holdout seeds and a rule-based subset

Synthetic seeds 201 to 220 of the three designs (20 graphs each), drawn after the main results were fixed, and the 12 countries farthest from the fitted line (largest absolute residual), a rule fixed before the run. Every method at the main run's settings.

| Scenario | `mlabel()` | `labrepel` | `gpolish` | `gpolish` 0.6.0 | adjustText | ggrepel | ggrepel (informed) |
|---|---|---|---|---|---|---|---|
| Synthetic, 30 of 30 | 0.57 / 0.57 | 0.44 / 0.32 | 0.99 / 0.99 | 0.96 / 0.95 | 0.59 / 0.59 | 0.57 / 0.57 | 0.97 / 0.97 |
| Synthetic, 20 of 60 | 0.46 / 0.46 | 0.33 / 0.29 | 0.98 / 0.97 | 0.88 / 0.87 | 0.49 / 0.49 | 0.42 / 0.42 | 0.91 / 0.91 |
| Synthetic, 60 of 60 | 0.35 / 0.35 | 0.24 / 0.15 | 0.92 / 0.87 | 0.83 / 0.76 | 0.53 / 0.49 | 0.62 / 0.60 | 0.86 / 0.83 |
| Life expectancy, 12 farthest from the line | 0.67 / 0.67 | 0.00 / 0.00 | 1.00 / 1.00 | 0.92 / 0.92 | 0.67 / 0.67 | 0.58 / 0.58 | 0.92 / 0.92 |

## Random seeds

ggrepel, informed ggrepel and `labrepel` on the four real-data graphs with seeds 1 to 20 (the main run uses 12345). Clean share: median (minimum to maximum) over the 20 seeds, then the main run's value for that method and `gpolish`'s, which has no random seed.

| Scenario | Method | Median clean | Range | Seed 12345 | `gpolish` | Median clean and near | Range |
|---|---|---|---|---|---|---|---|
| Life expectancy, 12 of 63 | `labrepel` | 0.00 | 0.00 to 0.00 | 0.00 | 1.00 | 0.00 | 0.00 to 0.00 |
| Life expectancy, 12 of 63 | ggrepel | 0.33 | 0.25 to 0.42 | 0.33 | 1.00 | 0.33 | 0.25 to 0.42 |
| Life expectancy, 12 of 63 | ggrepel (informed) | 0.83 | 0.75 to 1.00 | 0.75 | 1.00 | 0.83 | 0.75 to 1.00 |
| Auto, 19 of 74 | `labrepel` | 0.00 | 0.00 to 0.00 | 0.00 | 0.84 | 0.00 | 0.00 to 0.00 |
| Auto, 19 of 74 | ggrepel | 0.16 | 0.16 to 0.16 | 0.16 | 0.84 | 0.16 | 0.16 to 0.16 |
| Auto, 19 of 74 | ggrepel (informed) | 0.68 | 0.58 to 0.74 | 0.63 | 0.84 | 0.68 | 0.58 to 0.74 |
| Life expectancy, all 63 | `labrepel` | 0.01 | 0.00 to 0.05 | 0.02 | 0.75 | 0.00 | 0.00 to 0.05 |
| Life expectancy, all 63 | ggrepel | 0.56 | 0.49 to 0.60 | 0.57 | 0.75 | 0.54 | 0.46 to 0.57 |
| Life expectancy, all 63 | ggrepel (informed) | 0.67 | 0.62 to 0.70 | 0.67 | 0.75 | 0.59 | 0.52 to 0.62 |
| Auto, all 74 | `labrepel` | 0.00 | 0.00 to 0.00 | 0.00 | 0.59 | 0.00 | 0.00 to 0.00 |
| Auto, all 74 | ggrepel | 0.53 | 0.47 to 0.66 | 0.51 | 0.59 | 0.32 | 0.27 to 0.41 |
| Auto, all 74 | ggrepel (informed) | 0.57 | 0.54 to 0.66 | 0.58 | 0.59 | 0.34 | 0.28 to 0.41 |

## adjustText and ggrepel tuned

adjustText and informed ggrepel at the settings `tune_others.py` chose on the tuning seeds (101 to 110) with `gpolish`'s objective (see `results/tuned_settings.md`). The other columns are the main run. Clean share / clean-and-near share; synthetic designs are means over the 20 test seeds.

| Scenario | `mlabel()` | `labrepel` | `gpolish` | `gpolish` 0.6.0 | adjustText | ggrepel | ggrepel (informed) | adjustText, tuned | ggrepel (informed), tuned |
|---|---|---|---|---|---|---|---|---|---|
| Life expectancy, 12 of 63 | 0.58 / 0.58 | 0.00 / 0.00 | 1.00 / 1.00 | 0.92 / 0.92 | 0.50 / 0.50 | 0.33 / 0.33 | 0.75 / 0.75 | 0.92 / 0.92 | 0.75 / 0.75 |
| Auto, 19 of 74 | 0.16 / 0.16 | 0.00 / 0.00 | 0.84 / 0.68 | 0.89 / 0.68 | 0.37 / 0.37 | 0.16 / 0.16 | 0.63 / 0.63 | 0.79 / 0.58 | 0.74 / 0.74 |
| Life expectancy, all 63 | 0.24 / 0.24 | 0.02 / 0.02 | 0.75 / 0.63 | 0.83 / 0.59 | 0.30 / 0.24 | 0.57 / 0.56 | 0.67 / 0.59 | 0.71 / 0.40 | 0.76 / 0.70 |
| Auto, all 74 | 0.09 / 0.09 | 0.00 / 0.00 | 0.59 / 0.35 | 0.51 / 0.22 | 0.38 / 0.22 | 0.51 / 0.31 | 0.58 / 0.34 | 0.43 / 0.20 | 0.68 / 0.38 |
| Synthetic, 30 of 30 | 0.61 / 0.61 | 0.46 / 0.32 | 0.99 / 0.99 | 0.96 / 0.95 | 0.60 / 0.59 | 0.59 / 0.58 | 0.95 / 0.95 | 0.94 / 0.91 | 0.98 / 0.98 |
| Synthetic, 20 of 60 | 0.47 / 0.47 | 0.35 / 0.29 | 0.96 / 0.95 | 0.86 / 0.84 | 0.49 / 0.49 | 0.40 / 0.40 | 0.86 / 0.86 | 0.86 / 0.82 | 0.89 / 0.89 |
| Synthetic, 60 of 60 | 0.33 / 0.33 | 0.25 / 0.16 | 0.92 / 0.88 | 0.83 / 0.76 | 0.56 / 0.53 | 0.60 / 0.58 | 0.86 / 0.84 | 0.75 / 0.63 | 0.89 / 0.87 |

Clean share over the 10 row orders of the four real-data graphs: median (minimum to maximum).

| Scenario | `mlabel()` | `labrepel` | `gpolish` | `gpolish` 0.6.0 | adjustText | ggrepel | ggrepel (informed) | adjustText, tuned | ggrepel (informed), tuned |
|---|---|---|---|---|---|---|---|---|---|
| Life expectancy, 12 of 63 | 0.58 (0.58 to 0.58) | 0.00 (0.00 to 0.00) | 1.00 (1.00 to 1.00) | 1.00 (0.92 to 1.00) | 0.54 (0.50 to 0.58) | 0.33 (0.25 to 0.42) | 0.88 (0.75 to 0.92) | 0.92 (0.92 to 0.92) | 0.88 (0.75 to 0.92) |
| Auto, 19 of 74 | 0.16 (0.16 to 0.16) | 0.00 (0.00 to 0.00) | 0.84 (0.74 to 0.89) | 0.84 (0.74 to 0.89) | 0.34 (0.32 to 0.37) | 0.16 (0.16 to 0.16) | 0.74 (0.63 to 0.74) | 0.79 (0.79 to 0.79) | 0.74 (0.74 to 0.74) |
| Life expectancy, all 63 | 0.24 (0.24 to 0.24) | 0.00 (0.00 to 0.03) | 0.79 (0.65 to 0.84) | 0.68 (0.59 to 0.76) | 0.43 (0.40 to 0.44) | 0.54 (0.46 to 0.59) | 0.64 (0.57 to 0.73) | 0.60 (0.52 to 0.63) | 0.74 (0.68 to 0.79) |
| Auto, all 74 | 0.09 (0.09 to 0.09) | 0.00 (0.00 to 0.00) | 0.54 (0.50 to 0.59) | 0.51 (0.42 to 0.62) | 0.38 (0.35 to 0.47) | 0.53 (0.46 to 0.59) | 0.57 (0.49 to 0.61) | 0.51 (0.34 to 0.61) | 0.69 (0.64 to 0.73) |

## Held-out real data

Four scatterplots from Stata example datasets never used while `gpolish` was developed or tuned, chosen by a rule fixed before any was drawn (see `make_real.do`). Every method at the main run's settings and the two tuned columns. First table: the original row order, clean share / clean-and-near share. Second: median clean share over 10 random row orders (minimum to maximum).

| Scenario | `mlabel()` | `labrepel` | `gpolish` | `gpolish` 0.6.0 | adjustText | ggrepel | ggrepel (informed) | adjustText, tuned | ggrepel (informed), tuned |
|---|---|---|---|---|---|---|---|---|---|
| Census: deaths per 1,000 by median age, all 50 states | 0.12 / 0.12 | 0.00 / 0.00 | 0.68 / 0.46 | 0.56 / 0.36 | 0.30 / 0.14 | 0.62 / 0.32 | 0.56 / 0.44 | 0.56 / 0.30 | 0.78 / 0.52 |
| Census: the same, 13 of 50 states labelled | 0.38 / 0.38 | 0.00 / 0.00 | 1.00 / 0.92 | 0.77 / 0.69 | 0.08 / 0.08 | 0.15 / 0.15 | 0.54 / 0.54 | 0.62 / 0.62 | 0.62 / 0.62 |
| hsng: median rent by family income, all 50 states | 0.10 / 0.10 | 0.00 / 0.00 | 0.74 / 0.56 | 0.60 / 0.30 | 0.48 / 0.24 | 0.66 / 0.48 | 0.64 / 0.48 | 0.64 / 0.26 | 0.66 / 0.50 |
| states: divorce rate by median age, all 50 states | 0.12 / 0.12 | 0.10 / 0.10 | 0.56 / 0.40 | 0.60 / 0.40 | 0.38 / 0.22 | 0.54 / 0.44 | 0.76 / 0.62 | 0.60 / 0.32 | 0.88 / 0.68 |

| Scenario | `mlabel()` | `labrepel` | `gpolish` | `gpolish` 0.6.0 | adjustText | ggrepel | ggrepel (informed) | adjustText, tuned | ggrepel (informed), tuned |
|---|---|---|---|---|---|---|---|---|---|
| Census: deaths per 1,000 by median age, all 50 states | 0.12 (0.12 to 0.12) | 0.00 (0.00 to 0.06) | 0.68 (0.56 to 0.74) | 0.58 (0.48 to 0.66) | 0.34 (0.32 to 0.38) | 0.62 (0.56 to 0.66) | 0.56 (0.52 to 0.64) | 0.53 (0.46 to 0.64) | 0.74 (0.70 to 0.78) |
| Census: the same, 13 of 50 states labelled | 0.38 (0.38 to 0.38) | 0.00 (0.00 to 0.00) | 1.00 (1.00 to 1.00) | 0.77 (0.69 to 0.85) | 0.08 (0.08 to 0.08) | 0.23 (0.15 to 0.31) | 0.62 (0.54 to 0.69) | 0.62 (0.62 to 0.62) | 0.62 (0.54 to 0.69) |
| hsng: median rent by family income, all 50 states | 0.10 (0.10 to 0.10) | 0.00 (0.00 to 0.00) | 0.66 (0.60 to 0.70) | 0.58 (0.50 to 0.66) | 0.40 (0.32 to 0.50) | 0.60 (0.54 to 0.62) | 0.63 (0.58 to 0.68) | 0.68 (0.62 to 0.74) | 0.71 (0.66 to 0.74) |
| states: divorce rate by median age, all 50 states | 0.12 (0.12 to 0.12) | 0.07 (0.02 to 0.10) | 0.67 (0.60 to 0.74) | 0.57 (0.48 to 0.62) | 0.38 (0.34 to 0.46) | 0.62 (0.60 to 0.68) | 0.76 (0.70 to 0.80) | 0.58 (0.52 to 0.70) | 0.82 (0.74 to 0.84) |
