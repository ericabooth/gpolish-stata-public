{smcl}
{* *! version 0.7.0  18nov2026}{...}
{viewerjumpto "Syntax" "gpolish##syntax"}{...}
{viewerjumpto "Description" "gpolish##description"}{...}
{viewerjumpto "Subcommands" "gpolish##subcommands"}{...}
{viewerjumpto "Limits" "gpolish##limits"}{...}
{viewerjumpto "Examples" "gpolish##examples"}{...}
{viewerjumpto "Technical notes" "gpolish##technical"}{...}
{title:Title}

{phang}
{bf:gpolish} {hline 2} Polish a Stata graph after it is drawn: direct labels, callouts and point labels placed by a layout step


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}{cmd:gpolish} [{cmd:style}] [{cmd:,} {opt name(graphname)} {opt nobold} {opt keepyl:ine} {opt keepyt:icks}]

{p 8 16 2}{cmd:gpolish endlabel} [{cmd:,} {opt name(graphname)} {opt plot:s(numlist)} {opt lab:els(strlist)} {opt val:ues}
{opt for:mat(%fmt)} {opt dot:s} {opt dotsi:ze(#)} {opt sid:e(right|left)} {opt col:or(rgb)} {opt keepl:egend}
{opt siz:e(#)} {opt gap(#)} {opt xg:ap(#)} {opt wrap(#)} {opt nobold} {opt norepel}]

{p 8 16 2}{cmd:gpolish callout} {it:"line 1"} [{it:"line 2"} ...]{cmd:,} {c -(}{opt at(x y)} | {opt to(x y)}{c )-}
[{opt fr:om(x y)} {opt cur:ve(#)} {opt siz:e(#)} {opt col:or(rgb)} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt al:ign(str)}
{opt ang:le(#)} {opt halo} {opt noarrow} {opt head:size(#)} {opt seg:ments(#)} {opt fill(rgb)} {opt bor:der(rgb)} {opt pad(#)}
{opt xax:is(#)} {opt yax:is(#)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish note} {it:"line 1"} [{it:"line 2"} ...]{cmd:,} {c -(}{opt at(x y)} | {opt to(x y)}{c )-}
[{opt fill(rgb)} {opt bor:der(rgb)} {opt pad(#)} {it:callout_options}]

{p 8 16 2}{cmd:gpolish brace} [{it:"label line 1"} ...]{cmd:,} {opt fr:om(x y)} {opt to(x y)}
[{opt w:idth(#)} {opt flip} {opt gap(#)} {opt siz:e(#)} {opt col:or(rgb)} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt xax:is(#)} {opt yax:is(#)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish arrow,} {opt fr:om(x y)} {opt to(x y)}
[{opt cur:ve(#)} {opt head:size(#)} {opt seg:ments(#)} {opt shr:ink(#)} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt xax:is(#)} {opt yax:is(#)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish ptlabel} {it:varname} {ifin}{cmd:,} {opt x(varname)} {opt y(varname)}
[{opt siz:e(#)} {opt col:or(rgb)} {opt off:set(#)} {opt ms:ize(#)} {opt halo} {opt nolead:er} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt xax:is(#)} {opt yax:is(#)} {opt maxl:abels(#)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish bracket} [{it:"label line 1"} ...]{cmd:,} {c -(}{opt x(#)} {opt y0(#)} {opt y1(#)} [{opt left}] | {opt y(#)} {opt x0(#)} {opt x1(#)} [{opt below}]{c )-} [{opt tick(#)} {opt gap(#)} {opt siz:e(#)} {opt col:or(rgb)} {opt lc:olor(rgb)} {opt lw:idth(str)}
{opt xax:is(#)} {opt yax:is(#)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish legend} [{cmd:,} {opt plot:s(numlist)} {opt nobold} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish clear} [{cmd:,} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish render} [{cmd:,} {opt name(graphname)} {it:gr2mpl_options}]

{p 8 16 2}{cmd:gpolish limits}

{p 8 16 2}{cmd:gpolish geom} [{cmd:,} {opt name(graphname)}]

{pstd}All sizes are in points. Positions are in the units of the graph's axes.
Each value in {opt at()}, {opt to()}, {opt from()} and the {opt x()}, {opt y0()}, {opt y1()}, {opt y()}, {opt x0()} and {opt x1()} of {cmd:bracket}
may be a number or an expression written without spaces, such as {cmd:to(td(21sep2001) 966)} on a date axis.
An expression may use the results of the previous command, such as {cmd:to(1999 r(max))} after {cmd:summarize}.
Positions are read on the first x and y axes; on a graph with a second axis, {opt xaxis(#)} and {opt yaxis(#)}
say which axis the positions belong to. {cmd:ptlabel} finds the axes of its {opt x()} and {opt y()} variables
itself (see below); for it, {opt xaxis()} and {opt yaxis()} name the axes to read them on instead.
{opt name()} picks a graph in memory other than the current one.

{pstd}{cmd:gpolish} is not an r-class command: it leaves {cmd:r()} as it found it, except {cmd:gpolish geom},
which returns the geometry, and {cmd:gpolish render}, which returns the results of {helpb gr2mpl}.


{marker description}{...}
{title:Description}

{pstd}
{cmd:gpolish} works on a graph that is already drawn and held in memory. It reads the graph's own geometry,
works out where labels and notes fit, and then adds them to the graph. The result is still a Stata graph:
you can keep editing it, combine it, and export it to any format.

{pstd}
Because it reads the drawn graph and not your command, it also works on graphs made by other commands
that produce {helpb twoway} graphs, such as {helpb marginsplot}.

{pstd}
Use it with the scheme {cmd:pypolish} (shipped with this package), which sets the static defaults:
white background, left-aligned titles, light horizontal grid, horizontal axis labels and a restrained palette.
{cmd:gpolish} also works with any other scheme.

{pstd}
Some effects are beyond Stata's graph renderer. {cmd:gpolish} says so when you ask for one,
and {cmd:gpolish render} redraws the finished graph with matplotlib (see {helpb gr2mpl}), carrying every
{cmd:gpolish} edit across. See {help gpolish##limits:Limits}.


{marker subcommands}{...}
{title:Subcommands}

{phang}
{cmd:gpolish} [{cmd:style}] makes the title bold and removes the y-axis line and its tick marks.
{opt nobold}, {opt keepyline} and {opt keepyticks} switch each change off.

{phang}
{cmd:gpolish endlabel} replaces the legend with a label at the end of each line, in the line's color.
Labels that would overlap are moved apart, and the margin grows to fit the longest label.
The legend is switched off; {opt keeplegend} keeps it.
By default every line plot is labeled; {opt plots()} names the plots to label by number, and series with no
nonmissing values are skipped with a note.
Label text is the plot's legend text when it differs from the variable label, as it does for a fit line from {cmd:lfit} or a line drawn by {cmd:marginsplot}; otherwise it is the variable label.
{opt labels()} overrides both, one label per plot in the order of {opt plots()}.
When two plots would get the same label, {cmd:endlabel} prints a note, keeps the legend and suggests {opt labels()}.
{opt values} adds the last value in a column, formatted with {opt format()}. The column sits beyond the line end
farthest out on the labeled side, so a line that ends early still has its value in the same column.
{opt dots} adds a marker at each line end. {opt dotsize(#)} sets its size in points (default 5.5) and implies {opt dots}. {opt color()} sets one text color for all labels instead of each line's color.
{opt side(left)} labels the left ends of the lines instead of the right; on a reversed axis
({cmd:xscale(reverse)}) the labels follow the screen, not the data.
Normally the labels go into the graph margin beside the plot. When a y axis is drawn on the labeled side
(the usual left axis with {opt side(left)}, or an axis moved right with {cmd:yscale(alt)} or {cmd:yaxis(2)}),
the room is made inside the plot region instead, so the labels sit between the axis and the lines.
Lines on a second y axis are labeled at their own scale.
{opt wrap(#)} wraps long labels on word boundaries at about # characters, measured by rendered width.
{opt gap(#)} sets the minimum distance between the centres of neighbouring labels, in multiples of the font size per text line (default 1.3); wrapped labels get proportionally more room.
Labels are kept within the height of the plot. When the labels need more height than the plot has, the first
and last labels keep their room at the edges and every distance between neighbouring labels shrinks by the same
factor, so the labels fill the plot height evenly in the order of the line ends, and {cmd:gpolish endlabel} gives
a note. The note counts only the pairs of neighbouring labels that had to be placed closer than {opt gap()}
asks: first the pairs among them whose text overlaps (the text of a line is taken to span about 0.95 of the
font size), then, separately, the pairs among them that do not overlap. Labels placed as far apart as
{opt gap()} asks are not counted, so with a {opt gap()} below about 0.95 neighbouring labels can touch or
overlap without a note.
Labels are bold unless {opt nobold} is given; a label with an unmatched {cmd:{c )-}} is shown as typed, because the
brace would end the bold markup early.
Running {cmd:gpolish endlabel} again replaces the earlier labels instead of adding a second set.

{phang}
{cmd:gpolish callout} adds a note of one or more lines, with a curved arrow to {opt to()}.
If {opt at()} is omitted, the note is placed automatically near the target, clear of what is already drawn:
the markers and lines of scatter, line, connected, rline, function, spike and dropline plots; bars, shaded areas
and range plots (bar, rbar, area, rarea, rcap, rspike, rcapsym, which include histograms and confidence bands);
reference lines from {opt xline()} and {opt yline()}; and other added text.
Lines and shaded areas are covered by small boxes along their whole length. When one plot would need more than
20,000 boxes, neighbouring boxes are merged in groups of equal size, each merged box covering its whole group.
{opt from()} moves the tail of the arrow; by default it starts at the edge of the text nearest the target.
When the target lies inside the text, or {opt from()} equals {opt to()}, no arrow is drawn and {cmd:gpolish} says so.
{opt segments(#)} must be 1 or more.
{opt curve(#)} sets the bend (0 is straight; the sign sets the side).
{opt halo} draws a white box behind the text.

{phang}
{cmd:gpolish note} adds a shaded box of text, for a finding or a call-out. It takes the same options as
{cmd:gpolish callout}; the difference is that it draws a shaded box by default. {opt fill()} and {opt border()}
change the box colors (the default border is used only when {opt fill()} is not given), and {opt pad(#)} sets the
padding in points. {cmd:gpolish callout} draws the same box when {opt fill()} is given.
With {opt to()} it draws an arrow from the box; with {opt at()} alone it is a plain box.
{cmd:callout} and {cmd:note} stop with an error when the text is empty, when {opt to()} lies outside
the plot region (the message gives the axis ranges), or, with automatic placement, when the text box is wider or
taller than the plot region. An {opt at()} or {opt from()} outside the plot region gets a note and is drawn where
it is, so a box can still be placed by hand in the graph margin.
With the default {opt align(left)} the left edge of the box sits on {opt at()}, with {opt align(right)} its right
edge does, and with {opt align(center)} the box is centered on {opt at()}, which suits flow charts.

{phang}
{cmd:gpolish brace} draws a curly brace between two points, with an optional label at its tip.
Use it to mark a confidence interval, a gap between two values, or a range on an axis.
The tip points to the left of the direction from {opt from()} to {opt to()}; {opt flip} turns it to the other side.
{opt width(#)} is the depth of the brace in points.

{phang}
{cmd:gpolish arrow} draws an arrow between two points, straight by default; {opt curve(#)} bends it.
{opt from()} and {opt to()} must be different points. When either lies outside the plot region,
{cmd:arrow} (and {cmd:brace}) prints a note and still draws.
Together with {cmd:gpolish note} it builds simple flow charts on an empty plot.

{phang}
{cmd:gpolish ptlabel} labels selected points of a scatterplot with the variable {it:varname}.
A string variable is used as it is. A numeric variable is shown with its value label when it has one and
otherwise with its display format, as {cmd:mlabel()} does; points with a missing value are not labeled.
Each label is tried in eight positions next to its point and placed where it overlaps markers, lines and other
labels least. If even the best of the eight still overlaps something, the label is also tried farther out, on
rings around its point, and joined to the point by a thin leader line; it moves out only when that spot costs less
than the best spot next to the point. {opt noleader} keeps every
label next to its point; {opt lcolor()} and {opt lwidth()} style the leader lines.
{opt x()} and {opt y()} name the plotted variables. Their values are read on the scales of the plot region
where a plot draws {opt y()} against {opt x()}, so points plotted on a second axis need no option. When no plot
draws that pair, the first plot region that carries an axis {opt y()} is drawn on and an axis {opt x()} is drawn
on is used. A variable that no plot draws puts no condition on the region, so when neither is drawn the first
plot region is used. {opt yaxis(#)} and {opt xaxis(#)} limit the choice to the plot regions that carry those axes.
When the {opt y()} variable is drawn only on other y axes than {opt yaxis()} names (or the {opt x()} variable
only on other x axes than {opt xaxis()} names), or when no plot region carries an axis of each variable,
{cmd:gpolish ptlabel} stops before any edit and names the option to use. Log axes are detected, and points with zero or negative values on a log axis are skipped.
Selected points that fall outside the axis range of the plot region are skipped with a note that gives how many.
A label wider than the plot region is skipped with a note; shorten it or use a smaller {opt size()}.
{cmd:ptlabel} is meant for tens to a few hundred labels. Above 300 labels it prints a note, because run time
grows quickly with the number of labels (about 40 seconds for 600). {opt maxlabels(#)} refuses a selection of more
than # points before any edit; the default is 1000.
Placement avoids the same drawn objects as an automatic {cmd:gpolish callout}.

{phang}
{cmd:gpolish bracket} draws a square bracket from {opt y0()} to {opt y1()} at {opt x()}.
Its ticks point right on the screen, whatever the axis direction; {opt left} points them left.
With {opt y()}, {opt x0()} and {opt x1()} instead, it draws a horizontal bracket from {opt x0()} to {opt x1()} at {opt y()},
as used to mark a comparison between two bars. Its ticks point down, and its label is centred above the spine;
{opt below} puts the ticks up and the label below. Give one set of positions or the other; a mix stops with r(198).
{opt tick(#)} sets their length in points. An optional label sits beside the middle of the bracket, on the side
away from the ticks, {opt gap(#)} points from it. The label's position is fixed: unlike the other layout commands,
{cmd:bracket} does not check it against markers, lines, bars or earlier labels, and prints no note if they overlap.
The two ends ({opt y0()} and {opt y1()}, or {opt x0()} and {opt x1()}) must differ. For a curly brace, use {cmd:gpolish brace}.

{phang}
{cmd:gpolish legend} colors each legend label to match its key and makes it bold. Labels of more than one
line keep every line. Each label takes the color of the key beside it, also when the legend uses {cmd:order()}.
{opt plots()} names the plots whose labels are colored, by plot number; the other labels are left as they are.

{phang}
{cmd:gpolish clear} removes every added text box, line and marker from the graph and undoes the margin and legend
changes of {cmd:gpolish endlabel}, including those made by {cmd:gpolish} 0.6.1 or earlier (see
{help gpolish##technical:Technical notes}). It keeps the title and axis edits of plain {cmd:gpolish}. It also
removes anything added by hand in the Graph Editor.
It reports how many objects it removed; when there is nothing to remove it makes no edit and prints nothing.

{phang}
{cmd:gpolish render} passes the graph to {helpb gr2mpl}, which redraws it with matplotlib and writes a PNG, PDF,
SVG or JPG file. {cmd:gpolish limits} lists what needs it.

{phang}
{cmd:gpolish geom} reports the drawn geometry of a graph for programmers: the size in inches in {cmd:r(xsize)} and
{cmd:r(ysize)}, the plot box in device units in {cmd:r(gx0)}, {cmd:r(gx1)}, {cmd:r(gy0)} and {cmd:r(gy1)}, the
data-to-device transform in {cmd:r(xa)}, {cmd:r(xb)}, {cmd:r(ya)} and {cmd:r(yb)} (device = a + b * data, with the
natural log of the data on a log axis, flagged in {cmd:r(xlog)} and {cmd:r(ylog)}), device units per inch in
{cmd:r(gpi)}, relative size units per point in {cmd:r(relperpt)}, and the graph's name in {cmd:r(name)}.
Like the layout commands, {cmd:geom} works on twoway graphs only and stops with r(198) on other graph families.


{marker limits}{...}
{title:Limits}

{pstd}Stata's renderer cannot draw the first four items below; the others are limits of {cmd:gpolish} itself.
{cmd:gpolish} prints a note for text at an unsupported angle, for inline color tags in the graph title, and when
{cmd:endlabel}, {cmd:ptlabel} or an automatically placed callout or note cannot place every label without overlap.
It stops with an error when {cmd:endlabel}, {cmd:callout}, {cmd:note}, {cmd:arrow}, {cmd:brace}, {cmd:bracket},
{cmd:ptlabel}, {cmd:legend}, {cmd:geom} or {cmd:clear} is used on a graph that is not a twoway graph.

{p2colset 8 46 48 2}{...}
{p2col:Limit}What happens{p_end}
{p2line}
{p2col:Text at an angle other than 0, 90 or 270}the angle is stored; {cmd:gpolish render} applies it{p_end}
{p2col:Soft halo behind text}{opt halo} draws a white box, which can cover nearby markers{p_end}
{p2col:Different colors inside one line of text}not possible; color whole labels{p_end}
{p2col:Filled arrow heads}arrow heads are open{p_end}
{p2col:Labels that cannot all fit}{cmd:endlabel} reports how many pairs of labels overlap among the pairs it placed closer than {opt gap()} asks; {cmd:ptlabel} and automatic callouts report how many labels still overlap noticeably{p_end}
{p2col:{cmd:graph bar}, {cmd:by()} and combined graphs}layout commands and {cmd:geom} are refused with a message; plain {cmd:gpolish} still makes the title bold; {helpb gr2mpl} redraws them{p_end}
{p2col:{cmd:graph pie}}layout commands are refused; {helpb gr2mpl} does not redraw pie charts either{p_end}
{p2col:{cmd:ptlabel} on many points}run time grows quickly with the number of labels; a note is printed above 300 labels and more than {opt maxlabels()} (default 1000) are refused{p_end}
{p2col:{cmd:bracket} labels}placed at a fixed spot beside the spine and not checked against the data or other labels; move the bracket with {opt x()} or {opt left} (or {opt y()} or {opt below}) if its label covers something{p_end}
{p2col:{cmd:endlabel} with {cmd:aspectratio()}}when a y axis is drawn on the labeled side, the room for labels would have to be made inside a plot region whose shape is fixed, which distorts the axes; {cmd:endlabel} stops with r(198) before any edit. Drop {cmd:aspectratio()} or label the other side with {opt side()}{p_end}
{p2col:Positions outside the plot region}{cmd:callout} and {cmd:note} refuse a {opt to()} outside the axis ranges; {opt at()}, {opt from()}, {cmd:arrow} and {cmd:brace} get a note; ranges are given in the axis's own units, so dates show as numbers{p_end}
{p2col:Labels wider than the plot region}{cmd:ptlabel} skips them with a note; an automatically placed callout or note stops with an error; {cmd:gpolish} does not wrap text itself{p_end}
{p2col:Positions on a second axis}{opt at()}, {opt to()} and {opt from()} use the first axes unless {opt xaxis()} or {opt yaxis()} says otherwise{p_end}
{p2col:Graphs edited by {cmd:gpolish} 0.6.1 or earlier}these carry no {cmd:endlabel} record; their end labels are found in the graph's edit log (see {help gpolish##technical:Technical notes}){p_end}
{p2line}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. sysuse uslifeexp, clear}{p_end}
{phang2}{cmd:. graph set window fontface "Open Sans"}{p_end}
{phang2}{cmd:. line le_wfemale le_wmale le_bfemale le_bmale year, scheme(pypolish) legend(off) xsize(7.5) ysize(5) title("Life expectancy rose for every group", size(14pt))}{p_end}
{phang2}{cmd:. gpolish}{p_end}
{phang2}{cmd:. gpolish endlabel, values dots}{p_end}
{phang2}{cmd:. gpolish callout "1918 influenza" "pandemic", to(1918.6 30.6)}{p_end}
{phang2}{cmd:. graph export life.png, width(2400) replace}{p_end}

{pstd}In batch mode ({cmd:stata -b}), {cmd:graph set window fontface} is not available; use
{cmd:graph set svg fontface "Open Sans"} instead (see {help gpolish##technical:Technical notes}).{p_end}

{pstd}A line on a second axis, labeled at its own scale, and a note placed on that axis:{p_end}
{phang2}{cmd:. sysuse uslifeexp, clear}{p_end}
{phang2}{cmd:. generate pop = 1000 + 20*(year-1900)}{p_end}
{phang2}{cmd:. twoway (line le year) (line pop year, yaxis(2)), scheme(pypolish)}{p_end}
{phang2}{cmd:. gpolish endlabel, values}{p_end}
{phang2}{cmd:. gpolish callout "Index 2000", to(1950 2000) yaxis(2)}{p_end}

{pstd}A graph from another command:{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. regress wage c.ttl_exp##i.collgrad}{p_end}
{phang2}{cmd:. margins collgrad, at(ttl_exp=(0(4)28))}{p_end}
{phang2}{cmd:. marginsplot, scheme(pypolish) recast(line) recastci(rarea) legend(off)}{p_end}
{phang2}{cmd:. gpolish endlabel, labels("No degree" "College graduate") values format(%4.2f)}{p_end}

{pstd}A note on a date axis, then undo everything and start again:{p_end}
{phang2}{cmd:. sysuse sp500, clear}{p_end}
{phang2}{cmd:. line close date, scheme(pypolish)}{p_end}
{phang2}{cmd:. gpolish callout "Low of 966", to(td(21sep2001) 966)}{p_end}
{phang2}{cmd:. gpolish clear}{p_end}


{marker technical}{...}
{title:Technical notes}

{pstd}
Requires Stata 16 or later. {cmd:gpolish} relies on undocumented members of Stata's graph objects and on
{cmd:gr_edit}, the command the Graph Editor records. These could change in a future release.

{pstd}
Stata does not report how wide a piece of text is. {cmd:gpolish} uses built-in character-width tables for
common fonts (Open Sans, Helvetica, Arial, Verdana, Tahoma, Trebuchet MS, Avenir, Gill Sans, Times, Georgia,
Palatino, Courier New, Menlo and a few variants) and picks the table for the font Stata exports with.
With a Graph window, that is the font set by {cmd:graph set window fontface}. In batch mode ({cmd:stata -b}) and
in console Stata there is no Graph window, {cmd:graph set window fontface} is not available, and Stata exports
PNG files with the font set by {cmd:graph set svg fontface}; {cmd:gpolish} then reads that setting.
To name the font yourself, for example for PDF export, set {cmd:global GPOLISH_FONT "Open Sans"}; it overrides both.
For a font without a table {cmd:gpolish} uses Arial's widths and says so; spacing is then approximate.
If it cannot read the font at all, it assumes Helvetica and says so.
Characters outside ASCII are measured by class: Chinese, Japanese and Korean characters as about 1 em,
accented Latin, Greek and Cyrillic letters as an average width.

{pstd}
Set {opt xsize()} and {opt ysize()} to the size the graph will be printed at, and give text sizes in points.
Run {cmd:gpolish} after the graph has its final size, because positions are solved for that size: resizing
afterwards with {cmd:graph display, xsize() ysize()} moves the plot but not the labels. To resize, redraw the
graph, or run {cmd:gpolish clear} and the layout commands again.

{pstd}
Text keeps {cmd:$} and backtick characters literally; they are stored as {cmd:{c -(}c 36{c )-}} and {cmd:{c -(}c 96{c )-}}.

{pstd}
{cmd:gpolish endlabel} keeps a record of what it added (the text boxes, markers, margin and legend change) in a
hidden text box inside the graph. The record belongs to that graph only, and it is saved with the graph, so after
{cmd:graph save} and {cmd:graph use} a second {cmd:gpolish endlabel} still replaces the first set of labels and
{cmd:gpolish clear} still restores the margin and the legend. A graph redrawn under the same name starts with no
record. Each {cmd:endlabel} run undoes the run before it, so after any number of runs one {cmd:gpolish clear}
returns the graph to its layout before the first run: the plot region where it was, the legend shown or hidden as
it was, and no added objects. A second {cmd:gpolish clear} changes nothing. If a recorded label was changed or
removed by other means (for example in the Graph Editor), the next {cmd:endlabel} leaves that label as it is,
hides the other labels of the earlier run, gives back its margin and restores the legend, and prints a note;
{cmd:gpolish clear} removes every added text box. A graph holds at most one record box: a second
{cmd:gpolish endlabel} writes its record into the box of the first. The record box is not drawn, but it is listed
in the Graph Editor's object browser, and scripts that count {cmd:.plotregion1.added_text} should skip boxes whose
text starts with {cmd:gpolish-endlabel}.

{pstd}
{cmd:gpolish} 0.6.1 and earlier kept no such record. On a graph without a record, {cmd:gpolish endlabel} and
{cmd:gpolish clear} look for the end labels of those releases in the graph's edit log, the list of edits that
Stata keeps in every graph and saves with it. An earlier {cmd:endlabel} run shows there as a margin edit on the
graph, followed by the legend switched off (unless {opt keeplegend} was given) and the label boxes. Each run whose margin was not given back
later is undone: its labels, values and dots are hidden, its margin is given back, and the legend is shown again
if that run switched it off. A note says so when this happens. Changes made to those labels in the Graph Editor
are not followed; if the result looks wrong, redraw the graph. Once {cmd:gpolish} 0.7.0 or later has written an
{cmd:endlabel} record into a graph, the edit log is no longer searched, because that release has already undone
the earlier runs.


{title:Author}

{pstd}
Eric A. Booth{break}
Sr Researcher, Texas 2036{break}
{browse "mailto:eric.a.booth@gmail.com":eric.a.booth@gmail.com}{break}
{browse "https://github.com/ericabooth":github.com/ericabooth}{p_end}

{pstd}
Issues and suggestions:
{browse "https://github.com/ericabooth/gpolish-stata-public/issues":github.com/ericabooth/gpolish-stata-public/issues}{p_end}


{title:Also see}

{psee}{helpb gr2mpl}, {helpb schemes}, {helpb graph_editor:graph editor}{p_end}
