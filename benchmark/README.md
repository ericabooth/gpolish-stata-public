# Label-placement benchmark

This benchmark measures how well five methods place point labels on a scatterplot. It compares `gpolish ptlabel` with Stata's own marker labels, with `labrepel` (the other Stata tool for this), and with the two standard tools outside Stata: adjustText for Python and ggrepel for R.

<img width="900" alt="Share of clean labels and seconds per graph for five methods" src="results/benchmark.png" />

Full tables are in [results/summary.md](results/summary.md); per-graph and per-label scores are in [results/graphs.csv](results/graphs.csv) and [results/labels.csv](results/labels.csv).

## What it shows

- **Against the other Stata options, `gpolish` is clearly better.** It gives the highest share of clean labels of the three Stata methods in every scenario. Against Stata's default `mlabel()`, the share of clean labels rises by between 45 percent and elevenfold.
- **When a subset of points is labelled, `gpolish` is the best of all five methods.** That is the common case in a report: 12 of 63 countries, 19 of 74 cars, or 20 of 60 synthetic points. There it places 58 to 92 percent of labels cleanly, against 37 to 68 percent for ggrepel.
- **When every point is labelled, ggrepel is best.** With all 60 synthetic points labelled, ggrepel places 86 percent of labels cleanly and `gpolish` 65 percent; on the real data with every point labelled, ggrepel reaches about 60 percent and `gpolish` 14 to 32 percent. ggrepel moves labels well away from their points and draws leader lines; `gpolish` keeps every label next to its point, which fails when the space around a point is full.
- **`gpolish` is fast enough to use routinely.** It takes 0.1 to 0.5 seconds per graph, in the same range as ggrepel and adjustText.

## Design

**Scenarios.** Each scenario is a scatterplot with some points labelled.

| Scenario | Points | Labelled | Fit line | Graphs |
|---|---|---|---|---|
| Life expectancy and log GNP per capita (Stata `lifeexp`), the 12 gallery countries | 63 | 12 | yes | 1 |
| The same, every country | 63 | 63 | yes | 1 |
| Mileage and weight (Stata `auto`), every fourth car by weight | 74 | 19 | yes | 1 |
| The same, every car | 74 | 74 | yes | 1 |
| Synthetic: three Gaussian clusters, all labelled | 30 | 30 | no | 20 seeds |
| Synthetic: three clusters, a third labelled | 60 | 20 | no | 20 seeds |
| Synthetic: three clusters, all labelled | 60 | 60 | no | 20 seeds |

Synthetic labels are made-up names of 4 to 14 characters. Every graph is 7 × 4.6 inches, with labels in Open Sans at 8.6 points and markers 6 points across.

**Same geometry for every method.** Stata draws each scenario first, and its plot region and axis scales are exported. The adjustText and ggrepel versions are drawn on a plot region of exactly the same size and position, with the same axis ranges, so all five methods face the same crowding.

**Methods, each at its defaults.**

| Method | Call |
|---|---|
| Stata `mlabel()` | `scatter ..., mlabel() mlabposition(3)`: Stata's default label position |
| `labrepel` 1.7 (graphfunctions, SSC) | `labrepel y x, label() mlabsize() xsize() ysize() seed()`, drawn at the repelled positions with leader lines, as its help file shows |
| `gpolish ptlabel` 0.5.1 | `gpolish ptlabel label, x(x) y(y) size(8.6) msize(6)` |
| adjustText 1.4.0 | `adjust_text(texts, x=..., y=...)`, told about every data point |
| ggrepel 0.9.8 | `geom_text_repel(..., max.overlaps = Inf)`, so it drops no labels |

**One measuring rule.** Every label box is measured the same way, with matplotlib's text extent for the font and size actually used. For the Stata methods the position and alignment of each label are read from the exported SVG; for adjustText from the finished figure; for ggrepel from the label centres read back from the drawn grid objects.

## Metrics

For each label:

| Metric | Definition |
|---|---|
| Overlaps a label | its box intersects another label's box by more than 0.25 pt² |
| Touches a marker | its box comes within a marker's radius of any data point, including its own |
| Crosses the fit line | its box (shrunk by 0.5 pt) intersects the fitted line |
| Outside the plot | its box extends more than 0.5 pt past the plot region |
| Clean | none of the four above |
| Distance | gap between its own point and the nearest edge of its box, in ems (multiples of the font size) |
| Ambiguous | another data point is more than 1 pt closer to the box than its own point |
| Seconds | time for the placement step |

The headline figure is the share of clean labels.

## Caveats

- **`labrepel` is shown at its defaults.** It starts each label centred on its point and moves it only when labels collide. With few labels nothing collides, so labels stay on top of their markers. That is why its clean share is near zero in the 12-label case. Its `nudgex()`, `nudgey()` and `direction()` options would change this, and a user tuning it would do better.
- **adjustText was not told about the fit line.** Only `gpolish` treats plotted lines as obstacles by default. ggrepel and adjustText can be given extra obstacles, but not by default.
- **Timings are not strictly comparable.** For `gpolish` they cover the whole command: reading the graph, placement and adding the labels. For `labrepel` they cover the placement only. For ggrepel they cover drawing the whole plot, because ggrepel places labels while it draws. For adjustText they cover `adjust_text()` only. All runs were on one Mac.
- **`gpolish` never moves a label away from its point.** It tries eight positions next to the point and picks the least crowded. That gives short, unambiguous distances and no leader lines, but it cannot escape a crowded neighbourhood. This explains its weaker results when every point is labelled.
- **Text widths in `gpolish` come from built-in tables.** Stata reports no text metrics, so `gpolish` estimates widths from per-font character tables. The benchmark measures the real rendered boxes, so any error in those estimates shows up in the scores.

## Running it

From this folder:

```bash
python make_synthetic.py                    # data/: 60 synthetic scenarios
stata-mp -b do run_stata.do                 # out/stata/: default, gpolish, labrepel; real-data scenarios
python run_adjusttext.py                    # out/adjusttext/
Rscript run_ggrepel.R                       # out/ggrepel/
python score.py                             # results/labels.csv, results/graphs.csv
python summarize.py                         # results/summary.md, results/benchmark.png
```

Requirements:

- **Stata 16 or later**, with this package's `src` folder (found automatically from this folder) and `labrepel`. To install `labrepel`, run `ssc install graphfunctions`; set the environment variable `BENCH_PLUS` to search another ado folder for it.
- **Python** with matplotlib, numpy and adjustText.
- **R** with ggplot2 and ggrepel.
- **The Open Sans font.**

`python score.py --check life12` draws every method's measured boxes over the data for one scenario, as a check that the boxes match the rendered labels.

`data/` and `out/` are generated and not kept in the repository.
