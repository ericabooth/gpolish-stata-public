* gr2mpl test battery: each graph is exported natively and through matplotlib.
* Run from the repository root:  stata-mp -b do tests/gr2mpl_tests.do
version 16
set more off
clear all
adopath ++ "`c(pwd)'/src"
* Python with matplotlib: set $GR2MPL_PYTHON or the environment variable of the same name
if "$GR2MPL_PYTHON"=="" global GR2MPL_PYTHON : environment GR2MPL_PYTHON
gr2mpl doctor
capture mkdir "tests/out"
capture mkdir "tests/spec"
capture program drop both
program both
    args tag opts
    graph export "tests/out/`tag'_stata.png", replace width(1600)
    capture noisily gr2mpl, saving("tests/out/`tag'_mpl.png") specdir("tests/spec/`tag'") keepspec lwscale(1.7) msscale(1.5) replace `opts'
    if _rc di as err "FAILED: `tag' rc=" _rc
    else di as res "OK: `tag'"
end

* 01 multi-series lines with direct labels ---------------------------------
sysuse uslifeexp, clear
label var le_wmale "White men"
label var le_wfemale "White women"
label var le_bmale "Black men"
label var le_bfemale "Black women"
line le_wmale le_wfemale le_bmale le_bfemale year, ///
    title("Life expectancy rose for every group, but gaps remain") ///
    ytitle("Life expectancy at birth, years") xtitle("") ///
    note("Source: National Vital Statistics Report, Vol. 50, No. 6") xsize(6.5) ysize(4)
both 01_lines endlabels

* 02 scatter with fit and confidence band -----------------------------------
sysuse auto, clear
twoway (lfitci mpg weight) (scatter mpg weight if !foreign) (scatter mpg weight if foreign, msymbol(Dh)), ///
    legend(order(3 "Domestic" 4 "Foreign" 2 "Linear fit")) ///
    title("Heavier cars get fewer miles per gallon") ytitle("Miles per gallon") xtitle("Weight (lbs.)") ///
    xsize(6) ysize(4)
both 02_scatter_fit

* 03 marginsplot after an interaction model (a command we do not control) ----
sysuse nlsw88, clear
quietly regress wage i.race##c.grade i.union
quietly margins race, at(grade=(8(2)18))
marginsplot, title("Predicted hourly wage by schooling and race") ytitle("Predicted wage, dollars") ///
    xtitle("Years of schooling") xsize(6.5) ysize(4)
both 03_marginsplot
both 03b_marginsplot_house "endlabels palette(house)"

* 04 twoway bar from collapsed data; data in memory is then destroyed --------
sysuse nlsw88, clear
collapse (mean) wage, by(occupation)
drop if missing(occupation)
gsort -wage
gen rank = _n
decode occupation, gen(occ)
forvalues i = 1/`=_N' {
    label define rk `i' "`=occ[`i']'", add
}
label values rank rk
twoway bar wage rank, barwidth(0.7) xlabel(1(1)13, valuelabel angle(45) labsize(small)) ///
    title("Mean hourly wage by occupation") ytitle("Dollars per hour") xtitle("") xsize(7) ysize(4.2)
clear
both 04_bar

* 05 area with reference line and text annotation ---------------------------
sysuse uslifeexp, clear
twoway (area le year, color(navy%40)) (line le year if year>=1950, lcolor(navy) lwidth(medthick)), ///
    xline(1918, lpattern(dash)) text(42 1930 "1918 influenza pandemic") legend(off) ///
    title("U.S. life expectancy, 1900 to 1999") ytitle("Years") xtitle("") xsize(6.5) ysize(4)
both 05_area_refline

* 06 dated series: line with a range band ------------------------------------
sysuse sp500, clear
twoway (rarea high low date, color(gs12)) (line close date, lcolor(maroon)), ///
    legend(order(2 "Close" 1 "Daily range")) title("S&P 500 in 2001") ///
    ytitle("Index level") xtitle("") xsize(6.5) ysize(4)
both 06_dates_rarea

* 07 coefficient-style plot: points with caps, horizontal ---------------------
sysuse auto, clear
quietly regress price mpg headroom trunk length turn i.foreign
matrix T = r(table)
clear
svmat double T
gen stat = _n
keep if inlist(stat, 1, 5, 6)
xpose, clear
drop in 7/8
rename (v1 v2 v3) (b lo hi)
drop if b == 0
gen k = _n
label define k 1 "MPG" 2 "Headroom" 3 "Trunk space" 4 "Length" 5 "Turn circle" 6 "Foreign"
label values k k
twoway (rcap lo hi k, horizontal lcolor(navy)) (scatter k b, mcolor(navy)), ///
    xline(0) ylabel(1(1)6, valuelabel angle(0)) yscale(reverse) legend(off) ///
    title("Price regression coefficients") xtitle("Dollars, with 95% CI") ytitle("") xsize(6) ysize(3.6)
both 07_coef_rcap

* 08 graph hbar with over() ---------------------------------------------------
sysuse nlsw88, clear
graph hbar (mean) wage, over(industry, sort(1) descending) title("Mean wage by industry") ///
    ytitle("Dollars per hour") xsize(6.5) ysize(4.5)
both 08_graph_hbar

* 09 graph bar, two variables over a group ------------------------------------
sysuse auto, clear
graph bar (mean) mpg trunk, over(rep78) title("Mileage and trunk space by repair record") ///
    legend(order(1 "MPG" 2 "Trunk (cu. ft.)")) xsize(6) ysize(4)
both 09_graph_bar

* 10 connected lines, log scale ------------------------------------------------
sysuse uslifeexp2, clear
twoway connected le year, yscale(log) ylabel(40 50 60 70) title("Connected markers on a log scale") ///
    ytitle("Life expectancy") xtitle("") xsize(6) ysize(4)
both 10_connected_log

* 11 coefplot, only if already installed ---------------------------------------
capture which coefplot
if !_rc {
    sysuse auto, clear
    quietly regress price mpg headroom trunk length turn
    coefplot, drop(_cons) xline(0) title("coefplot output")
    both 11_coefplot
}
else di as txt "coefplot not installed; test 11 skipped"

* 12 by(): small multiples with a shared legend ---------------------------------
sysuse auto, clear
twoway (scatter mpg weight) (lfit mpg weight), by(foreign, title("Mileage falls with weight in both groups") ///
    note("Source: 1978 automobile data")) ytitle("Miles per gallon") xtitle("Weight (lbs.)") ///
    legend(order(1 "Cars" 2 "Linear fit")) xsize(7) ysize(4)
both 12_by_two

* 13 by(): six panels, lines --------------------------------------------------------
sysuse nlsw88, clear
collapse (mean) wage, by(industry age)
keep if inlist(industry, 4, 5, 6, 7, 11, 12)
twoway line wage age, by(industry, title("Mean wage by age, six industries") note("")) ///
    ytitle("Dollars per hour") xtitle("Age") xsize(7.5) ysize(5)
both 13_by_six

* 14 histogram -----------------------------------------------------------------------
sysuse nlsw88, clear
histogram wage, width(2) frequency title("Distribution of hourly wages") xtitle("Dollars per hour") ///
    xsize(6) ysize(4)
both 14_histogram

