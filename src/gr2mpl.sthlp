{smcl}
{* *! version 0.6.0  18nov2026}{...}
{viewerjumpto "Syntax" "gr2mpl##syntax"}{...}
{viewerjumpto "Description" "gr2mpl##description"}{...}
{viewerjumpto "Options" "gr2mpl##options"}{...}
{viewerjumpto "Python setup" "gr2mpl##python"}{...}
{viewerjumpto "What is supported" "gr2mpl##support"}{...}
{viewerjumpto "Limits" "gr2mpl##limits"}{...}
{viewerjumpto "Examples" "gr2mpl##examples"}{...}
{title:Title}

{phang}
{bf:gr2mpl} {hline 2} Redraw a Stata graph held in memory with matplotlib and save it as a PNG, PDF, SVG or JPG image


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}{cmd:gr2mpl} [{cmd:,} {opt name(graphname)} {opt sav:ing(filename)} {opt replace} {opt w:idth(#)} {opt dpi(#)}
{opt endl:abels} {opt noleg:end} {opt pal:ette(house)} {opt font(fontname)} {opt nogrid} {opt nohalo} {opt notick:s} {opt round:box}
{opt lws:cale(#)} {opt mss:cale(#)} {opt py:thon(path)} {opt keep:spec} {opt specdir(dir)}]

{p 8 16 2}{cmd:gr2mpl doctor} [{cmd:,} {opt py:thon(path)} {opt font(fontname)}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:gr2mpl} reads a graph that Stata has already drawn and redraws it with matplotlib in a clean house style:
bold left-aligned title, gray subtitle, light horizontal grid, no box, and direct labels where they fit.
It reads the finished graph object, not your command, so it works on graphs made by {helpb twoway},
{helpb graph bar}, {helpb graph box}, {helpb graph dot}, {cmd:by()}, {helpb graph combine}, {helpb marginsplot}
and community commands that build on them.

{pstd}
The data come from the graph itself. The dataset in memory can have changed since the graph was drawn.

{pstd}
The result is an image file (PNG, PDF, SVG or JPG, set by the {opt saving()} extension). It is not a Stata graph: it cannot be edited in the Graph Editor or combined.
For edits that stay inside Stata, see {helpb gpolish}. {cmd:gr2mpl} carries every {cmd:gpolish} edit
(end labels, callouts, point labels, colored legend text) into the matplotlib version.
It applies the angles that Stata stores for text boxes, marker labels and x-axis tick labels,
including angles that Stata itself cannot draw. {cmd:gpolish render} calls {cmd:gr2mpl}.

{pstd}
Text sizes follow the graph. {cmd:gr2mpl} reads the size Stata used for each title, axis title,
tick label, legend, marker label and text box, and converts it to points the way Stata does: relative to the
shorter side of the graph, so a small {cmd:xsize()} and {cmd:ysize()} or a scheme with its own sizes
gives the same proportions as Stata's own export. Panels of {cmd:by()}, {cmd:graph combine} and
{cmd:graph matrix} graphs are shrunk by the same factor Stata uses ({cmd:iscale()}), and that factor
also applies to text added with {cmd:text()} or {cmd:gpolish}, including {cmd:text()} boxes inside
the members of {cmd:graph combine}. As in Stata, each member of
{cmd:graph combine} gets a cell of equal size, and its plot takes what is left of the cell after its own
tick labels, end labels and titles; the axes of {cmd:by()} panels are lined up.


{marker options}{...}
{title:Options}

{phang}{opt name(graphname)} names the graph to redraw. The default is the current graph.

{phang}{opt saving(filename)} names the file to write. The extension sets the format: {cmd:.png} (the default when there is none), {cmd:.pdf}, {cmd:.svg} or {cmd:.jpg}. The default file is {it:graphname}{cmd:_mpl.png} in the current directory. A folder ending in a slash, such as {cmd:saving(out/)}, writes {it:graphname}{cmd:_mpl.png} in that folder. The folder must exist.

{phang}{opt replace} allows an existing file to be overwritten; without it {cmd:gr2mpl} stops with an error, as {helpb graph export} does. The image is rendered to a temporary file first, so a failed render leaves an existing file untouched.

{phang}{opt width(#)} sets the image width in pixels; {opt dpi(#)} sets the resolution (default 200). The figure keeps the graph's {cmd:xsize()} and {cmd:ysize()}.

{phang}{opt endlabels} replaces the legend of a line graph with labels at the line ends. {opt nolegend} drops the legend.

{phang}{opt palette(house)} recolors the series with the house palette. The default keeps the colors of the Stata graph. {cmd:house} is the only palette; any other name is an error.

{phang}{opt font(fontname)} sets the typeface (default Open Sans, falling back to Helvetica or Arial).

{phang}{opt roundbox} draws boxed text (a {cmd:text(, box)} box or a shaded note box added with {cmd:gpolish}) with rounded corners. The default is square corners, as in Stata.

{phang}{opt nogrid}, {opt nohalo} and {opt noticks} switch off the grid, the white halo behind annotation text, and the x-axis tick marks.

{phang}{opt lwscale(#)} and {opt msscale(#)} multiply all line widths and marker sizes (default 1, which matches Stata).

{phang}{opt python(path)} names the Python interpreter to use. See {help gr2mpl##python:Python setup}.

{phang}{opt keepspec} keeps the intermediate files: the JSON spec, a CSV copy of the data behind each plot, and {cmd:render_info.txt}, a plain-text record of what was drawn. {cmd:gr2mpl} reports the folder and returns it in {cmd:r(specdir)}. Without {opt keepspec}, {cmd:gr2mpl} deletes these files when it finishes, also after an error, because the CSV files hold the graph's data.

{phang}{opt specdir(dir)} says where to write the intermediate files. The default is a new folder in Stata's temporary directory. Without {opt keepspec}, {cmd:gr2mpl} deletes its own files from {it:dir} and removes {it:dir} if {cmd:gr2mpl} created it; a folder that already existed is left in place.


{marker python}{...}
{title:Python setup}

{pstd}
{cmd:gr2mpl} needs Python 3 with {bf:matplotlib} 3.6 or later and {bf:numpy}. It looks for an interpreter in this order:

{p 8 12 2}1. the {opt python()} option;{p_end}
{p 8 12 2}2. the global macro {cmd:$GR2MPL_PYTHON};{p_end}
{p 8 12 2}3. Stata's own Python (see {helpb python}), if it can import matplotlib;{p_end}
{p 8 12 2}4. {cmd:python3}, then {cmd:python}, on the system path.{p_end}

{pstd}
{cmd:gr2mpl doctor} reports which interpreter will be used, its matplotlib version and whether that version
is new enough, and whether the font is installed.
If no interpreter has matplotlib, {cmd:gr2mpl} stops and prints the {cmd:pip install} command to run.
In steps 3 and 4, an interpreter whose matplotlib is older than 3.6 is passed over, with a note, and
{cmd:gr2mpl} tries the next one. If no interpreter has matplotlib 3.6 or later, or if the interpreter named
in step 1 or 2 has an older matplotlib, {cmd:gr2mpl} stops with error 601, names the version it found,
and prints the {cmd:pip install --upgrade} command to run.
The global macro {cmd:$GR2MPL_SEARCH} can replace the list searched in steps 3 and 4, for example
{cmd:global GR2MPL_SEARCH python3 embedded} to try {cmd:python3} before Stata's own Python
({cmd:embedded} stands for Stata's own Python).
To set the interpreter once, put {cmd:global GR2MPL_PYTHON "/path/to/python"} in your profile.do.


{marker support}{...}
{title:What is supported}

{p2colset 8 44 46 2}{...}
{p2col:Graph}Status{p_end}
{p2line}
{p2col:twoway line, connected, scatter, marker labels}yes{p_end}
{p2col:mlabformat(), mlabvposition(), mlabangle()}yes{p_end}
{p2col:connect(stairstep), cmissing()}yes{p_end}
{p2col:twoway bar, rbar, histogram, area, rarea}yes{p_end}
{p2col:rcap, rspike, rline, spike, dropline, dot}yes{p_end}
{p2col:horizontal spike, dropline, area, rbar, rcap}yes{p_end}
{p2col:lfit, lfitci, qfitci, lowess, kdensity, function}yes{p_end}
{p2col:pcspike, pcarrow, pccapsym}yes{p_end}
{p2col:second y axis (also when plot 1 is on it), yaxis(1 2)}yes{p_end}
{p2col:yscale(alt)}yes{p_end}
{p2col:log and reversed scales, dates}yes{p_end}
{p2col:xline(), yline(), text(), also on the second y axis}yes{p_end}
{p2col:gpolish edits}yes{p_end}
{p2col:legend order(), subtitle, repeated labels}yes{p_end}
{p2col:order() with text-only entries or a plot listed twice}yes{p_end}
{p2col:plot-region margin wider than 4}kept (see {help gr2mpl##limits:Limits}){p_end}
{p2col:SMCL superscripts, subscripts, Greek, bold}yes (see {help gr2mpl##limits:Limits}){p_end}
{p2col:two-line tick labels, non-Latin scripts}yes{p_end}
{p2col:boxed text: text(, box), shaded note boxes}yes{p_end}
{p2col:xscale(off), yscale(off) diagrams, scatteri, pcarrowi}yes{p_end}
{p2col:graph bar, hbar, box, hbox, dot}yes{p_end}
{p2col:blabel() bar labels, second over() group labels}yes{p_end}
{p2col:graph matrix (half honoured)}yes{p_end}
{p2col:by() on twoway and graph bar (one shared scale unless yrescale); graph combine}yes{p_end}
{p2col:marginsplot (also with by()), coefplot (several models)}yes{p_end}
{p2col:avplot, rvfplot, lvr2plot, cluster dendrogram}yes{p_end}
{p2col:heatplot and other nodropbase area polygons}yes, with a stepped colour legend{p_end}
{p2col:statplot}yes{p_end}
{p2col:contour, contourline}layer skipped, with a note{p_end}
{p2col:graph pie}refused{p_end}
{p2col:a layer on a second x axis or a third y axis}layer skipped, with a note{p_end}
{p2col:xline(), yline(), text() on those axes}skipped, with a note{p_end}
{p2col:nested combine; by() graph inside combine}panel skipped, with a note{p_end}
{p2line}

{pstd}
Skipped layers, panels and annotations are named in a note and listed in {cmd:r(unsupported)}.


{marker limits}{...}
{title:Limits}

{pstd}
Some choices differ from the Stata graph on purpose: the y-axis title moves above the plot (above its
right end when the y axis of a single graph is on the right; with two y axes each title stays beside its axis), the series
legend sits above the plot, bars always start at their base, black reference lines become gray, and y-axis tick
labels are drawn horizontally unless Stata set a diagonal angle.

{pstd}
Other differences are limits of the translation:

{p 8 12 2}o {cmd:{c -(}it:{c )-}} text is drawn upright, and SMCL font changes ({cmd:{c -(}stSerif:{c )-}} and the like) use the main font.{p_end}
{p 8 12 2}o {cmd:{c -(}sup:{c )-}} and {cmd:{c -(}sub:{c )-}} use Unicode superscript and subscript characters; text that has none (most capital letters in subscripts, punctuation) is drawn on the line.{p_end}
{p 8 12 2}o Characters that no installed font can draw appear as empty boxes; {cmd:gr2mpl} tries the CJK fonts that come with macOS, Windows and Noto.{p_end}
{p 8 12 2}o With {cmd:gpolish endlabel, values}, the value column is spaced from the widths matplotlib measures, so it can sit a little further right than in Stata.{p_end}
{p 8 12 2}o Plot-region margins of 4 or less (in Stata's relative units; the default margins of Stata's schemes and of {cmd:pypolish} are 3 or less) are replaced by {cmd:gr2mpl}'s own padding of about 2.5% of the axis range at each end (none below a y axis that starts at 0). A wider margin is kept, in points, as Stata draws it: for example the room {cmd:gpolish endlabel} makes between a y axis and the lines with {cmd:side(left)}, {cmd:yscale(alt)} or {cmd:yaxis(2)}, or {cmd:plotregion(margin(large))}.{p_end}
{p 8 12 2}o The number of legend columns set by {cmd:legend(cols())} or {cmd:legend(rows())} is not followed: {cmd:gr2mpl} puts as many keys on a row as fit the figure width. The keys read row by row, in Stata's order, and column by column with {cmd:legend(colfirst)}.{p_end}
{p 8 12 2}o {cmd:xscale(alt)} is not followed: the x axis stays at the bottom. When Stata draws both y axes on one side (as it does with a third y axis), the second is drawn on the other side.{p_end}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. gr2mpl doctor}{p_end}
{phang2}{cmd:. sysuse nlsw88, clear}{p_end}
{phang2}{cmd:. regress wage c.grade##i.race}{p_end}
{phang2}{cmd:. margins race, at(grade=(8(2)18))}{p_end}
{phang2}{cmd:. marginsplot}{p_end}
{phang2}{cmd:. gr2mpl, saving(margins.png) replace endlabels}{p_end}


{title:Stored results}

{pstd}{cmd:r(filename)}, {cmd:r(python)}, {cmd:r(pymode)} ({cmd:embedded} or {cmd:shell}), {cmd:r(unsupported)}
(skipped layers, panels and annotations, separated by semicolons), and, with {opt keepspec}, {cmd:r(specdir)} (the folder that holds the intermediate files).

{pstd}{cmd:gr2mpl doctor} returns {cmd:r(python)}, {cmd:r(pymode)}, {cmd:r(mplversion)} (the matplotlib version)
and {cmd:r(mplok)} (1 when that version is 3.6 or later, 0 when it is older).


{title:Technical note}

{pstd}
Requires Stata 16 or later. {cmd:gr2mpl} reads undocumented members of Stata's graph objects, which could change in a future release.


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

{psee}{helpb gpolish}, {helpb python}{p_end}
