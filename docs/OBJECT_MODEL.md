# Technical notes: how gr2mpl and gpolish read a Stata graph

`gr2mpl` redraws a Stata graph that is already in memory with matplotlib. It reads the
graph object, not the command syntax, so it works on output from commands it knows
nothing about (`marginsplot`, `coefplot`). Tested on StataNow 19.5 and Stata 16.1; written for
Stata 16+ (`version 16`).

    gr2mpl [, name(graph) saving(file) replace width(#) dpi(#) endlabels nolegend
              palette(house) font(name) nogrid nohalo noticks roundbox
              lwscale(#) msscale(#) python(path) keepspec specdir(dir)]
    gr2mpl doctor [, python(path) font(name)]

`saving()` takes a `.png`, `.pdf`, `.svg` or `.jpg` file name; with no extension the
output is a PNG. The output is an image file, not a Stata graph.

Saved results: `r(filename)`, `r(python)`, `r(pymode)` (`embedded` or `shell`),
`r(unsupported)` (layers that were skipped, `;`-separated), `r(specdir)`. Each skipped
layer also prints `note: gr2mpl skipped ...`.

Pipeline: the ado writes `spec.json` plus one CSV per serset to a spec folder, then runs
`gr2mpl_render.py`, which needs matplotlib and numpy only (no pandas).

## Python discovery

Order: `python()` option, `$GR2MPL_PYTHON`, Stata's embedded Python if it can import
matplotlib (then the renderer runs through `python script`, no shell), then `python3` /
`python` on PATH. The working choice is cached in `$GR2MPL_PYRESOLVED`, `$GR2MPL_PYMODE`
and `$GR2MPL_MPLVERSION` for the session. If nothing works the command exits 601 and
prints the interpreters tried and the exact `pip install` / `set python_exec` fixes.
There is no hardcoded path.

Checking the embedded interpreter initializes Stata's Python, which locks `python_exec`
for the session; that only happens when no explicit choice is given. Windows shell quoting
is untested.

Run the tests from the repository root: `stata-mp -b do tests/gr2mpl_tests.do`. Each case
is exported by Stata and by gr2mpl into `tests/out/` for side-by-side comparison.

## Object-model facts (verified)

Graph level (`.g` = `.graphname`)
- `.g.graphfamily`: `twoway`, `bar` (graph bar/hbar/dot/box and pie all say `bar`), `by`,
  `combine`, `matrix`. A pie chart is told apart by `.g.classname == "piegraph_g"`.
- `.g.n_views`: number of plots; `.g.n_text`: number of `text()` boxes
- `.g.style.declared_xsize.val`, `.declared_ysize.val`: size in inches (default 7.5 x 4.5 with
  stcolor in Stata 19.5, 5.5 x 4 with s2color in Stata 16.1)
- `.g.title.text[k]`, `.subtitle`, `.note`, `.caption`: arrays of lines (`.text.arrnels`)
- `.g.command`: the original command string
- `.g.legend.draw_view.setting` (yes/no); `.g.legend.map[k]` = plot index of entry k;
  `.g.legend.plotregion1.label[k].text[1]` = its label

Axes (`.g.xaxis1`, `.g.yaxis1`)
- `.title.text[k]`
- `.major.dlg_tickpos[k]`, `.major.dlg_ticklabel[k]`: drawn tick positions and labels
  (value labels and date formats already applied); `.major.label_format`
- `.style.draw_major_grid.setting`
- scale: `.g.plotregion1.xscale.curmin/.curmax` (axis range), `.min/.max` (data range),
  `.reverse.setting`, `.transform.setting` (`linear`/`log`)

Plots (`.g.plotregion1.plotN`)
- `.type.setting`: scatter, line, connected, bar, area, rarea, rcap, ...
- `.xvar .yvar .y2var .lvar .wvar`: column POSITIONS in the plot's serset
- `.serset.id`: id for `serset set #`; `serset use, clear` loads the plotted data
- `.serset.sers[k].name/.label/.format`. Names can be stale (tempvars are renamed on
  `serset use`), so columns must be addressed by position, not by name.
- style: `.style.line.color.setting` ("26 133 255 %100"), `.style.line.width.val`,
  `.style.line.pattern.setting`, `.style.marker.symbol.setting`,
  `.style.marker.fillcolor.setting`, `.style.marker.linestyle.color.setting`,
  `.style.marker.size.val`, `.style.area.shadestyle.color.setting`,
  `.style.label.position.setting`
- orientation: `horizontal` is recorded only as `.bar_drop_to.setting == "y"`
- `.base` is missing for the default bar base (0); `.drawn_base` is the clipped value
- reference lines: `.g.plotregion1._xylines[k]` with `.z`, `.ord.setting` (x/y),
  `.style.linestyle.color.setting`
- text boxes: `.g.plotregion1.textboxK` with `.text[k]`, `.xpos.val`, `.ypos.val`

graph bar / hbar
- `.g.plotregion1.bars[k]` holds every drawn rectangle: `.x0 .y0 .x1 .y1` and
  `.style.shadestyle.color.setting`. The category axis runs 0-100.
- `.g.grpaxis.major.dlg_tickpos/.dlg_ticklabel`: group positions and labels;
  `.g.scaleaxis` is the value axis; `.g.horizontal.setting`
- So sorting, stacking and gaps come for free: the rectangles are redrawn as is.
- The serset (`_values _variables <over var> [_grp_sort]`) is not needed.

Sizes
- Every size object (`linewidth`, `symbolsize`, `gsize`) has `.val` (the number as
  typed, in whatever unit) and `.gmval` (converted to relative units). Read `.gmval`:
  `msize(6pt)` has `.val = 6` but `.gmval = 1.67` on a 5-inch-tall graph.
- points = gmval / 100 * min(xsize, ysize) * 72. Line widths and marker sizes are mapped
  with this rule; `lwscale()` / `msscale()` multiply them (`tests/gr2mpl_tests.do` uses
  1.7 / 1.5).

Objects added with gr_edit or the Graph Editor (what gpolish creates)
- counts: `.g.plotregion1.added_text.arrnels`, `.added_lines.arrnels`,
  `.added_markers.arrnels` (empty string, not 0, when there are none)
- text: `.added_text[k].text[i]`, `.xpos.val`, `.ypos.val`, `.style.size.gmval`,
  `.style.color.setting`, `.style.horizontal.setting`, `.style.box_alignment.setting`
  (east = text starts at the point, west = ends at it, north/south = above/below)
- lines: `.added_lines[k].x0/.y0/.x1/.y1`, `.style.linestyle.color.setting`,
  `.style.linestyle.width.gmval`, `.style.headpos.setting`
- markers: `.added_markers[k].x/.y`, `.style.marker.fillcolor.setting`,
  `.style.marker.size.gmval`, `.style.marker.symbol.setting`
- restyled legend labels: `.legend.plotregion1.label[k].style.color.setting`

Log scales
- `dlg_tickpos`, `curmin/curmax` and the serset are all in raw data units, not logged.
  Axis padding must be multiplicative on a log axis (an additive pad went negative and
  collapsed the plot in an earlier version).

Other
- Dates export as strings unless numerics are reformatted (`format %18.0g`) first.
- `.keys[k]` of the legend is an object; expanding it in a macro breaks the parser.

## Supported / not supported

| Graph | Status | How |
|---|---|---|
| twoway line, connected, scatter (+ `mlabel`, value labels) | yes | serset |
| twoway bar, rbar, histogram | yes | histogram is an `rbar` plot |
| twoway area, rarea, lfitci, qfitci | yes | |
| twoway rcap, rspike, rcapsym, rline, rconnected, rscatter | yes | rcap caps are sized by the plot's marker size; rcapsym is drawn as plain spikes, without its end symbols |
| twoway spike, dropline, dot | yes | |
| kdensity, lowess, lfit, `function` | yes | all resolve to `line` |
| pcspike, pcarrow, pcbarrow, pccapsym, pcscatter | yes | class `yxyxview_g`, `.x2var/.y2var` |
| `horizontal` bar / rcap / rspike / rarea | yes | `.bar_drop_to.setting == "y"` |
| second y axis (`yaxis(2)`) | yes | plot lives in `.plotregion2`, axis in `.yaxis2` |
| `xline()`, `yline()`, `text()`, rotated text | yes | |
| gr_edit / gpolish added text, lines, markers | yes | |
| log and reversed scales, date and value-labelled ticks | yes | |
| graph bar, graph hbar (over, several vars, sort, stack) | yes | drawn rectangles |
| graph box, graph hbox | yes | `.plotregion1.boxes[k]`, `.outsides[k]` |
| graph dot | yes | `.plotregion1.points[k]`; `.bars[k]` are the guide lines |
| `by()` on twoway and on graph bar | yes | `.graphs[k]` sub-graphs |
| graph combine | yes | `.graphs[k]`, each drawn by its own family |
| marginsplot, coefplot | yes | twoway underneath |
| contour, contourline | no, skipped with a note | |
| graph pie | no, exits 198 | class `piegraph_g` (its family says `bar`) |
| `x2axis`, `yaxis(3+)` | no | only xaxis1, yaxis1, yaxis2 are read |
| supergroup labels (second `over()`) in graph bar | yes | `.supaxis`, drawn bold |
| `blabel()` bar labels | yes | `.plotregion1.barlabels[k]` |
| marker weights, jitter | no | weighted markers draw at one size |
| `{it:}`, `{fontface}` text tags | stripped | `{bf:}` renders as bold |
| nested combine, by() inside combine | no, panel skipped with a note | |
| tri-panel sharing in `by(, total)` / `holes()` | untested | |

More object paths
- by(): `.g.graphfamily == "by"`, `.g.n`, `.g.rows`, `.g.cols`, `.g.graphs[k]` (each a
  full twoway or bar graph object), panel label in `.g.graphs[k].subtitle.text[1]`,
  shared legend in `.g.legend`, overall title/note at `.g.title` / `.g.note`. A panel's
  suppressed axis shows as `.graphs[k].yaxis1.draw_view.setting == "no"`.
- combine: `.g.graphfamily == "combine"`, same `.graphs[k]` array; each member keeps its
  own title, axes and legend.
- box: `.plotregion1.boxes[k]` with `.z` (category position, 0-100), `.p25 .p50 .p75
  .adjl .adjh .width2 .horizontal`, colour in `.rect.style.shadestyle.color.setting`;
  outside values in `.plotregion1.outsides[k].x/.y`.
- dot: `.plotregion1.points[k].x/.y` and `.style.marker.fillcolor.setting`.
- second axis: `.g.n_plotregions`, `.g.y_scales` (one quoted axis number per plot);
  plot i is `.plotregionJ.plotI` for the region that has it.
- text rotation: `.textboxK.style.angle.setting` (a number, or `horizontal`/`vertical`)
  and `.orientation.setting`; the same members on `.added_text[k]`. Stata itself draws
  `text(, angle(30))` flat; gr2mpl honours the stored angle.
- marker value labels: not on the serset data, but in the class as
  `.plotN.serset.sers[k].vlabs.__D_<value>`.
- A member that does not exist expands to an empty string (no error), which is how the
  ado tests for optional objects.
- JSON trap: Stata prints `.02`; tick positions are written as strings.

## Deliberate departures from the Stata graph

- y-axis title moves above the plot as a subtitle line when all panels share it; with
  two y axes, or panels with different titles, it stays on the axis.
- Legend moves above the plot (one shared legend for by()); `endlabels` replaces it with
  repelled end-of-line labels (single-panel graphs only).
- by() panel labels are bold left-aligned titles, not shaded strips.
- Bars always show their base: test 04 has a y axis starting at 2 in Stata, 0 in gr2mpl.
- Black reference lines and text become gray; opaque CI bands become translucent.
- `%td` tick labels like `01jan2001` are rewritten as `Jan 2001`.
- Short outside tick marks on the x axis (off with `noticks`); none on the y axis.
- Annotation text has a thin white halo (1.6 pt stroke; off with `nohalo`).
- Box-plot outside values are hollow circles; whisker caps are not drawn.
- When every layer on the second y axis is filled (bar, rbar, area, rarea, spike), the
  second axis is drawn behind the first.
- Line widths and marker sizes follow Stata exactly unless `lwscale()`/`msscale()` is set.
- Graph-margin edits made by gpolish are ignored; the layout is refit around whatever
  text extends past the axes, so end labels are never clipped.

## Known weaknesses

- Stata 17 and 18 are not tested, nor is Windows. All member paths are undocumented and
  could change.
- Marker-label collisions are not resolved (only end-of-line labels are repelled).
- Curved callout arrows arrive as many short straight segments, which is how they are
  stored.
- In combine, a panel with both a title and a legend stacks them above the plot, which
  costs height.
- The output image (PNG, PDF, SVG or JPG) is not a Stata graph: no further
  `graph combine`, no Graph Editor.

## What gpolish adds to the same object model

`gpolish` reads the same graph object and writes back to it with `gr_edit`.

- Transform: `.g.plotregion1.drawn_xalpha/.drawn_xbeta/.drawn_yalpha/.drawn_ybeta` map data to
  device units (device = alpha + beta * data; log axes use the natural log of the data).
  `.gdi_x0 .gdi_x1 .gdi_y0 .gdi_y1` give the plot box. Device units per inch are
  `.g.gdi_y1 / ysize`, with the size taken from `graph describe`.
- Sizes: a relative size unit is 1 percent of min(xsize, ysize); points convert through that.
- Adding objects: `gr_edit .plotregion1.AddTextBox added_text editor <y> <x>`,
  `.AddLine added_lines editor <x0> <y0> <x1> <y1>`, `.AddMarker added_markers editor <x> <y>`,
  each followed by `added_*_new = k`, `added_*_rec = k` and a `.style.editstyle ... editcopy`.
- Text boxes: `box_alignment(east)` extends the text to the right of the point, `west` to the
  left, `north` and `south` above and below. `angle()` is stored but only quarter turns draw
  (`.orientation.setstyle, style(vertical)`).
- Stata does not report text width. `gpolish` embeds advance-width tables for common fonts
  (see `build/make_fontwidths.py`) and picks one from `graph set window fontface`.
- Scheme note: in the s2color family, `draw_major_vgrid yes` switches on the horizontal
  gridlines (the entry is named for the axis the lines come from).

## Boxed text

Members of a text box object, for both `text()` boxes (`.plotregion1.textboxK`) and
boxes added through the Graph Editor interface (`.plotregion1.added_text[k]`):

| Member | Meaning |
|---|---|
| `.style.drawbox.setting` | `yes` when a box is drawn |
| `.style.fillcolor.setting` | fill, e.g. `226 238 246 %90` |
| `.style.linestyle.color.setting` | outline colour |
| `.style.linestyle.width.gmval` | outline width in relative units; `0` for `width(none)` |
| `.style.boxmargin.gleft/.gright/.gbottom/.gtop.gmval` | `boxmargin()` padding |
| `.style.margin.gleft/.gright/.gbottom/.gtop.gmval` | `margin()` padding, used by `text(, box margin())` |

`linestyle(color(none) width(none))` reads back as colour `0 0 0 %100` with width `0`,
so the width, not the colour, says whether there is an outline. gr2mpl draws a filled
rectangle with the two paddings added (square corners, or rounded with `roundbox`); a
white fill with no outline is treated as a halo and drawn as a thin stroke around the
glyphs. Boxed text is not rotated.

## graph matrix

- `.g.graphfamily == "matrix"`, `.g.nvars`.
- Cell (row i, column j): `.g.plotregion1.plotregion<i>_<j>.plot1`, an ordinary scatter
  view with its own `.xscale` / `.yscale`. With `half` only i > j exists.
- Diagonal titles: `.g.plotregion1.titlegrid<k>.variable_title<k>.text[1..]`.
- Tick sets per variable: `.g.plotregion1.xaxis<k>` or `.yaxis<k>`; only some exist, so
  the one that is present for a variable is used for both directions.

## graph bar: labels

- `blabel()` texts: `.g.plotregion1.barlabels[k]` with `.text[1]`, `.xpos.val`,
  `.ypos.val` (plot-region units) and `.style.box_alignment.setting`.
- Second-level `over()` labels: `.g.supaxis.major.dlg_tickpos[k]` / `.dlg_ticklabel[k]`.
  With several variables and one `over()`, the variables are on `.grpaxis` and the
  groups on `.supaxis` or the reverse, depending on `ascategory`; both arrays are read.

## Polygon areas (heatplot)

`heatplot` draws each colour class as one `area` plot with `nodropbase`: the serset holds
closed polygons separated by missing rows. `.plotN.drop_base.setting == "no"` marks
them. The legend is ordinary (`.legend.map`, labels, and the heading in
`.legend.subtitle.text[1]`); five or more polygon classes are drawn as a stepped
colour bar.

## Axes switched off

`xscale(off)` / `yscale(off)` show as `.xaxis1.draw_view.setting == "no"`. The axis
line, ticks, labels, title and the grid belonging to that axis are then left out.

## Known differences found with these graph types

- `cluster dendrogram`: the spikes are drawn in the colour stored in
  `.style.line.color` (black), while Stata draws them in the scheme's first plot colour.
- `graph matrix` without `half`: tick labels are drawn on the left and bottom edges
  only, so the first row and last column have none.
- Marker labels are not moved apart; a dense `lvr2plot` overprints as it does in Stata.

## Further members read

- Legend layout: `.legend.style.rows.val` (0 when not set), `.legend.style.cols.val`,
  and the legend's clock position in `.g.style.legend_position.setting`. `rows(1)` keeps
  the legend on one row; a polygon colour key at positions 2-4 without `rows(1)` is
  drawn as a vertical ramp at the right, low values at the bottom.
- `xscale(noline)` does not change `.xaxis1.style.linestyle` members. It is visible only
  in the construction log: an entry of `.g.__LOG[]` containing
  `.xaxis1.style.editstyle  linestyle(none)`. gr2mpl scans the log for it.
- Grid: `.xaxis1.style.draw_major_grid.setting` / `.yaxis1...` are honoured, so
  `xlabel(, nogrid)` and `ylabel(, nogrid)` remove the corresponding grid lines.
- `rcap` cap size is the plot's marker size (`.style.marker.size.gmval`); `msize(zero)`
  gives plain spikes.
- Paired-coordinate plots drawn `horizontal` (for example `cluster dendrogram,
  horizontal`) keep the serset unswapped and set `.bar_drop_to.setting` to `y`; the
  two coordinate pairs are swapped when drawing.