* 15 kdensity plus a function layer ----------------------------------------------------
sysuse auto, clear
quietly summarize mpg
local m = r(mean)
local sd = r(sd)
twoway (kdensity mpg) (function y = normalden(x, `m', `sd'), range(10 42) lpattern(dash)), ///
    legend(order(1 "Kernel density" 2 "Normal")) title("Mileage is right-skewed") ///
    ytitle("Density") xtitle("Miles per gallon") xsize(6) ysize(4)
both 15_kdensity_function

* 16 graph box and 17 graph hbox --------------------------------------------------------
sysuse nlsw88, clear
graph box wage, over(race) title("Hourly wage by race") ytitle("Dollars per hour") xsize(6) ysize(4)
both 16_graph_box
graph hbox wage ttl_exp, over(collgrad) title("Wage and experience by degree") ///
    legend(order(1 "Hourly wage" 2 "Total experience")) xsize(6.5) ysize(4)
both 17_graph_hbox

* 18 graph dot -----------------------------------------------------------------------------
sysuse nlsw88, clear
graph dot (mean) wage (median) wage, over(occupation, sort(1) descending) ///
    legend(order(1 "Mean" 2 "Median")) title("Mean and median wage by occupation") ///
    ytitle("Dollars per hour") xsize(6.5) ysize(4.8)
both 18_graph_dot

* 19 paired-coordinate plots -----------------------------------------------------------------
sysuse nlsw88, clear
collapse (mean) wage hours, by(race collgrad)
reshape wide wage hours, i(race) j(collgrad)
twoway (pcarrow wage0 hours0 wage1 hours1, lcolor(navy) mcolor(navy)) ///
       (scatter wage0 hours0, mcolor(navy) mlabel(race) mlabpos(6)), ///
    legend(off) title("A degree moves every group up and to the right") ///
    ytitle("Mean hourly wage") xtitle("Mean weekly hours") xsize(6) ysize(4)
both 19a_pcarrow
twoway (pcspike wage0 hours0 wage1 hours1) (pccapsym wage1 hours0 wage0 hours1, lpattern(dash)), ///
    legend(order(1 "pcspike" 2 "pccapsym")) title("pcspike and pccapsym") xsize(6) ysize(4)
both 19b_pcspike_capsym

* 20 second y axis ------------------------------------------------------------------------------
sysuse sp500, clear
twoway (line close date) (bar volume date, yaxis(2) color(gs12)), ///
    legend(order(1 "Close" 2 "Volume")) title("S&P 500 close and trading volume") ///
    ytitle("Index level") ytitle("Shares traded", axis(2)) xtitle("") xsize(6.5) ysize(4)
both 20_second_axis

* 21 graph combine --------------------------------------------------------------------------------
sysuse auto, clear
twoway scatter mpg weight, title("Mileage and weight") name(c1, replace) nodraw
graph bar (mean) mpg, over(rep78) title("Mileage by repair record") name(c2, replace) nodraw
histogram price, title("Price") name(c3, replace) nodraw
twoway (line mpg weight if foreign, sort) (line mpg weight if !foreign, sort), ///
    legend(order(1 "Foreign" 2 "Domestic")) title("Two lines") name(c4, replace) nodraw
graph combine c1 c2 c3 c4, title("Four graphs combined") xsize(8) ysize(6)
both 21_combine

* 22 rotated text; halo switched off ------------------------------------------------------------------
sysuse uslifeexp, clear
twoway line le year, text(45 1918 "1918 pandemic", orientation(vertical) placement(w)) ///
    text(70 1960 "angle(30)", angle(30)) title("Rotated text boxes") ytitle("Years") xtitle("") ///
    xsize(6) ysize(4)
both 22_rotated_text nohalo

* 23 graph bar with by() -----------------------------------------------------------------------------------
sysuse auto, clear
graph bar (mean) mpg, over(rep78) by(foreign, title("Mileage by repair record") note("")) ///
    ytitle("Miles per gallon") xsize(7) ysize(4)
both 23_bar_by

* 24 a layer that cannot be drawn is reported, not silently dropped ----------------------------------------------
sysuse sandstone, clear
twoway (contourline depth northing easting, levels(4)) (scatter northing easting in 1/20), ///
    title("Contour layer is skipped with a note") xsize(6) ysize(4)
both 24_skipped_layer
return list

* 25 a family that is not supported fails cleanly ----------------------------------------------------------------
sysuse auto, clear
graph pie, over(rep78)
capture noisily gr2mpl, saving("tests/out/25_pie_mpl.png")
di "pie rc = " _rc

* 26 boxed text: text(, box), a shaded note box added with gr_edit, and a halo box ----------------
sysuse auto, clear
twoway scatter mpg weight, title("Boxed annotations") ytitle("Miles per gallon") xtitle("Weight (lbs.)") ///
    text(38 4100 "Outlined box" "from text(, box)", box fcolor("255 244 214") lcolor("200 140 0") ///
        lwidth(thin) margin(small) size(9pt)) xsize(6) ysize(4)
gr_edit .plotregion1.AddTextBox added_text editor 15 2100
gr_edit .plotregion1.added_text_new = 1
gr_edit .plotregion1.added_text_rec = 1
gr_edit .plotregion1.added_text[1].style.editstyle size(9pt) drawbox(yes) fillcolor("226 238 246%90") linestyle(color("11 93 122") width(thin)) boxmargin(2 2 1.2 1.2) box_alignment(east) horizontal(left) editcopy
gr_edit .plotregion1.added_text[1].text = {}
gr_edit .plotregion1.added_text[1].text.Arrpush "{bf:Finding.} Light cars"
gr_edit .plotregion1.added_text[1].text.Arrpush "cluster above 25 mpg"
gr_edit .plotregion1.AddTextBox added_text editor 22 4300
gr_edit .plotregion1.added_text_new = 2
gr_edit .plotregion1.added_text_rec = 2
gr_edit .plotregion1.added_text[2].style.editstyle size(9pt) drawbox(yes) fillcolor("255 255 255%80") linestyle(color(none) width(none)) editcopy
gr_edit .plotregion1.added_text[2].text = {}
gr_edit .plotregion1.added_text[2].text.Arrpush "halo, not a box"
both 26_boxed_text
both 26b_boxed_text_round roundbox

* 27 graph matrix, half and full ---------------------------------------------------------------------
sysuse auto, clear
graph matrix mpg weight price length, half title("Scatterplot matrix, lower half") xsize(6) ysize(6)
both 27_matrix_half
graph matrix mpg weight price, title("Scatterplot matrix") xsize(6) ysize(6)
both 27b_matrix_full

* 28 heatplot (community command), only if installed ---------------------------------------------------
capture which heatplot
if !_rc {
    sysuse auto, clear
    heatplot price weight mpg, title("Mean price by weight and mileage") xsize(6.5) ysize(4.5)
    both 28_heatplot
}
else di as txt "heatplot not installed; test 28 skipped"

* 29 a heat map built from rbar layers, labelled ticks on both axes, values in the cells -----------------
sysuse nlsw88, clear
collapse (mean) wage, by(race occupation)
keep if occupation <= 6
gen lo = race - 0.5
gen hi = race + 0.5
gen str5 lab = string(wage, "%4.1f")
twoway (rbar lo hi occupation if wage < 7, barwidth(1) color("222 235 247")) ///
       (rbar lo hi occupation if inrange(wage, 7, 9.999), barwidth(1) color("158 202 225")) ///
       (rbar lo hi occupation if wage >= 10, barwidth(1) color("49 130 189")) ///
       (scatter race occupation, msymbol(none) mlabel(lab) mlabpos(0) mlabcolor(black)), ///
    ylabel(1 2 3, valuelabel angle(0) nogrid) xlabel(1(1)6, valuelabel angle(30) nogrid) ///
    legend(order(1 "Under $7" 2 "$7 to $10" 3 "$10 or more")) ///
    title("Mean hourly wage by race and occupation") ytitle("") xtitle("") xsize(7) ysize(4)
both 29_rbar_heatmap

* 30 cluster dendrogram ----------------------------------------------------------------------------------
sysuse auto, clear
keep in 1/20
cluster wardslinkage mpg weight price, name(wl)
cluster dendrogram wl, labels(make) xlabel(, angle(45) labsize(vsmall)) ///
    title("Ward's linkage, 20 cars") ytitle("Dissimilarity") xsize(7) ysize(4.5)
both 30_dendrogram

* 31 statplot (community command), only if installed --------------------------------------------------------
capture which statplot
if !_rc {
    sysuse auto, clear
    statplot mpg trunk turn, over(foreign) blabel(bar, format(%4.1f)) title("Means by origin") xsize(6.5) ysize(4)
    both 31_statplot
}
else di as txt "statplot not installed; test 31 skipped"

* 32 graph hbar with two over() levels and bar labels --------------------------------------------------------
sysuse nlsw88, clear
graph hbar (mean) wage, over(collgrad) over(race) blabel(bar, format(%4.2f)) ///
    title("Mean wage by race and degree") ytitle("Dollars per hour") xsize(6.5) ysize(4.2)
both 32_hbar_two_over
graph bar (mean) wage hours, over(union) over(married) blabel(bar, format(%4.1f)) ///
    legend(order(1 "Hourly wage" 2 "Weekly hours")) title("Wage and hours") xsize(6.5) ysize(4.2)
both 32b_bar_two_over

* 33-35 regression diagnostics ----------------------------------------------------------------------------------
sysuse auto, clear
quietly regress price mpg weight foreign
avplot mpg, title("Added-variable plot") xsize(6) ysize(4)
both 33_avplot
rvfplot, yline(0) title("Residuals against fitted values") xsize(6) ysize(4)
both 34_rvfplot
lvr2plot, mlabel(make) title("Leverage against squared residuals") xsize(6) ysize(4)
both 35_lvr2plot

* 36 marginsplot with by() ------------------------------------------------------------------------------------------
sysuse nlsw88, clear
quietly regress wage i.race##i.collgrad i.union c.grade
quietly margins race, over(collgrad union)
marginsplot, by(union) title("Predicted wage by race, degree and union status") xsize(7.5) ysize(4.2)
both 36_marginsplot_by

* 37 coefplot with several models, only if installed -------------------------------------------------------------------
capture which coefplot
if !_rc {
    sysuse auto, clear
    quietly regress price mpg headroom trunk turn if foreign
    estimates store Foreign
    quietly regress price mpg headroom trunk turn if !foreign
    estimates store Domestic
    coefplot Foreign Domestic, drop(_cons) xline(0) title("Price models by origin") xsize(6.5) ysize(4)
    both 37_coefplot_models
}
else di as txt "coefplot not installed; test 37 skipped"

* 38 flow-chart style diagram with both axes switched off ------------------------------------------------------------------
clear
twoway (pcarrowi 3 1.6 3 2.4  3 3.6 3 4.4  2.75 5 1.4 5, lcolor(gs6) mcolor(gs6)) ///
       (scatteri 3 1 "Raw data" 3 3 "Clean" 3 5 "Model" 1.1 5 "Report", msymbol(none) mlabpos(0) mlabsize(medium)), ///
    xscale(off range(0.3 5.7)) yscale(off range(0.6 3.5)) legend(off) ///
    title("A four-step pipeline") xsize(6.5) ysize(3)
both 38_flowchart_axes_off

* -- file handling and messages ---------------------------------------------------
sysuse auto, clear
scatter mpg weight, name(fh, replace)
capture erase "tests/out/fh_mpl.png"
gr2mpl, name(fh) saving("tests/out/fh_mpl.png")
capture gr2mpl, name(fh) saving("tests/out/fh_mpl.png")
assert _rc==602
gr2mpl, name(fh) saving("tests/out/fh_noext") replace
confirm file "tests/out/fh_noext.png"
capture gr2mpl, name(fh) saving("tests/out/nodir/x.png") replace
assert _rc==603
capture gr2mpl, name(fh) saving("tests/out/x.png") replace python("/no/such/python")
assert _rc==601
global foo X
gpolish callout "Cost \$foo", at(3000 30)
gr2mpl, name(fh) saving("tests/out/fh_dollar.png") replace keepspec specdir("tests/spec/fh")
gr2mpl, name(fh) saving("tests/out/fh_font.png") replace font("NoSuchFont")
di "FILE HANDLING OK"


* =================================================================================
* Regression checks. Each graph is drawn by gr2mpl with keepspec; the renderer's
* record of what it drew (render_info.txt in the spec folder) is checked line by line.
* =================================================================================
capture program drop rchk
program rchk
    * draw the current graph with gr2mpl, keep its spec, and export Stata's version
    args tag opts
    graph export "tests/out/r_`tag'_stata.png", replace width(1200)
    gr2mpl, saving("tests/out/r_`tag'_mpl.png") specdir("tests/spec/r_`tag'") keepspec replace `opts'
    global R_UNSUP `"`r(unsupported)'"'
    global R_DIR "tests/spec/r_`tag'"
end
capture program drop has
program has
    * has "line"      the render record holds this exact line
    * has "line", absent  it does not
    syntax anything(name=want id="line") [, ABSent]
    local want `want'
    tempname fh
    local found 0
    file open `fh' using "$R_DIR/render_info.txt", read text
    file read `fh' line
    while r(eof) == 0 {
        if `"`macval(line)'"' == `"`macval(want)'"' local found 1
        file read `fh' line
    }
    file close `fh'
    if "`absent'" == "" & !`found' {
        di as err `"render record lacks: `macval(want)'"'
        type "$R_DIR/render_info.txt"
        exit 9
    }
    if "`absent'" != "" & `found' {
        di as err `"render record should not hold: `macval(want)'"'
        exit 9
    }
    global R_N = $R_N + 1
