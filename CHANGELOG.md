# Changelog

## 0.7.0 (2026-11-18)

This release contains gpolish 0.7.0 and gr2mpl 0.6.0. The changes listed under 0.6.1 below were not released under their own tag and are part of this release too.

### gpolish

- `gpolish endlabel` takes each label from the plot's legend text when that text differs from the variable label, so a fit line from `lfit`, `qfit` or `lowess` is labelled "Fitted values" and `marginsplot` lines are labelled "Domestic" and "Foreign" as in the legend. Otherwise the raw variable label is used, as before. `labels()` still overrides both.
- `gpolish endlabel` prints a note when two plots would get the same label, suggests `labels()`, and keeps the legend in that case.
- `gpolish clear` with nothing to remove makes no edit and prints nothing. Before, it printed "removed 0 text box(es), ..." and the Graph Editor note.
- `gpolish ptlabel` skips selected points that fall outside the axis range of the plot region and prints a note that gives how many. Before, it labelled them, and the labels sat above the plot or past the edge of the graph. When no selected point is inside the plot region, it makes no edit.
- `gpolish ptlabel` prints a note when it places more than 300 labels, because run time grows quickly with the number of labels. The new option `maxlabels(#)` (default 1000) refuses a larger selection before any edit, with error 198.
- `gpolish endlabel` keeps its record in the graph itself, in one hidden text box, instead of in a session list keyed by graph name and drawing time. A second `endlabel` replaces the first set of labels, and `gpolish clear` restores the margin and the legend, also after arrows, callouts, brackets or leader lines were added and after `graph save` and `graph use` in a new session. A re-run reuses the record box, so a graph has at most one. A graph redrawn under the same name starts without a record.
- After any sequence of `endlabel` runs, one `gpolish clear` returns the plot region and the legend to their state before the first run and removes every added text box, line and marker; a second `clear` makes no edit and prints no note.
- When a recorded end label was changed or removed by other means (for example in the Graph Editor), `endlabel` still gives back the earlier run's margin and restores the legend if that run switched it off. It hides the earlier labels, values and dots that are unchanged, leaves the changed ones as they are, and a note gives their number. Before, the margin stayed and one `clear` left the plot region narrower than before the first run, with the legend off.
- Graphs edited and saved by 0.6.1 or earlier carry no record. On those graphs, `endlabel` and `clear` find earlier end-label runs in the edit log that Stata saves with the graph, undo each run whose margin was not given back, and print a note. Once a 0.7.0 record has been written, the edit log is no longer searched. Edits made to those labels in the Graph Editor are not followed.
- Second axes: `endlabel` labels lines on `yaxis(2)` at their own scale, `gpolish legend` colours their keys, and automatic placement treats them as obstacles. `callout`, `note`, `arrow`, `brace`, `bracket` and `ptlabel` take new `xaxis(#)` and `yaxis(#)` options, and the plot region for those options is found from the axes each region carries. `ptlabel` reads `x()` and `y()` on the plot region where a plot draws them, so points on a second axis need no option; when the variable is drawn only on another axis, it stops before any edit with r(198) and names the option to use. Plain `gpolish` edits every y axis, including a graph whose only y axis is `yaxis(2)`.
- `endlabel` makes room inside the plot region when a y axis is on the labelled side (`side(left)`, `yscale(alt)`, `yaxis(2)`), so labels no longer print over the axis. It keeps labels within the plot height: when they need more height than the plot has, the gaps between neighbours shrink by the same factor. Its note counts pairs whose text overlaps separately from pairs that are only closer than `gap()` asks.
- Automatic placement (`callout` and `note` without `at()`, and `ptlabel`) also avoids bars, areas, range plots (including histograms and confidence bands) and `xline()`/`yline()` reference lines. Obstacle boxes for lines and bands now cover the whole series; above 20,000 boxes per plot, neighbouring boxes are merged instead of dropped.
- Fonts: in batch mode and console Stata, `gpolish` reads the font from `graph set svg fontface`, which Stata uses for PNG export when there is no Graph window. The new global `GPOLISH_FONT` overrides detection, and a note appears when the font cannot be read (before, Helvetica was assumed without a note). Chinese, Japanese and Korean characters are counted as about 1 em wide.
- `gpolish bracket` takes an optional label, expressions in `x()`, `y0()` and `y1()`, and new options `gap()`, `size()` and `color()`; its ticks follow the screen on a reversed axis.
- `gpolish` leaves the caller's `r()` as it found it (except after `geom` and `render`), and position expressions may read `r()`, for example `to(1999 r(max))`.
- Filled `note` and `callout` boxes with `align(left)` or `align(right)` now have their edge on `at()`.
- `gpolish legend` keeps every line of multi-line labels. A label with an unmatched `}` is shown as typed.
- Clearer errors: `plots()` out of range names the plot count; `arrow` with `from()` equal to `to()`, and `segments()` below 1, stop before any edit; `callout` and `note` draw no arrow, with a note, when the target is inside the text; a mistyped subcommand lists the valid ones (r(199)); `ptlabel` gives a note when none of the selected points is drawn; `render` with no graph gives r(111); the refusal on `graph pie` names it.
- Fixed: an internal program returned from inside a loop with a bare `exit`, which under `version 16` does not leave the program.
- `callout` and `note` stop with an error (r(198)) before any edit when `to()`, the point the arrow aims at, lies outside the plot region; the message gives the x and y axis ranges. An `at()` or `from()` outside the plot region gets the same message as a note and is drawn where it was put, so a box placed by hand in the graph margin works as in 0.6.1.
- `arrow` and `brace` print a note when `from()` or `to()` lies outside the plot region, and still draw.
- `callout` and `note` stop with "text is empty" when every text line is blank.
- An automatically placed `callout` or `note` whose text box is wider or taller than the plot region stops with an error instead of drawing off the canvas. `ptlabel` skips labels wider than the plot region and prints a note that gives how many.
- `bracket` stops with an error when `y0()` equals `y1()`, as `arrow` and `brace` do for equal ends. Its label sits at a fixed position beside the spine and is not checked against the data; the help and README now say so.
- `endlabel, values` puts every value in one column, beyond the line end farthest out on the labelled side, so the value of a line that ends early now sits in the column with the others.
- `ptlabel` accepts numeric label variables: the value label is shown when there is one, otherwise the display format; missing values are not labelled.
- `gpolish limits` lines up its columns, describes the matplotlib output as PNG, PDF, SVG or JPG, and lists pie charts as handled by neither command.

