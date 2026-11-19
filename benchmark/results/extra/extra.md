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