end
capture program drop getv
program getv, rclass
    * r(val): the text after "key=" on the first line that starts with it
    args key
    tempname fh
    local val
    local got 0
    file open `fh' using "$R_DIR/render_info.txt", read text
    file read `fh' line
    while r(eof) == 0 {
        if !`got' & strpos(`"`macval(line)'"', "`key'=") == 1 {
            local val = usubstr(`"`macval(line)'"', ustrlen("`key'=") + 1, .)
            local got 1
        }
        file read `fh' line
    }
    file close `fh'
    if !`got' {
        di as err "render record has no `key'"
        exit 9
    }
    return local val `"`macval(val)'"'
end
capture program drop near
program near
    * near key value [tol]: the record's number for key is within tol of value
    args key target tol
    if "`tol'" == "" local tol 0.06
    getv `key'
    local v = real(`"`r(val)'"')
    if missing(`v') | abs(`v' - `target') > `tol' {
        di as err "`key' = `v', expected `target'"
        exit 9
    }
    global R_N = $R_N + 1
end
capture program drop ok
program ok
    * ok expression: an assert that counts
    assert `0'
    global R_N = $R_N + 1
end
global R_N 0

* -- a plot on yaxis(2) that is not plot 2 is drawn on the second axis
sysuse auto, clear
twoway (scatter mpg weight) (lfit mpg weight) (line price weight, sort yaxis(2)), title("y2 is plot 3")
rchk y2_plot3
has "panel1.plot1.axis=y1"
has "panel1.plot2.axis=y1"
has "panel1.plot3.axis=y2"
ok `"$R_UNSUP"' == ""

* -- horizontal spike, dropline and area plots are drawn
twoway spike mpg weight, horizontal title("spike, horizontal")
rchk spike_h
has "panel1.segments=h74"
twoway dropline mpg weight in 1/15, horizontal title("dropline, horizontal")
rchk dropline_h
has "panel1.segments=h15"
sysuse uslifeexp, clear
twoway area le year, horizontal title("area, horizontal")
rchk area_h
getv panel1.line_x
ok real(word(subinstr(`"`r(val)'"', ",", " ", .), 1)) > 35 & real(word(subinstr(`"`r(val)'"', ",", " ", .), 2)) < 80

* -- a long legend wraps instead of crushing the plot
line le_wmale le_wfemale le_bmale le_bfemale le_male le_female year, title("six series")
rchk long_legend
has "panel1.legend_inside=1"
getv panel1.axes
ok real(word(subinstr(`"`r(val)'"', ",", " ", .), 3)) > 0.6

* -- custom tick labels that look like dates are kept
clear
set obs 7
gen t = _n - 4
gen y = t^2
twoway line y t, xlabel(-3 "01jan2020" -2 "01feb2020" -1 "01mar2020" 0 "01apr2020" 1 "01may2020" 2 "01jun2020" 3 "01jul2020") ///
    title("date-like labels on an event-time axis")
