# Changelog

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
