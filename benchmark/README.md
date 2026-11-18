# Label-placement benchmark

This benchmark measures how well five methods place point labels on a scatterplot. It compares `gpolish ptlabel` with Stata's own marker labels, with `labrepel` (the other Stata tool for this), and with the two standard tools outside Stata: adjustText for Python and ggrepel for R.

<img width="1000" alt="Share of clean labels, share of clean labels near their point, and seconds per graph for five methods" src="results/benchmark.png" />

Full tables are in [results/summary.md](results/summary.md). Per-graph and per-label scores are in [results/graphs.csv](results/graphs.csv) and [results/labels.csv](results/labels.csv), and the tuning results are in [results/tuning.csv](results/tuning.csv).

## What it shows

No candidate setting was scored on the synthetic test seeds or on the real-data scenarios: `gpolish`'s six settings were chosen only on separate tuning seeds (see [Tuning](#tuning)). The test output did have some indirect influence, because the tuning objective was revised once after looking at test-set images and the method itself was developed with this benchmark in view; both are described under Tuning.

- **Against the other Stata options, `gpolish` is clearly better.** It has the highest share of clean labels of the three Stata methods in every scenario: between 1.7 and 16 times the share for Stata's default `mlabel()`.
- **When a subset of points is labelled, `gpolish` is the best of all five methods.** That is the common case in a report: 12 of 63 countries, 19 of 74 cars, or 20 of 60 synthetic points. There 84 to 100 percent of its labels are clean and 68 to 100 percent are clean and within 3 ems of their point. The figures for ggrepel are 37 to 68 percent on both measures.
- **When every point is labelled, `gpolish` leads in three of four scenarios and trails badly in one.** It is ahead of ggrepel on both measures with every country labelled (0.70 against 0.60 clean) and in both all-labelled synthetic designs (for example 0.93 against 0.86 clean with 60 points). With every car labelled it is well behind: 0.34 against 0.59 clean, and 0.20 against 0.36 clean and near. Its failures there are mostly labels touching markers (35 percent of labels against 20 for ggrepel) and overlapping pairs (31 against 16), not fit-line crossings (14 percent against 18).
- **`gpolish` usually places labels farther from their points than ggrepel.** Its mean distance is 0.7 to 2.4 ems, against 0.3 to 2.4 for ggrepel; it is farther in six of seven scenarios and level with every car labelled.
- **It takes 0.1 to 2.0 seconds per graph,** against 0.1 to 1.2 for ggrepel and 0.02 to 1.1 for adjustText.

## Design

**Scenarios.** Each scenario is a scatterplot with some points labelled.

| Scenario | Points | Labelled | Fit line | Graphs |
|---|---|---|---|---|
| Life expectancy and log GNP per capita (Stata `lifeexp`), the 12 gallery countries | 63 | 12 | yes | 1 |
| The same, every country | 63 | 63 | yes | 1 |
| Mileage and weight (Stata `auto`), every fourth car by weight | 74 | 19 | yes | 1 |
| The same, every car | 74 | 74 | yes | 1 |
| Synthetic: three Gaussian clusters, all labelled | 30 | 30 | no | 20 test seeds |
| Synthetic: three clusters, a third labelled | 60 | 20 | no | 20 test seeds |
| Synthetic: three clusters, all labelled | 60 | 60 | no | 20 test seeds |

Synthetic labels are made-up names of 4 to 14 characters. Every graph is 7 × 4.6 inches, with labels in Open Sans at 8.6 points and markers 6 points across.

**Same geometry for every method.** Stata draws each scenario first, and its plot region and axis scales are exported. The adjustText and ggrepel versions are drawn on a plot region of exactly the same size and position, with the same axis ranges, so all five methods face the same crowding.

**Methods, each at its defaults.**

| Method | Call |
|---|---|
| Stata `mlabel()` | `scatter ..., mlabel() mlabposition(3)`: Stata's default label position |
| `labrepel` 1.7 (graphfunctions, SSC) | `labrepel y x, label() mlabsize() xsize() ysize() seed()`, drawn at the repelled positions with leader lines, as its help file shows |
| `gpolish ptlabel` 0.6.1 | `gpolish ptlabel label, x(x) y(y) size(8.6) msize(6)` |
| adjustText 1.4.0 | `adjust_text(texts, x=..., y=..., arrowprops=...)`, told about every data point; `arrowprops` only draws its leader lines |
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
| Clean and near | clean, and no more than 3 ems from its own point |
| Distance | gap between its own point and the nearest edge of its box, in ems (multiples of the font size) |
| Ambiguous | another data point is more than 1 pt closer to the box than its own point |
| Seconds | time for the placement step |

The two headline measures are the share of clean labels and the share of clean labels near their point.

## Tuning

`gpolish ptlabel` has six placement settings, kept in one function in the code (`_gpl_placeparms()`):

- the number of rings searched when a label moves out on a leader line, and the spacing of those rings;
- the cost of a spot away from the point, and how that cost grows with distance (searched as pairs);
- the label box height and the padding around each box.

They were chosen with [tune.py](tune.py) on separate **tuning scenarios**: synthetic seeds 101 to 110 for each of the three synthetic designs, 30 graphs drawn by the same process as the test seeds. Neither the 20 test seeds nor the four real-data scenarios were used to choose them.