rchk datelike
has "panel1.xticks=01jan2020|01feb2020|01mar2020|01apr2020|01may2020|01jun2020|01jul2020"
* real %td axes still get the short labels
sysuse sp500, clear
line close date, title("a daily date axis")
rchk td_axis
has "panel1.xticks=Jan 2001|Apr|Jul|Oct|Jan 2002"

* -- gpolish endlabel, values: values clear of the labels
sysuse uslifeexp, clear
line le_wfemale le_wmale le_bfemale le_bmale year, scheme(pypolish) legend(off) title("end labels with values")
gpolish
gpolish endlabel, values dots
rchk endlabel_values
has "panel1.ann_overlaps=0"

* -- text sizes follow Stata's: scheme sizes and small graphs
sysuse auto, clear
foreach o in "xsize(5.5) ysize(4)" "scheme(economist)" "xsize(3) ysize(2)" "xsize(9) ysize(6)" "title(, size(10pt))" {
    twoway (scatter mpg weight if foreign) (scatter mpg weight if !foreign), title("Text sizes") `o'
    local u = min(`.Graph.style.declared_xsize.val', `.Graph.style.declared_ysize.val') * 0.72
    local tfs = `.Graph.title.style.size.gmval' * `u'
    local xfs = `.Graph.xaxis1.style.majorstyle.tickstyle.textstyle.size.gmval' * `u'
    rchk sizes
    near title_fs `tfs'
    near panel1.xtickfs `xfs'
    has "panel1.legend_inside=1"
}
* by() and graph combine shrink panel text by the multiplier Stata stores
scatter mpg weight, by(foreign)
local u = min(`.Graph.style.declared_xsize.val', `.Graph.style.declared_ysize.val') * 0.72
local xfs = `.Graph.graphs[2].xaxis1.style.majorstyle.tickstyle.textstyle.size.gmval' * `u' * `.Graph.plotregion1.gmetric_mult'
rchk by_sizes
near panel2.xtickfs `xfs'
scatter mpg weight, name(ca, replace) nodraw
scatter mpg price, name(cb, replace) nodraw
graph combine ca cb
local u = min(`.Graph.style.declared_xsize.val', `.Graph.style.declared_ysize.val') * 0.72
local xfs = `.Graph.graphs[1].xaxis1.style.majorstyle.tickstyle.textstyle.size.gmval' * `u' * `.Graph.plotregion1.gmetric_mult'
rchk combine_sizes
near panel1.xtickfs `xfs'

* -- legend: one key per entry even when labels repeat; Stata's order; subtitle
twoway (scatter mpg weight if foreign) (scatter mpg weight if !foreign) (lfit mpg weight), title("repeated labels")
rchk dup_labels
has "panel1.legend=Mileage (mpg)|Mileage (mpg)|Fitted values"
twoway (scatter mpg weight if !foreign) (scatter mpg weight if foreign) (lfit mpg weight), ///
    legend(order(3 "Fit" 1 "Domestic" 2 "Foreign") subtitle("Measure")) title("legend order")
rchk legend_order
has "panel1.legend=Fit|Domestic|Foreign"
has "panel1.legend_title=Measure"

* -- connect(stairstep) and cmissing()
sysuse uslifeexp, clear
twoway line le year if year < 1930, connect(stairstep) title("stairstep")
rchk stairstep
has "panel1.drawstyle=steps-post"
replace le = . if inrange(year, 1915, 1925)
twoway connected le year if year < 1950, title("default cmissing(y) bridges the gap")
rchk cmissing_y
has "panel1.line_nan=0"
twoway connected le year if year < 1950, cmissing(n) title("cmissing(n) breaks the line")
rchk cmissing_n
has "panel1.line_nan=0", absent

* -- SMCL: superscripts, subscripts, Greek letters, hex characters, two-line ticks
sysuse auto, clear
twoway scatter mpg weight, title("R{sup:2} = 0.65 and {&beta}{sub:1} < 0 caf{c 0xe9}") ///
    ytitle("{&mu} mpg") xtitle("Weight {&le} 5000, {&Delta}") xlabel(2000 `""Line A" "Line B""' 4000 "four")
rchk smcl
has "title=R² = 0.65 and β₁ < 0 café"
has "figtext=μ mpg|`: di %4.2f `.Graph.yaxis1.title.style.size.gmval' * min(`.Graph.style.declared_xsize.val', `.Graph.style.declared_ysize.val') * 0.72'"
has "figtext=Weight ≤ 5000, Δ|`: di %4.2f `.Graph.xaxis1.title.style.size.gmval' * min(`.Graph.style.declared_xsize.val', `.Graph.style.declared_ysize.val') * 0.72'"
has "panel1.xticks=Line A/Line B|four"

* -- SMCL toggle tags {bf} {it} {sf} {rm} are applied or dropped, never printed
sysuse auto, clear
twoway scatter mpg weight, title("A {bf}bold{sf} and {it}italic{sf} word; {it:colon} form") ///
    note("{it}note{rm} text") text(30 3000 "{bf}hi{sf}")
rchk smcl_toggle
has "title=A bold and italic word; colon form"
has "panel1.ann=hi|left|0|y1|in"

* -- graph combine keeps each member's subtitle(), note() and caption()
sysuse auto, clear
twoway (scatter mpg weight) (lfitci mpg weight), name(cm_a, replace) title("TTT") ///
    subtitle("SUBXYZ") note("NOTEXYZ") caption("CAPXYZ")
kdensity mpg, name(cm_b, replace)
graph combine cm_a cm_b, name(cm_c, replace)
rchk combine_notes
has "panel1.ptitle=TTT"
has "panel1.psubtitle=SUBXYZ"
has "panel1.psubtitle_below_title=1"
has "panel1.pnote=NOTEXYZ/CAPXYZ"
has "panel1.pnote_below_xaxis=1"
has "panel1.pnote_inside=1"
has "panel2.pnote=kernel = epanechnikov, bandwidth = 1.9746"
has "panel1.ann=SUBXYZ|left|0|y1|in", absent
graph drop cm_a cm_b cm_c

* -- marker labels: mlabformat(), mlabvposition(), pc-plot labels, mlabangle()
sysuse uslifeexp, clear
twoway connected le year if mod(year, 10) == 0, msymbol(none) mlabel(le) mlabformat(%4.1f) title("mlabformat")
rchk mlabformat
has "panel1.ann=50.0|left|0|y1|in"
has "panel1.ann=47.3|left|0|y1|in"
clear
twoway scatteri 1 1 (3) "Alpha" 2 2 (9) "Beta" 3 1.5 (12) "Gamma", xscale(range(0 3)) yscale(range(0 4)) title("positions")
rchk scatteri_pos
has "panel1.ann=Alpha|left|0|y1|in"
has "panel1.ann=Beta|right|0|y1|in"
has "panel1.ann=Gamma|center|0|y1|in"
twoway pcarrowi 1 1 2 2 (3) "arrow label", title("pcarrowi label")
rchk pc_label
has "panel1.ann=arrow label|left|0|y1|in"
sysuse auto, clear
twoway scatter mpg weight in 1/12, mlabel(make) mlabangle(45) xlabel(, angle(vertical)) title("angles")
rchk angles
has "panel1.ann=Buick Opel|left|45|y1|in"
has "panel1.xtickangle=90"

* -- reference lines and text on the second y axis
twoway (scatter mpg weight) (line price weight, sort yaxis(2)), yline(5000, axis(2) lcolor(red)) ///
    text(12000 3000 "on axis 2", yaxis(2)) title("y2 line and text")