### gr2mpl 0.6.0

- graph bar, hbar, box and dot with by(): every panel is now drawn on the scale range Stata shares across the panels, so bars in panels without tick labels have the right height against the labelled axis. by(, yrescale) keeps each panel on its own scale.
- Legends that wrap onto more than one row now read row by row in Stata's order (legend order(), plot order), as Stata fills them; legend(colfirst) fills column by column. This applies to single-graph legends, graph bar legends and the shared by() legend. The spec now records Stata's col_first setting (and rows/cols for graph bar legends).
- graph bar with two over() groups: the outer group labels are now placed below the lowest edge of the inner category labels, after any rotation, so the two rows no longer overprint.
- legend(cols()) and legend(rows()) counts are not followed: gr2mpl fits as many keys per row as the width allows (documented in the help's Limits).
- Second axes: plots on `yaxis(2)` are drawn against that axis wherever they appear in the command, `yaxis(1 2)` keeps both axes, `yline(, axis(2))` and `text(, yaxis(2))` are drawn on the second axis, each y axis is drawn on the side Stata used, and `yscale(alt)` puts the y axis and its title on the right. A layer, reference line or `text()` on a second x axis or a third y axis is skipped with a note and listed in `r(unsupported)`; so is a `by()` graph inside `graph combine`.
- A plot-region margin wider than 4 relative units is kept, so `gpolish endlabel` with an axis on the labelled side renders with the labels between the axis and the lines. `plotregion(margin(large))` is followed.
- Text sizes follow the sizes Stata stored, and panels of `by()`, `graph combine` and `graph matrix` are scaled by Stata's `iscale()` factor, text boxes included. In `graph combine`, each member gets a cell of equal width.
- Legends follow `legend(order())`, keep text-only entries and repeated plots, show a legend `subtitle()`, wrap onto more rows when too wide, and take each key's colour from the right plot when plots share a plot region.
- `gpolish endlabel, values`: values are spaced from label widths measured in matplotlib and paired with their labels by screen position, so they no longer overprint the labels, also on a reversed x axis.
- Newly drawn: horizontal `spike`, `dropline`, `dot`, `area`, `rline` and `rconnected`; `connect(stairstep)` and `connect(stepstair)`; lines that bridge missing values as Stata's `cmissing(y)` does; `mlabformat()`, `mlabvposition()` and `mlabangle()`; marker labels of paired-coordinate plots; `xlabel(, angle())`; boxes of `graph box` groups without whiskers; `text()` boxes inside `graph combine` members.
- SMCL text: `{sup:}`, `{sub:}`, `{&name}` symbols and `{c 0x..}` codes are drawn, and compound-quoted tick labels are drawn on two lines. Characters missing from the main font are drawn with an installed fallback font.
- Date-like tick labels are rewritten only on a daily-date axis and only when every label is its tick's date.
- Fixed: a `by()` graph drawn after a `by()` graph had been put in `graph combine` was drawn as a combine graph.
- gr2mpl needs matplotlib 3.6 or later. The default search (Stata's Python, then `python3`, then `python`) passes over an interpreter whose matplotlib is too old and stops at the first one that is new enough; it stops with error 601 only when none is. The new global `GR2MPL_SEARCH` replaces the search list. Fixed: the search took the last working interpreter instead of the first. `gr2mpl doctor` reports whether matplotlib is new enough and returns `r(mplversion)` and `r(mplok)`.
- Without `keepspec`, gr2mpl deletes its spec folder (the JSON spec and the CSV copies of the data) when it finishes, also after an error, and `r(specdir)` is returned only with `keepspec`. With `keepspec`, the folder also holds `render_info.txt`, a record of what was drawn.
- `saving()` naming a folder that ends in a slash writes `<graphname>_mpl.png` there; `palette()` accepts only `house`; matplotlib's font-fallback warnings are no longer printed.
- `twoway bar` and `twoway rbar` bars narrower than about 0.5% of the x range (for example the default `barwidth()` on a weight axis in pounds) are outlined in their own colour, as Stata draws them, so they show as thin bars instead of disappearing behind a white edge. Wider bars keep their white separators. This also restores the rbar layer in `rarea || rbar` graphs.
- A colour set to `none` is passed to matplotlib as no colour. Before, the spec recorded it as black, so `twoway bar` and `rbar` with `color(none)` or `fcolor(none)` drew black bars; they now draw no fill, as in Stata, with an outline only when the outline colour is visible.
- `area` and `rarea` with `color(none)` draw their outline in `lcolor()`: an `area` gets its top edge and an `rarea` both edges, and the legend key is an outlined box. Stata also draws an `area`'s base and side edges; gr2mpl draws only the top edge. Before, the `area` outline was drawn in white and the `rarea` had no outline. With `lcolor(none)` too, nothing is drawn.
- `scatter` (and other marker plots) with `mcolor(none)` or `mfcolor(none)` and a visible `mlcolor()` draw hollow markers. Before, the spec recorded the marker fill as black, because Stata stores a `none` marker fill as black and only its style name says it is none, so the markers were drawn filled black.

### Benchmark

- The benchmark numbers changed. Release 0.6.1 measured the Open Sans labels with `gpolish`'s Helvetica width table in batch runs; `run_stata.do` and `tune.do` now set the svg font to Open Sans, check that `gpolish` used its Open Sans table, and set the recorded font back afterwards. The six placement settings were not tuned again. adjustText now runs a fixed 100 iterations and ggrepel runs with `max.time = Inf`, so repeated runs give identical positions; ggrepel's label and marker sizes were corrected (they were 0.4 percent too large). `labrepel` gets its seed set before each call, because version 1.0 ignores `seed()`.
- Headline clean shares, release 0.6.1 against this release: `gpolish` with every car labelled 0.34 to 0.49, every country 0.70 to 0.71, 30 of 30 synthetic points 0.98 to 0.99, 60 of 60 synthetic points 0.93 to 0.91; ggrepel with every car labelled 0.59 to 0.57 (every country 0.60, unchanged); adjustText with every car labelled 0.23 to 0.28. The subset scenarios are unchanged for `gpolish` (1.00, 0.84, 0.96).
- New columns: ggrepel given every point and the drawn marker size ("informed"), and `gpolish` with release 0.6.0's hand-set settings.
- New metrics: clean except the label's own marker; leader lines drawn and leaders that cross a label, a marker or another leader; ambiguity split by labels with and without a leader; paired seed-level differences with 95 percent intervals. New scenario sets: 10 random row orders of the real-data scenarios, 150 and 300 points, and other label and marker sizes.
- `score.py` writes every method's measured label boxes, leader lines, geometry and points, and `score.py --rescore` rebuilds the scores from them alone. New `marker_sensitivity.py`, `selftest.py` and `BENCH_SCENARIOS`; `run_stata.do` checks that it runs the package's own `gpolish`.
- benchmark/README.md was rewritten to report every result, including the scenarios and measures where `gpolish` does worse than ggrepel.
- benchmark/README.md: the 150-point paragraph now matches results/summary.md and graphs.csv for adjustText, and the distance finding says `gpolish` places labels farther from their points than ggrepel in every scenario (it said "usually").

### Documentation

- README: describes batch-mode fonts, `GPOLISH_FONT`, the matplotlib 3.6 minimum, second-axis options, the output formats of `gr2mpl`, and the handling of graphs saved by 0.6.1 or earlier; the benchmark paragraph reports the current numbers.
- Gallery: every code block runs as it stands in a fresh Stata session; `gallery/make_page.py` builds the pages, with `--check` and `--blocks` modes, and stops on an unknown argument without writing a file.
- README and help: `geom` is listed with the commands that stop with r(198) on graphs that are not twoway graphs, and the bracket label is described as fixed and not checked against the data.
- Help files and docs/OBJECT_MODEL.md updated for each change above.

## 0.6.1 (2026-11-17)

Not released as a separate tag; these changes are part of 0.7.0. The benchmark figures in this entry come from runs that measured the Open Sans labels with the Helvetica width table; 0.7.0 lists the current figures.

- `gpolish ptlabel`'s placement settings (search rings and their spacing, the cost of moving a label away from its
  point, box height and padding) were chosen on separate tuning scenarios (the hand-set 0.6.0 starting point and the tuning objective were influenced by the test scenarios; see benchmark/README.md); `benchmark/tune.py` reproduces the choice.
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
  with `gr2mpl doctor`; keeps `gpolish` edits in the matplotlib version.
- Scheme `pypolish`.
- Tested on StataNow 19.5 and Stata 16.1 (macOS).