- **Objective:** the mean, across the three designs, of the share of labels that are clean and within 3 ems of their point.
- **Search:** 566 settings in five stages, all on the tuning scenarios. Stage 1 is a grid of 420. Later stages extended ranges whose best value sat at an edge and narrowed or fixed the others; stage 3 also added an intermediate distance cost (0.05 with 0.005), which the final setting uses. The ring spacing was held at 0.9 label heights in stages 1 to 3 and varied only in stages 4 and 5.
- **Stopping rule:** stop when extending the ranges gains less than 0.01. The rule was set after stage 4 and before stage 5. The gains from stages 2 to 5 were 0.020, 0.006, 0.014 and 0.001. Stage 3's gain was already below the threshold, so had the rule been set from the start the search would have stopped at stage 3, at the setting discussed below. Stage 5 gained 0.001, so the search stopped there.
- **Result:** 9 rings spaced 0.4 label heights apart; a far spot costs 0.05 label heights squared plus 0.005 per label height of distance; box height 0.4 times the font size with 3 points of padding. On the tuning set it scores 0.93 on the objective (clean-and-near shares of 0.97, 0.88 and 0.95 in the three designs); pooled over all 1,100 tuning labels, 92 percent are clean and near. The ring spacing of 0.4 is the smallest value tried.
- **Precision:** the ten best settings score within 0.006 of each other on the tuning set, so the exact choice among them matters little.

**How well the tuning carried over.** On the synthetic test seeds the tuned settings do slightly better than on the tuning seeds (a mean clean-and-near share of 0.94 against 0.93). The real-data results are mixed. Compared with the previous release, 0.6.0, whose settings were set by hand, the clean share rose from 0.54 to 0.70 with every country labelled, stayed at 1.00 for the 12 countries, and fell from 0.89 to 0.84 for 19 cars and from 0.47 to 0.34 with every car labelled. The scorer and the other methods' results did not change, so these figures compare directly. The best setting after stage 3 of this same search scored 0.59 clean on the all-cars graph. The final setting scores higher on the tuning objective (0.93 against 0.92 clean and near), though not on the clean share alone (0.94 against 0.95), and it scores 0.34 on that graph. Its losses there come from labels touching markers and overlapping each other, not from the fit line; the life-expectancy graph also has a fit line and improved. One possible reason is that the final setting uses a smaller collision box (0.4 times the font size plus 3 points of padding, against 1.4 times plus 0.6 points in 0.6.0) and tighter rings, which may suit the synthetic clusters better than a 74-label crowd. The gap is reported here rather than tuned away, since changing the settings after seeing it would use the test data to choose them.

Points of process a reader should know:

- **The objective was revised once.** Stages 1 and 2 were designed and run while the objective was the clean share alone. The setting that objective chose sent many labels out on long leader lines, which the test-set images made obvious. The 3-em condition was then added, stages 1 and 2 were scored again under it, and stages 3 to 5 were designed and run under the revised objective. The settings were never chosen on test data, but the objective was changed after looking at test output.
- **The method was developed with this benchmark in view.** The leader-line fallback and the box-height correction were added after early benchmark runs showed where `gpolish` failed. Only the six numeric settings were tuned on held-out data.
- **A crash was fixed during tuning.** A leader-line check failed when a candidate leader crossed no obstacle at all. No tuning or benchmark run hit it (every run completed every graph), and the fix does not change any placement.

## Caveats

- **`labrepel` is shown at its defaults.** It starts each label centred on its point and moves it only when labels collide. With few labels nothing collides, so labels stay on top of their markers; that is why its clean share is near zero in the 12-label case. Its `nudgex()`, `nudgey()` and `direction()` options would change this, and a user tuning it would do better.
- **adjustText was not told about the fit line.** Only `gpolish` treats plotted lines as obstacles by default. ggrepel and adjustText can be given extra obstacles, but not by default.
- **Timings are not strictly comparable.** For `gpolish` they cover the whole command: reading the graph, placement and adding the labels. For `labrepel` they cover the placement only. For ggrepel they cover drawing the whole plot, because ggrepel places labels while it draws. For adjustText they cover `adjust_text()` only. All runs were on one Mac.
- **The ambiguity measure ignores leader lines.** A label moved away from its point can sit nearer another point and count as ambiguous, even though its leader line shows which point it belongs to. Every method except `mlabel()` draws leader lines for labels it moves.
- **Text widths in `gpolish` come from built-in tables.** Stata reports no text metrics, so `gpolish` estimates widths from per-font character tables. The benchmark measures the real rendered boxes, so any error in those estimates shows up in the scores.

## Running it

From this folder:

```bash
python make_synthetic.py                    # data/: test seeds 1 to 20 and tuning seeds 101 to 110
stata-mp -b do run_stata.do                 # out/stata/: default, gpolish, labrepel; real-data scenarios
python run_adjusttext.py                    # out/adjusttext/
Rscript run_ggrepel.R                       # out/ggrepel/
python score.py                             # results/labels.csv, results/graphs.csv
python summarize.py                         # results/summary.md, results/benchmark.png
python tune.py stata-mp 6                   # optional: results/tuning.csv (about 50 minutes on 6 workers)
```

Requirements:

- **Stata 16 or later**, with this package's `src` folder (found automatically from this folder) and `labrepel`. To install `labrepel`, run `ssc install graphfunctions`; set the environment variable `BENCH_PLUS` to search another ado folder for it, and `BENCH_METHODS` (for example `gpolish`) to rerun only some methods.
- **Python** with matplotlib, numpy and adjustText.
- **R** with ggplot2 and ggrepel.
- **The Open Sans font.**

`python score.py --check life12` draws every method's measured boxes over the data for one scenario, as a check that the boxes match the rendered labels.

`data/` and `out/` are generated and not kept in the repository.