rchk y2_refs
has "panel1.refline=y2:y:5000"
has "panel1.ann=on axis 2|left|0|y2|in"
ok `"$R_UNSUP"' == ""

* -- layers on a second x axis or a third y axis are skipped and reported
twoway (scatter mpg weight) (scatter mpg length, xaxis(2)), title("x2 plot")
rchk x2_plot
ok strpos(`"$R_UNSUP"', "plot 2 (type scatter): second x axis")
has "panel1.plot2.axis=y1", absent
twoway (scatter mpg weight) (scatter price weight, yaxis(2)) (scatter length weight, yaxis(3)), title("y3 plot")
rchk y3_plot
ok strpos(`"$R_UNSUP"', "plot 3 (type scatter): y axis 3")
has "panel1.plot2.axis=y2"
has "panel1.legend=Mileage (mpg)|Price"
* Stata stacks the axes on the left; gr2mpl puts the second on the right
has "panel1.yside=left"
has "panel1.y2side=right"

* -- graph box: a group without whiskers still gets its box
graph box mpg, over(rep78) title("box without whiskers")
rchk box_nowhisk
has "panel1.patches=5"

* -- CJK characters are drawn with a fallback font
twoway scatter mpg weight, title("Año São Paulo 日本")
rchk cjk
getv font_family
if strpos(`"`r(val)'"', "Hiragino") | strpos(`"`r(val)'"', "Noto Sans CJK") | strpos(`"`r(val)'"', "YaHei") {
    has "glyphs_missing="
}
else di as txt "no CJK font installed; glyph check skipped"

* -- a by() graph inside graph combine is named in the note
scatter mpg weight, by(foreign) name(gb, replace)
scatter mpg price, name(gs, replace)
graph combine gb gs, title("by() inside combine")
rchk by_in_combine
ok strpos(`"$R_UNSUP"', "a by() graph inside graph combine")
* after a by() graph has been put in graph combine, Stata reports .graphfamily
* "combine" for later by() graphs; gr2mpl reads the family from .classname
scatter mpg weight, by(foreign)
rchk by_after_combine
has "family=by"
has "panel1.ptitle=Domestic"
has "panel2.ptitle=Foreign"

* -- end labels sit outside the plot on a reversed x axis
sysuse uslifeexp, clear
label var le_wfemale "White women"
label var le_bmale "Black men"
line le_wfemale le_bmale year, xscale(reverse) title("reversed x axis")
rchk reversed_endlabels endlabels
has "panel1.endlabel=White women|clear"
has "panel1.endlabel=Black men|clear"

* -- plot 1 on yaxis(2): plots, reference lines and text on y axis 1 keep their own scale
sysuse auto, clear
twoway (line price weight, sort yaxis(2)) (scatter mpg weight), yline(20) title("plot 1 on y axis 2")
rchk y2_plot1
has "panel1.plot1.axis=y2"
has "panel1.plot2.axis=y1"
has "panel1.refline=y1:y:20"
has "panel1.yticks=10|20|30|40"
getv panel1.ylim
ok real(word(subinstr(`"`r(val)'"', ",", " ", .), 2)) < 100
* Stata draws the axis of the first plot on the left
has "panel1.yside=right"
has "panel1.y2side=left"
* a graph whose only y axis is axis 2 draws it as its main axis, on the left
sysuse uslifeexp, clear
twoway line le year, yaxis(2) title("only y axis 2")
rchk y2_only
has "panel1.plot1.axis=y1"
has "panel1.yside=left"
has "panel1.yticks=40|50|60|70|80"
* yscale(alt) puts the y axis on the right
line le year, yscale(alt) title("yscale(alt)")
rchk yalt
has "panel1.yside=right"
* the y-axis title goes above the right end, on the side of the axis
has "ytitle_side=right"
line le year, title("y title on the left")
rchk ytitle_left
has "ytitle_side=left"
* by() keeps the shared title on the left, as Stata does
sysuse auto, clear
scatter mpg weight, yscale(alt) by(foreign)
rchk by_yalt
* (this runs after the graph combine above, so it also checks the family)
has "family=by"
has "ytitle_side=left"
has "panel1.yside=right"
* yaxis(1 2): one region holds both axes (.y_scales is "2 1"); Stata draws both axes,
* the axis-1 title and the grid
sysuse uslifeexp, clear
line le year, yaxis(1 2) title("yaxis(1 2)")
rchk y12
has "panel1.plot1.axis=y1"
has "panel1.yside=left"
has "panel1.y2side=right"
has "panel1.yticks=40|50|60|70|80"
has "panel1.y2ticks=40|50|60|70|80"
* (the variable label is "life expectancy" in Stata 16's copy of the data)
getv panel1.ylabel
ok lower(`"`r(val)'"') == "life expectancy"
has "panel1.ygrid=1"
twoway (line le_male year, yaxis(1 2)) (line le_female year), title("yaxis(1 2) and a second plot")
rchk y12_two
has "panel1.plot1.axis=y1"
has "panel1.plot2.axis=y1"
has "panel1.yside=left"
has "panel1.y2side=right"
has "panel1.ygrid=1"
* a region on axis 1 and 2 next to a region on axis 2 alone: plots keep their own scale
sysuse auto, clear
twoway (scatter mpg weight) (scatter price weight, yaxis(2)) (scatter turn weight, yaxis(1 2)), title("mixed regions")
rchk y12_mixed
has "panel1.plot2.axis=y2"
has "panel1.plot3.axis=y1"
has "panel1.y2ticks=0|5,000|10,000|15,000"

* -- the legend map numbers plots region by region: with plot 2 on yaxis(2), key 2 is plot 3
twoway (scatter mpg weight) (scatter price weight, yaxis(2)) (scatter turn weight), title("legend across regions")
rchk legend_regions
* (Stata 16's auto data label turn "Turn Circle (ft.) ")
getv panel1.legend
ok ustrregexm(lower(`"`r(val)'"'), "^mileage \(mpg\)\|turn circle \(ft\.\) ?\|price$")
has "panel1.legend_plots=1|3|2"
twoway (scatter mpg weight) (scatter price weight, yaxis(2)) (scatter turn weight), legend(order(3 2 1)) title("order() across regions")
rchk legend_regions_order
getv panel1.legend
ok ustrregexm(lower(`"`r(val)'"'), "^price\|turn circle \(ft\.\) ?\|mileage \(mpg\)$")
has "panel1.legend_plots=2|3|1"
twoway (scatter mpg weight) (scatter price weight, yaxis(2)) (scatter turn weight), by(foreign)
rchk legend_regions_by
has "family=by"
has "panel1.plot2.axis=y2"
has "panel1.ptitle=Domestic"
has "panel2.ptitle=Foreign"
* the shared legend maps its keys region by region, as in a single twoway graph
has "fig_legend_plots=1|3|2"
getv fig_legend
ok ustrregexm(lower(`"`r(val)'"'), "^mileage \(mpg\)\|turn circle \(ft\.\) ?\|price$")
sysuse uslifeexp, clear

* -- gpolish endlabel next to a y axis: the plot-region margin is kept, so the labels
*    sit between the axis and the lines, as in Stata's export
line le_wfemale le_wmale year, scheme(pypolish) legend(off) title("end labels on the left")
gpolish
gpolish endlabel, side(left) values
rchk endlabel_left
has "panel1.ann_overlaps=0"
has "panel1.ann_tick_overlaps=0"
getv panel1.xdata_pts
ok real(word(subinstr(`"`r(val)'"', ",", " ", .), 1)) > 100
line le_wfemale le_wmale year, scheme(pypolish) legend(off) yscale(alt) title("end labels, y axis on the right")
gpolish
gpolish endlabel, values
rchk endlabel_alt
has "panel1.ann_overlaps=0"
has "panel1.ann_tick_overlaps=0"
getv panel1.xdata_pts
ok real(word(subinstr(`"`r(val)'"', ",", " ", .), 2)) > 100
twoway (line le_wfemale year) (line le_wmale year, yaxis(2)), scheme(pypolish) legend(off) title("end labels, two y axes")
gpolish
gpolish endlabel, values
rchk endlabel_y2
has "panel1.ann_tick_overlaps=0"
has "panel1.y2side=right"
getv panel1.xdata_pts
ok real(word(subinstr(`"`r(val)'"', ",", " ", .), 2)) > 100
* gpolish's objects on a graph whose plot 1 is on yaxis(2) are drawn on that axis
twoway (line le_wfemale year, yaxis(2)) (line le_bmale year), scheme(pypolish) legend(off) title("plot 1 on y axis 2, end labels")
gpolish
gpolish endlabel, values
rchk endlabel_plot1y2
has "panel1.ann=79.9|left|0|y2|in"
has "panel1.ann=67.8|left|0|y2|in"
has "panel1.ann_overlaps=0"
* graph combine: a member with end labels on the left keeps its plot-region margin in
* its own cell; its data are not squeezed and its labels clear the tick labels
line le_wfemale le_wmale year, scheme(pypolish) legend(off) name(ga, replace) title("A")
gpolish, name(ga)
gpolish endlabel, side(left) name(ga)
line le_bfemale le_bmale year, scheme(pypolish) legend(off) name(gb, replace) title("B")
gpolish, name(gb)
gpolish endlabel, name(gb) values
graph combine ga gb, title("combine with end labels")
rchk combine_endlabel
has "panel1.ann_tick_overlaps=0"
has "panel2.ann_tick_overlaps=0"
has "panel1.ann_overlaps=0"
has "panel2.ann_overlaps=0"
* (Stata's own export gives the data about a quarter of panel A's plot width on 16.1
* and about 40% on 19.5; the squeezed render gave under 15%, and 16.1 renders 0.199)
getv panel1.xdata_frac
ok real(`"`r(val)'"') > 0.18
* as in Stata, the member whose end labels sit outside the plot has the narrower plot
getv panel1.axes_wpts
local wa = real(`"`r(val)'"')
getv panel2.axes_wpts
ok `wa' > real(`"`r(val)'"')
graph drop ga gb
* text() in a graph combine member is drawn (the member reports .n_text as 0)
line le year, name(ga, replace) text(75 1950 "a text box", box) text(60 1920 "second" "two lines", place(e))
line le_male year, name(gb, replace) text(50 1960 "member two", color(red))
graph combine ga gb, title("text() in combine members")
rchk combine_text
has "panel1.ann=a text box|left|0|y1|in"
has "panel1.ann=second|left|0|y1|in"
has "panel1.ann=two lines|left|0|y1|in"
has "panel2.ann=member two|left|0|y1|in"
graph drop ga gb
* a default plot-region margin keeps gr2mpl's padding (no change from earlier renders)
line le year, title("default margin")
rchk margin_default
getv panel1.xdata_pts
ok real(word(subinstr(`"`r(val)'"', ",", " ", .), 1)) < 20

* -- gpolish endlabel, values on a reversed x axis: each value is paired on screen
line le_wfemale le_wmale year, scheme(pypolish) legend(off) xscale(reverse) title("reversed, values")
gpolish
gpolish endlabel, values
rchk endlabel_reversed
has "panel1.ann_overlaps=0"
getv panel1.endpair_mingap
ok real(`"`r(val)'"') > 4

* -- the README quick start: values clear of the labels
line le_wfemale le_wmale le_bfemale le_bmale year, scheme(pypolish) legend(off) ///
    xsize(7) ysize(4.6) title("Life expectancy rose for every group", size(13.5pt))
gpolish
gpolish endlabel, values dots
gpolish callout "1918 influenza" "pandemic", to(1918.6 30.6)
rchk quickstart
has "panel1.ann_overlaps=0"
getv panel1.endpair_mingap
ok real(`"`r(val)'"') > 4

* -- legend: text-only entries and a plot listed twice keep their place in order()
sysuse auto, clear
twoway (scatter mpg weight if foreign) (scatter mpg weight if !foreign) (lfit mpg weight), ///
    legend(order(1 "A" - "group" 2 "B" 1 "A again")) title("text-only and repeated entries")
rchk legend_text
has "panel1.legend=A|group|B|A again"

* -- graph bar by(): every panel is drawn on the scale Stata shares across panels
sysuse auto, clear
graph bar mpg, over(rep78) by(foreign)
rchk barby_scale
getv panel1.barscale
local s1 `"`r(val)'"'
getv panel2.barscale
ok `"`r(val)'"' == `"`s1'"'
ok real(word(subinstr(`"`s1'"', ",", " ", .), 2)) >= 32
graph hbar mpg, over(rep78) by(foreign)
rchk hbarby_scale
getv panel1.barscale
local s1 `"`r(val)'"'
getv panel2.barscale
ok `"`r(val)'"' == `"`s1'"'
* yrescale keeps each panel on its own scale
graph bar mpg, over(rep78) by(foreign, yrescale)
rchk barby_yres
getv panel1.barscale
local s1 `"`r(val)'"'
getv panel2.barscale
ok `"`r(val)'"' != `"`s1'"'

* -- legends with more than one row read row by row, as Stata fills them
sysuse uslifeexp, clear
* (the variable labels differ between Stata releases, so the order is built from them)
local want
foreach v in le_wm le_bm le_wf le_bf le {
    local want `"`want'`: variable label `v''|"'
}
local want = substr(`"`want'"', 1, strlen(`"`want'"') - 1)
twoway line le_wm le_bm le_wf le_bf le year, legend(cols(3))
rchk leg_rowfirst
has "panel1.legend=`want'"
twoway line le_wm le_bm le_wf le_bf le year, legend(cols(2) colfirst)
rchk leg_colfirst
* colfirst keeps matplotlib's column-first fill, so the keys do not read in plot order
has "panel1.legend=`want'", absent
sysuse auto, clear
graph bar (count), over(rep78) blabel(bar) asyvars
rchk leg_asy
has "panel1.legend=1|2|3|4|5"
sysuse auto, clear
twoway (scatter mpg weight) (lfit mpg weight) (qfit mpg weight) (mspline mpg weight) (lowess mpg weight), by(foreign) legend(cols(3))
rchk leg_by
getv fig_legend
local fl `"`r(val)'"'
getv fig_legend_read
ok `"`r(val)'"' == `"`fl'"'

* -- two over() groups: the outer labels sit below the inner labels, rotated or not
sysuse auto, clear
graph bar mpg, over(foreign) over(rep78) title("Bar")
rchk bar_two_over
has "panel1.sup_overlaps=0"
has "panel1.sup_below=1"
graph bar mpg, over(foreign) over(rep78) xsize(8)
rchk bar_two_over_wide
has "panel1.sup_overlaps=0"
has "panel1.sup_below=1"

* -- matplotlib version: gr2mpl needs 3.6 or later
gr2mpl doctor
ok "`r(mplok)'" == "1"
* doctor prints the matplotlib line once
capture log close g2mdoc
log using "tests/out/doctor.txt", text replace name(g2mdoc)
gr2mpl doctor
log close g2mdoc
local nml 0
tempname dh
file open `dh' using "tests/out/doctor.txt", read text
file read `dh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "matplotlib  :") local ++nml
    file read `dh' line
}
file close `dh'
ok `nml' == 1
erase "tests/out/doctor.txt"
if c(os) != "Windows" {
    * a stand-in Python that reports matplotlib 3.5.3
    tempname fk
    file open `fk' using "tests/out/oldmpl.sh", write text replace
    file write `fk' "#!/bin/sh" _n `"echo "MPLOK 3.5.3""' _n
    file close `fk'
    shell chmod +x "tests/out/oldmpl.sh"
    scatter mpg weight, name(mv, replace)
    capture gr2mpl, name(mv) saving("tests/out/r_old.png") replace python("`c(pwd)'/tests/out/oldmpl.sh")
    ok _rc == 601
    capture confirm file "tests/out/r_old.png"
    ok _rc != 0
    gr2mpl doctor, python("`c(pwd)'/tests/out/oldmpl.sh")
    ok "`r(mplok)'" == "0"
    ok "`r(mplversion)'" == "3.5.3"
    * the old Python is not remembered: the next call uses the working one
    gr2mpl, name(mv) saving("tests/out/r_old.png") replace
    ok "`r(python)'" != "`c(pwd)'/tests/out/oldmpl.sh"
    * the default search passes over a Python whose matplotlib is too old and uses the
    * next one; it stops with 601 only when none is new enough
    local keeppy `"$GR2MPL_PYTHON"'
    if `"`keeppy'"' != "" {
        global GR2MPL_PYTHON
        global GR2MPL_PYRESOLVED
        global GR2MPL_SEARCH `""`c(pwd)'/tests/out/oldmpl.sh" "`keeppy'""'
        gr2mpl, name(mv) saving("tests/out/r_old.png") replace
        ok `"`r(python)'"' == `"`keeppy'"'
        gr2mpl doctor
        ok "`r(mplok)'" == "1"
        global GR2MPL_PYRESOLVED
        global GR2MPL_SEARCH `""`c(pwd)'/tests/out/oldmpl.sh""'
        capture erase "tests/out/r_old.png"
        capture gr2mpl, name(mv) saving("tests/out/r_old.png") replace
        ok _rc == 601
        capture confirm file "tests/out/r_old.png"
        ok _rc != 0
        * the 601 message names the global itself, not its contents twice
        global GR2MPL_SEARCH nosuchpy1 nosuchpy2
        global GR2MPL_PYRESOLVED
        capture log close g2mse
        log using "tests/out/search601.txt", text replace name(g2mse)
        capture noisily gr2mpl, name(mv) saving("tests/out/r_old.png") replace
        local rc601 = _rc
        log close g2mse
        ok `rc601' == 601
        local nfrom 0
        local nbad 0
        file open `dh' using "tests/out/search601.txt", read text
        file read `dh' line
        while r(eof) == 0 {
            if strpos(`"`macval(line)'"', "nosuchpy1 nosuchpy2   (from " + char(36) + "GR2MPL_SEARCH)") local ++nfrom
            if strpos(`"`macval(line)'"', "(from nosuchpy1") local ++nbad
            file read `dh' line
        }
        file close `dh'
        ok `nfrom' == 1
        ok `nbad' == 0
        erase "tests/out/search601.txt"
        * the search stops at the first Python that is new enough: a stand-in listed
        * after it (one that reports 3.9.0 but cannot draw) is not used
        file open `fk' using "tests/out/newmpl.sh", write text replace
        file write `fk' "#!/bin/sh" _n `"echo "MPLOK 3.9.0""' _n
        file close `fk'
        shell chmod +x "tests/out/newmpl.sh"
        global GR2MPL_PYRESOLVED
        global GR2MPL_SEARCH `""`keeppy'" "`c(pwd)'/tests/out/newmpl.sh""'
        gr2mpl, name(mv) saving("tests/out/r_old.png") replace
        ok `"`r(python)'"' == `"`keeppy'"'
        ok `"$GR2MPL_PYRESOLVED"' == `"`keeppy'"'
        * python() is used as given; the default search is not run after it
        global GR2MPL_PYRESOLVED
        global GR2MPL_SEARCH `""`c(pwd)'/tests/out/newmpl.sh""'
        gr2mpl, name(mv) saving("tests/out/r_old.png") replace python(`"`keeppy'"')
        ok `"`r(python)'"' == `"`keeppy'"'
        ok `"$GR2MPL_PYRESOLVED"' == `"`keeppy'"'
        * a quoted python() path is accepted
        global GR2MPL_PYRESOLVED
        gr2mpl, name(mv) saving("tests/out/r_old.png") replace python(`""`keeppy'""')
        ok `"`r(python)'"' == `"`keeppy'"'
        erase "tests/out/newmpl.sh"
        global GR2MPL_SEARCH
        global GR2MPL_PYRESOLVED
        global GR2MPL_PYMODE
        global GR2MPL_MPLVERSION
        global GR2MPL_PYTHON `"`keeppy'"'
    }
    erase "tests/out/oldmpl.sh"
    capture erase "tests/out/r_old.png"
}

