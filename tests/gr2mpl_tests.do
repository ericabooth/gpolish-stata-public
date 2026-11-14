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
    capture noisily gr2mpl, saving("tests/out/`tag'_mpl.png") specdir("tests/spec/`tag'") keepspec lwscale(1.7) msscale(1.5) `opts'
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

