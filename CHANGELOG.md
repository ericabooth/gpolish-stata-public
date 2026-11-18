# Changelog

## 0.6.1 (2026-11-17)

- `gpolish ptlabel`'s placement settings (search rings and their spacing, the cost of moving a label away from its
  point, box height and padding) were chosen on separate tuning scenarios; `benchmark/tune.py` reproduces the choice.
  Compared with 0.6.0, the clean share on the real-data benchmark graphs rose from 0.54 to 0.70 with every country
  labelled, stayed at 1.00 for 12 countries, and fell from 0.89 to 0.84 for 19 cars and from 0.47 to 0.34 with every
  car labelled; on the synthetic test designs it rose (for example from 0.68 to 0.93 with 60 points labelled).
- Fixed: `gpolish ptlabel` could stop with error 3301 when a candidate leader line crossed no obstacle.
- `gpolish geom` checks that the graph exists and is a twoway graph, and returns `r(name)`.
- Help and `gpolish limits`: `segments()` documented for `gpolish arrow`, `gpolish geom` documented, the `plots()`
  abbreviation shown, the description of when a label moves out on a leader line made exact, and the list of what
  `gpolish render` can draw corrected (it does not draw coloured words inside a line or filled arrow heads either).
- Benchmark: a second headline measure, labels that are clean and within 3 ems of their point; tuning seeds kept
  apart from the test seeds.

## 0.6.0 (2026-11-17)

- `gpolish ptlabel` moves a label out on a thin leader line when all eight spots next to its point collide.
  Leaders avoid crossing other labels and each other. New options `noleader`, `lcolor()` and `lwidth()`.
- `gpolish ptlabel` sizes label boxes to the font's full line height with a small pad, so labels that only
  touch are treated as colliding.

## 0.5.1 (2026-11-17)

- New `benchmark/` folder: a reproducible comparison of point-label placement against Stata's `mlabel()`,
  `labrepel`, adjustText (Python) and ggrepel (R), with results in `benchmark/results/`.

## 0.5.0 (2026-11-17)

Fixes found in a review of every subcommand and help example:

- `$` and backticks in label, note and point-label text were expanded as macros; they are now kept literally.
- `endlabel` placed labels on top of the data on a reversed x axis; labels now follow the screen.
- `endlabel` failed half-way on a series with no data, after widening the margin; such series are skipped.
- `endlabel` run twice stacked a second set of labels and doubled the margin; it now replaces the first set.
- `ptlabel` with an `if` that selects nothing, and `brace` with identical ends, stopped with unclear errors.
- `bracket` drew no tick marks on a log x axis.
- Unclear messages for a graph name that does not exist and for `plots()` out of range.
- `gr2mpl` overwrote existing files without `replace`, reported a failure for `saving()` without an extension,
  and printed a Python traceback when the folder did not exist. A failed render now leaves an existing file alone.
- `gr2mpl` names a missing interpreter given in `python()`, and notes when the requested font is not installed.

New:

- `gpolish clear` removes added objects and undoes `endlabel`'s margin and legend changes.
- `endlabel` options `side(left)`, `color()` and `keeplegend`; `endlabel` now turns the legend off.
- `at()`, `to()` and `from()` accept expressions, such as `td(21sep2001)`.
- `endlabel, wrap(#)` now counts characters, as documented (it counted ems before).
- `gr2mpl, saving()` accepts `.pdf`, `.svg` and `.jpg` as well as `.png`.

## 0.4.0 (2026-11-14)

- `gpolish note` (shaded finding box), `gpolish brace` (curly brace with label) and `gpolish arrow`.
- Plain `gpolish` now makes the title bold on every graph family, not only twoway.
- `gr2mpl`: `graph matrix`, `heatplot`, dendrograms, boxed text with `roundbox`, `blabel()` and second-level `over()` labels, axes-off diagrams.
- Scheme `pypolish`: colours for bars, boxes and histograms; plain `by()` panel labels and scatterplot-matrix cells; default marker outlines removed.
- Gallery grows from 12 to 22 examples, including a flow chart, a heatmap, a `coefplot` with shaded confidence bands, and output from `statplot` and `heatplot`.

## 0.3.0 (2026-11-14)

First public version.

- `gpolish`: `style`, `endlabel`, `callout`, `ptlabel`, `bracket`, `legend`, `render`, `limits`.
  Automatic placement for callouts and point labels; width tables for 16 fonts; log axes;
  label wrapping; notes that point to `gpolish render` when a request meets a limit of
  Stata's graph renderer.
- `gr2mpl`: twoway, graph bar/hbar/box/hbox/dot, `by()`, `graph combine`; Python discovery
  with `gr2mpl doctor`; carries `gpolish` edits into the matplotlib version.
- Scheme `pypolish`.
- Tested on StataNow 19.5 and Stata 16.1 (macOS).