* -- options and temporary files
sysuse auto, clear
scatter mpg weight, name(tf, replace)
capture gr2mpl, name(tf) palette(viridis) saving("tests/out/r_pal.png") replace
ok _rc == 198
gr2mpl, name(tf) palette(HOUSE) saving("tests/out/r_pal.png") replace
ok `"`r(unsupported)'"' == ""
* saving() that names a folder writes <name>_mpl.png into it
capture erase "tests/out/tf_mpl.png"
gr2mpl, name(tf) saving("tests/out/") replace
confirm file "tests/out/tf_mpl.png"
ok `"`r(filename)'"' == "tests/out/tf_mpl.png"
capture gr2mpl, name(tf) saving("tests/out/.png") replace
ok _rc == 198
* without keepspec the spec folder and its data are removed
capture mkdir "tests/spec"
gr2mpl, name(tf) saving("tests/out/r_tmp.png") replace specdir("tests/spec/r_tmp")
ok `"`r(specdir)'"' == ""
mata: st_local("ex", strofreal(direxists("tests/spec/r_tmp")))
ok "`ex'" == "0"
gr2mpl, name(tf) saving("tests/out/r_tmp.png") replace
ok `"`r(specdir)'"' == ""
* a folder that already existed is kept, but gr2mpl's files in it are removed
capture mkdir "tests/spec/r_pre"
gr2mpl, name(tf) saving("tests/out/r_tmp.png") replace specdir("tests/spec/r_pre")
mata: st_local("ex", strofreal(direxists("tests/spec/r_pre")))
ok "`ex'" == "1"
local fl : dir "tests/spec/r_pre" files "*"
ok `"`fl'"' == ""
* with keepspec the folder is kept and reported
gr2mpl, name(tf) saving("tests/out/r_tmp.png") replace keepspec
local sd `"`r(specdir)'"'
ok `"`sd'"' != ""
confirm file `"`sd'/spec.json"'
confirm file `"`sd'/render_info.txt"'
local fl : dir `"`sd'"' files "*"
foreach f of local fl {
    erase `"`sd'/`f'"'
}
rmdir `"`sd'"'
* a failed render cleans up too
capture gr2mpl, name(tf) saving("tests/out/r_tmp.png") replace specdir("tests/spec/r_fail") python("/no/such/python")
ok _rc == 601
mata: st_local("ex", strofreal(direxists("tests/spec/r_fail")))
ok "`ex'" == "0"

