{smcl}
{* *! version 0.5.0  17nov2026}{...}
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

{p 8 16 2}{cmd:gpolish endlabel} [{cmd:,} {opt name(graphname)} {opt plots(numlist)} {opt lab:els(strlist)} {opt val:ues}
{opt for:mat(%fmt)} {opt dot:s} {opt dots:ize(#)} {opt sid:e(right|left)} {opt col:or(rgb)} {opt keepl:egend}
{opt siz:e(#)} {opt gap(#)} {opt xg:ap(#)} {opt wrap(#)} {opt nobold} {opt norepel}]

{p 8 16 2}{cmd:gpolish callout} {it:"line 1"} [{it:"line 2"} ...]{cmd:,} {c -(}{opt at(x y)} | {opt to(x y)}{c )-}
[{opt fr:om(x y)} {opt cur:ve(#)} {opt siz:e(#)} {opt col:or(rgb)} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt al:ign(str)}
{opt ang:le(#)} {opt halo} {opt noarrow} {opt head:size(#)} {opt seg:ments(#)} {opt fill(rgb)} {opt bor:der(rgb)} {opt pad(#)}
{opt name(graphname)}]

{p 8 16 2}{cmd:gpolish note} {it:"line 1"} [{it:"line 2"} ...]{cmd:,} {c -(}{opt at(x y)} | {opt to(x y)}{c )-}
[{opt fill(rgb)} {opt bor:der(rgb)} {opt pad(#)} {it:callout_options}]

{p 8 16 2}{cmd:gpolish brace} [{it:"label line 1"} ...]{cmd:,} {opt fr:om(x y)} {opt to(x y)}
[{opt w:idth(#)} {opt flip} {opt gap(#)} {opt siz:e(#)} {opt col:or(rgb)} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish arrow,} {opt fr:om(x y)} {opt to(x y)}
[{opt cur:ve(#)} {opt head:size(#)} {opt shr:ink(#)} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish ptlabel} {it:strvar} {ifin}{cmd:,} {opt x(varname)} {opt y(varname)}
[{opt siz:e(#)} {opt col:or(rgb)} {opt off:set(#)} {opt ms:ize(#)} {opt halo} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish bracket,} {opt x(#)} {opt y0(#)} {opt y1(#)} [{opt tick(#)} {opt left} {opt lc:olor(rgb)} {opt lw:idth(str)} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish legend} [{cmd:,} {opt plots(numlist)} {opt nobold} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish clear} [{cmd:,} {opt name(graphname)}]

{p 8 16 2}{cmd:gpolish render} [{cmd:,} {opt name(graphname)} {it:gr2mpl_options}]

{p 8 16 2}{cmd:gpolish limits}

{pstd}All sizes are in points. Positions are in the units of the graph's axes.
Each value in {opt at()}, {opt to()} and {opt from()} may be a number or an expression written without spaces,
such as {cmd:to(td(21sep2001) 966)} on a date axis.
{opt name()} picks a graph in memory other than the current one.


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
Label text is the variable label; {opt labels()} overrides it, one label per plot in the order of {opt plots()}.
{opt values} adds the last value in a column, formatted with {opt format()}.
{opt dots} adds a marker at each line end. {opt color()} sets one text color for all labels instead of each line's color.
{opt side(left)} labels the left ends of the lines instead of the right; on a reversed axis
({cmd:xscale(reverse)}) the labels follow the screen, not the data.
{opt wrap(#)} wraps long labels on word boundaries at about # characters, measured by rendered width.
{opt gap(#)} is the minimum spacing between labels in line heights (default 1.3).
Running {cmd:gpolish endlabel} again replaces the earlier labels instead of adding a second set.

{phang}
{cmd:gpolish callout} adds a note of one or more lines, with a curved arrow to {opt to()}.
If {opt at()} is omitted, the note is placed automatically near the target, clear of markers, lines and other text.
{opt from()} moves the tail of the arrow; by default it starts at the edge of the text nearest the target.
{opt curve(#)} sets the bend (0 is straight; the sign sets the side).
{opt halo} draws a white box behind the text.

{phang}
{cmd:gpolish note} adds a shaded box of text, for a finding or a call-out. It takes the same options as
{cmd:gpolish callout}, plus {opt fill()} and {opt border()} for the box colors and {opt pad(#)} for the padding in points.
With {opt to()} it draws an arrow from the box; with {opt at()} alone it is a plain box.
With {opt align(center)} the box is centered on {opt at()}, which suits flow charts.

{phang}
{cmd:gpolish brace} draws a curly brace between two points, with an optional label at its tip.
Use it to mark a confidence interval, a gap between two values, or a range on an axis.
The tip points to the left of the direction from {opt from()} to {opt to()}; {opt flip} turns it to the other side.
{opt width(#)} is the depth of the brace in points.

{phang}
{cmd:gpolish arrow} draws an arrow between two points, straight by default; {opt curve(#)} bends it.
Together with {cmd:gpolish note} it builds simple flow charts on an empty plot.

{phang}
{cmd:gpolish ptlabel} labels selected points of a scatterplot with the string variable {it:strvar}.
Each label is tried in eight positions around its point and placed where it overlaps markers, lines and other
labels least. {opt x()} and {opt y()} name the plotted variables. Log axes are detected.

{phang}
{cmd:gpolish bracket} draws a square bracket from {opt y0()} to {opt y1()} at {opt x()}.

{phang}
{cmd:gpolish legend} colors each legend label to match its key and makes it bold.
If the legend uses {cmd:order()}, give the plot numbers in the same order in {opt plots()}.

{phang}
{cmd:gpolish clear} removes every added text box, line and marker from the graph and undoes the margin and legend
changes of {cmd:gpolish endlabel}. It keeps the title and axis edits of plain {cmd:gpolish}. It also removes anything
added by hand in the Graph Editor.

{phang}
{cmd:gpolish render} passes the graph to {helpb gr2mpl} for a matplotlib PNG. {cmd:gpolish limits} lists what needs it.


{marker limits}{...}
{title:Limits}

{pstd}Stata's renderer cannot draw the following. {cmd:gpolish} prints a note when a request meets one of them.

{p2colset 8 46 48 2}{...}
{p2col:Limit}What happens{p_end}
{p2line}
{p2col:Text at an angle other than 0, 90 or 270}the angle is stored; {cmd:gpolish render} applies it{p_end}
{p2col:Soft halo behind text}{opt halo} draws a white box, which can cover nearby markers{p_end}
{p2col:Different colors inside one line of text}not possible; color whole labels{p_end}
{p2col:Filled arrow heads}arrow heads are open{p_end}
{p2col:Labels that cannot all fit}a note reports how many overlap{p_end}
{p2col:{cmd:graph bar}, {cmd:by()} and combined graphs}layout commands are refused with a message; plain {cmd:gpolish} still makes the title bold; {helpb gr2mpl} redraws them{p_end}
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
Palatino, Courier New, Menlo and a few variants) and picks the table from {cmd:graph set window fontface}.
For any other font it uses Arial's widths and says so; spacing is then approximate.

{pstd}
Set {opt xsize()} and {opt ysize()} to the size the graph will be printed at, and give text sizes in points.
Run {cmd:gpolish} after the graph has its final size, because positions are solved for that size: resizing
afterwards with {cmd:graph display, xsize() ysize()} moves the plot but not the labels. To resize, redraw the
graph, or run {cmd:gpolish clear} and the layout commands again.

{pstd}
Text keeps {cmd:$} and backtick characters literally; they are stored as {cmd:{c -(}c 36{c )-}} and {cmd:{c -(}c 96{c )-}}.

{pstd}
The record that lets {cmd:gpolish endlabel} replace its own earlier labels, and lets {cmd:gpolish clear} restore
the margin, lasts for the Stata session. After {cmd:graph use} or {cmd:clear all}, {cmd:gpolish clear} still removes
the added objects but cannot restore the margin.


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