* -- bars with the default barwidth on a wide continuous axis still draw
* (each is outlined in its own colour, so a sub-pixel bar shows as a hairline)
tempname pf
file open `pf' using "tests/out/barpix.py", write text replace
file write `pf' "import sys" _n "from matplotlib.image import imread" _n
file write `pf' "a = imread(sys.argv[1])[..., :3]" _n
file write `pf' "n = int(((a.max(axis=2) - a.min(axis=2)) > 0.15).sum())" _n
* with a third argument, count near-black pixels instead
file write `pf' "n = int((a.max(axis=2) < 0.2).sum()) if len(sys.argv) > 3 else n" _n
file write `pf' "open(sys.argv[2], 'w').write(str(n))" _n
file close `pf'
capture program drop barpix
program barpix
    * barpix tag minimum [maximum [dark]]: the gr2mpl PNG holds at least minimum coloured
    * pixels and, when maximum is given, no more than maximum; dark counts near-black pixels
    args tag mn mx dark
    shell "$GR2MPL_PYTHON" "tests/out/barpix.py" "tests/out/r_`tag'_mpl.png" "tests/out/barpix.txt" `dark'
    tempname fh
    file open `fh' using "tests/out/barpix.txt", read text
    file read `fh' n
    file close `fh'
    erase "tests/out/barpix.txt"
    if real("`n'") < `mn' {
        di as err "`tag': `n' coloured pixels, expected at least `mn'"
        exit 9
    }
    if "`mx'" != "" & real("`n'") > 0`mx' {
        di as err "`tag': `n' coloured pixels, expected at most `mx'"
        exit 9
    }
    global R_N = $R_N + 1
end
sysuse auto, clear
gen lo = mpg - 3
gen hi = mpg + 3
twoway rbar lo hi weight, title("rbar on a weight axis")
rchk rbar_wide
barpix rbar_wide 1500
twoway bar mpg weight, title("bar on a weight axis")
rchk bar_wide
barpix bar_wide 3000
* the rbar layer is drawn over an rarea: gr2mpl draws the rarea in a light blue-gray
* whose channel spread (about 0.09) is under the 0.15 threshold, so the coloured
* pixels here come from the cranberry bars
twoway (rarea lo hi weight, sort) (rbar lo hi weight, color(cranberry)), title("rarea and rbar")
rchk rbar_layer
barpix rbar_layer 1500
* color(none) and fcolor(none) draw no fill, as in Stata (not black bars)
twoway rbar lo hi weight, color(none) barwidth(40) title("rbar, color(none)")
rchk rbar_none
barpix rbar_none 0 50
* tick labels and the title are near-black too; black bars would add tens of thousands
barpix rbar_none 0 8000 dark
twoway bar mpg weight, fcolor(none) barwidth(40) title("bar, fcolor(none)")
rchk bar_fnone
barpix bar_fnone 1000
* area and rarea with color(none) draw their outline in lcolor(), as Stata does
sysuse uslifeexp, clear
gen lo = le - 3
twoway area le year, color(none) lcolor(cranberry) title("area, color(none)")
rchk area_none
barpix area_none 500
twoway rarea lo le year, color(none) lcolor(cranberry) title("rarea, color(none)")
rchk rarea_none
barpix rarea_none 1000
* with lcolor(none) too, nothing coloured is drawn
twoway area le year, color(none) lcolor(none) title("area, no colour")
rchk area_none2
barpix area_none2 0 50
* mcolor(none) and mfcolor(none) with a visible mlcolor() draw hollow markers:
* the outline is drawn and the marker is not filled black
sysuse auto, clear
scatter mpg weight, mcolor(none) mlcolor(cranberry) msize(large) title("scatter, mcolor(none)")
rchk mcolor_none
barpix mcolor_none 1000
barpix mcolor_none 0 8000 dark
scatter mpg weight, mfcolor(none) mlcolor(cranberry) msize(large) title("scatter, mfcolor(none)")
rchk mfcolor_none
barpix mfcolor_none 1000
barpix mfcolor_none 0 8000 dark
erase "tests/out/barpix.py"

* -- marker sizes match Stata's at msscale(1): the diameter of two markers in the
* gr2mpl PNG is within 7% of the diameter in Stata's PNG at the same width
file open `pf' using "tests/out/markpix.py", write text replace
file write `pf' "import sys" _n "from matplotlib.image import imread" _n
file write `pf' "def n(f):" _n
file write `pf' "    a = imread(f)[..., :3] * 255" _n
file write `pf' "    return int(((abs(a[..., 0] - 26) < 40) & (abs(a[..., 1] - 133) < 40) & (a[..., 2] > 200)).sum())" _n
file write `pf' "open(sys.argv[3], 'w').write(str((n(sys.argv[2]) / n(sys.argv[1])) ** 0.5))" _n
file close `pf'
foreach s in medium large {
    twoway scatteri 1 1 2 2, msize(`s') mcolor("26 133 255") xsize(5) ysize(4)
    rchk msize_`s' "width(1200)"
    shell "$GR2MPL_PYTHON" "tests/out/markpix.py" "tests/out/r_msize_`s'_stata.png" "tests/out/r_msize_`s'_mpl.png" "tests/out/markpix.txt"
    file open `pf' using "tests/out/markpix.txt", read text
    file read `pf' ratio
    file close `pf'
    erase "tests/out/markpix.txt"
    di as txt "msize(`s'): gr2mpl/Stata marker diameter = `ratio'"
    ok abs(real("`ratio'") - 1) < 0.07
}
erase "tests/out/markpix.py"

* -- legend(on) on a one-plot graph draws the legend; the default draws none
sysuse auto, clear
twoway scatter mpg weight, legend(on pos(6)) title("legend(on), one plot")
rchk legend_on1
has "panel1.legend=Mileage (mpg)"
twoway scatter mpg weight, title("default legend, one plot")
rchk legend_def1
has "panel1.legend=Mileage (mpg)", absent
twoway scatter mpg weight, legend(on label(1 "Cars")) title("legend(on label()), one plot")
rchk legend_on1lab
has "panel1.legend=Cars"

* -- xlabel(none) / ylabel(none) draw no major tick labels (twoway and graph bar)
sysuse auto, clear
twoway (scatter mpg weight) (lfit mpg weight), legend(off) xlabel(none) ylabel(none) title("labels none")
rchk lab_none
has "panel1.xticks="
has "panel1.yticks="
has "panel1.ygrid=0"
twoway scatter mpg weight, xlabel(none) title("xlabel none")
rchk xlab_none
has "panel1.xticks="
has "panel1.yticks=", absent
twoway scatter mpg weight, ylabel(none) xscale(off) title("ylabel none, xscale off")
rchk ylab_none_xoff
has "panel1.yticks="
graph bar mpg, over(rep78) ylabel(none) title("bar ylabel none")
rchk bar_ylab_none
has "panel1.yticks="
* nolabels keeps the tick positions but no labels, as before
twoway scatter mpg weight, xlabel(, nolabels) title("nolabels")
rchk xlab_nolab
has "panel1.xticks=", absent

* -- xmlabel() / ymlabel() are drawn as labelled minor ticks
twoway scatter mpg weight, ylabel(10 "ten" 20 "twenty" 40 "forty") ymlabel(15 25 35) xmlabel(2500 3500 4500)
rchk mlabels
has "panel1.yminor=15|25|35"
has "panel1.xminor=2,500|3,500|4,500"
has "panel1.yticks=ten|twenty|forty"
graph bar mpg, over(rep78) ymlabel(5 15)
rchk bar_mlabels
has "panel1.yminor=5|15"

* -- aspectratio() gives the plot region Stata's height-to-width ratio
twoway scatter mpg weight, aspectratio(1) title("aspectratio(1)")
rchk aspect1
has "panel1.box_aspect=1"
twoway scatter mpg weight, aspectratio(0.5)
rchk aspect05
has "panel1.box_aspect=0.5"
twoway scatter mpg weight
rchk aspect_def
has "panel1.box_aspect=0"

* -- saving(file, replace) works as in graph's own saving(); a bad suboption is an error
twoway scatter mpg weight
capture erase "tests/out/r_sav_sub.png"
gr2mpl, saving("tests/out/r_sav_sub.png")
gr2mpl, saving("tests/out/r_sav_sub.png", replace)
ok "`r(filename)'" == "tests/out/r_sav_sub.png"
capture confirm file "tests/out/r_sav_sub.png, replace.png"
ok _rc != 0
gr2mpl, saving(tests/out/r_sav_sub.png, replace)
ok "`r(filename)'" == "tests/out/r_sav_sub.png"
capture gr2mpl, saving("tests/out/r_sav_sub.png")
ok _rc == 602
capture gr2mpl, saving("tests/out/r_sav_sub.png", bogus)
ok _rc == 198
erase "tests/out/r_sav_sub.png"

* -- lwscale() and msscale() below 1 render (JSON needs 0.5, not .5); 0 or less is an error
twoway scatter mpg weight
gr2mpl, msscale(0.5) saving("tests/out/r_scale.png") replace
ok _rc == 0
gr2mpl, lwscale(.75) msscale(.5) saving("tests/out/r_scale.png") replace
capture confirm file "tests/out/r_scale.png"
ok _rc == 0
capture gr2mpl, msscale(-1) saving("tests/out/r_scale.png") replace
ok _rc == 198
capture gr2mpl, lwscale(0) saving("tests/out/r_scale.png") replace
ok _rc == 198
erase "tests/out/r_scale.png"

* -- gr2mpl doctor returns r(mplok) as a number
gr2mpl doctor
ok r(mplok) == 1

di as res "$R_N checks passed"
