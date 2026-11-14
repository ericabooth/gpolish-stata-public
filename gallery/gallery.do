* gpolish gallery: every example is drawn three ways.
*   a = Stata's default look
*   b = scheme(pypolish) + gpolish        (still a Stata graph)
*   c = the b graph redrawn by gr2mpl     (matplotlib PNG)
* Run from the repository root:   stata-mp -b do gallery/gallery.do
* gr2mpl needs Python with matplotlib; set $GR2MPL_PYTHON or the environment
* variable GR2MPL_PYTHON if Stata's own Python does not have it.
version 16
set more off
clear all
adopath ++ "`c(pwd)'/src"
if "$GR2MPL_PYTHON"=="" global GR2MPL_PYTHON : environment GR2MPL_PYTHON
graph set window fontface "Open Sans"
capture mkdir "gallery/img"

capture program drop shotA
program shotA
    args tag
    graph export "gallery/img/`tag'_a.png", replace width(1400)
end
capture program drop shotBC
program shotBC
    args tag opts
    graph export "gallery/img/`tag'_b.png", replace width(1400)
    gr2mpl, saving("gallery/img/`tag'_c.png") replace width(1400) `opts'
end
* options shared by every polished version
local SZ xsize(7) ysize(4.6)
local TS size(13.5pt)
local SS size(10pt)
local NS size(8pt)
local LS labsize(9pt)

* ---------------------------------------------------------------- 01 lines
sysuse uslifeexp, clear
label var le_wfemale "White women"
label var le_wmale   "White men"
label var le_bfemale "Black women"
label var le_bmale   "Black men"
line le_wfemale le_wmale le_bfemale le_bmale year, title("Life expectancy at birth") `SZ'
shotA 01_lines
line le_wfemale le_wmale le_bfemale le_bmale year, scheme(pypolish) legend(off) `SZ' ///
    lcolor("11 93 122" "111 177 199" "184 67 15" "240 163 94") ///
    title("Life expectancy rose for every group, but the racial gap never closed", `TS') ///
    subtitle("Life expectancy at birth in the United States, 1900–1999, in years", `SS') ///
    note("Source: National Vital Statistics Reports, Vol. 50, No. 6.", `NS') ///
    xtitle("") ytitle("") ylabel(30(10)80, `LS') xlabel(1900(20)1980 1999, `LS') yscale(range(28 83))
gpolish
gpolish endlabel, values dots
gpolish callout "1918 influenza" "pandemic", to(1918.6 30.6)
gpolish callout "By 1999 the gap" "was 5 years", to(1997.3 77.2)
shotBC 01_lines

* ---------------------------------------------------------------- 02 labelled scatter
sysuse lifeexp, clear
drop if missing(gnppc, lexp)
gen lngnp = ln(gnppc)
quietly regress lexp lngnp
local a = _b[_cons]
local b = _b[lngnp]
twoway (scatter lexp gnppc if region==1) (scatter lexp gnppc if region==2) (scatter lexp gnppc if region==3), ///
    xscale(log) legend(order(1 "Europe & C. Asia" 2 "North America" 3 "South America")) ///
    title("Life expectancy and GNP per capita") `SZ'
shotA 02_scatter
twoway (function y = `a' + `b'*ln(x), range(350 45000) lcolor("154 154 154") lpattern(dash) lwidth(medium)) ///
       (scatter lexp gnppc if region==1, mcolor("11 93 122%85") mlcolor(white) mlwidth(vthin) msize(6pt)) ///
       (scatter lexp gnppc if region==2, mcolor("184 67 15%85") mlcolor(white) mlwidth(vthin) msize(6pt)) ///
       (scatter lexp gnppc if region==3, mcolor("224 161 0%85") mlcolor(white) mlwidth(vthin) msize(6pt)) ///
    , scheme(pypolish) `SZ' xscale(log range(300 52000)) yscale(range(52.5 81.5)) ///
    xlabel(500 "\$500" 1000 "\$1,000" 2000 "\$2,000" 5000 "\$5,000" 10000 "\$10,000" 20000 "\$20,000" 40000 "\$40,000", `LS') ///
    ylabel(55(5)80, `LS') ytitle("") xtitle("GNP per capita, 1998 (log scale)", size(9pt)) ///
    title("Richer countries live longer, but income explains less at the top", `TS') ///
    subtitle("Life expectancy at birth (years) and GNP per capita, 63 countries, 1998", `SS') ///
    note("Source: World Bank, World Development Indicators.", `NS') ///
    legend(order(2 "Europe & Central Asia" 3 "North America" 4 "South America") rows(1) position(11) span ///
           size(9.5pt) region(lstyle(none) margin(zero)) symxsize(*.4) keygap(*.5) colgap(*2.5) bmargin(b+2))
gpolish
gpolish legend, plots(2 3 4)
gpolish ptlabel country if inlist(country, "Haiti", "United States", "Switzerland", "Bolivia", "Russian Federation", "Moldova") ///
    | inlist(country, "Armenia", "Brazil", "Kazakhstan", "Canada", "Guatemala", "Denmark"), x(gnppc) y(lexp)
gpolish callout "Log-linear fit", to(9000 74.6) color("107 107 107") size(8.6) noarrow
shotBC 02_scatter

* ---------------------------------------------------------------- 03 marginsplot
sysuse nlsw88, clear
quietly regress wage c.ttl_exp##i.collgrad i.race
quietly margins collgrad, at(ttl_exp=(0(4)28))
marginsplot, `SZ'
shotA 03_margins
marginsplot, scheme(pypolish) recast(line) recastci(rarea) ciopts(color(%18) lwidth(none)) legend(off) `SZ' ///
    title("College graduates start higher and pull away with experience", `TS') ///
    subtitle("Predicted hourly wage (1988 dollars) by total work experience", `SS') ///
    note("Source: NLSW 1988 extract. Linear model with race controls; bands are 95% confidence intervals.", `NS') ///
    xtitle("Years of work experience", size(9pt)) ytitle("") xlabel(, `LS') ylabel(, `LS')
gpolish
gpolish endlabel, values format(%4.2f) dots labels("Not a college graduate" "College graduate") wrap(8)
shotBC 03_margins

* ---------------------------------------------------------------- 04 one series highlighted
sysuse uslifeexp, clear
label var le_bfemale "Black women"
line le_wmale le_wfemale le_bmale le_male le_female le le_bfemale year if year>=1950, title("Life expectancy, 1950-1999") `SZ'
shotA 04_highlight
local g "205 205 205"
line le_wmale le_wfemale le_bmale le_male le_female le le_bfemale year if year>=1950, scheme(pypolish) legend(off) `SZ' ///
    lcolor("`g'" "`g'" "`g'" "`g'" "`g'" "`g'" "184 67 15") lwidth(medium medium medium medium medium medium thick) ///
    title("Black women gained the most after 1950", `TS') ///
    subtitle("Life expectancy at birth, years; other groups in gray", `SS') ///
    note("Source: National Vital Statistics Reports, Vol. 50, No. 6.", `NS') ///
    xtitle("") ytitle("") xlabel(1950(10)1990 1999, `LS') ylabel(, `LS')
gpolish
gpolish endlabel, plots(7) values dots
shotBC 04_highlight

* ---------------------------------------------------------------- 05 scatter with fit and band
sysuse auto, clear
twoway (lfitci mpg weight) (scatter mpg weight), title("Mileage and weight") `SZ'
shotA 05_fitci
twoway (lfitci mpg weight, lcolor("60 60 60") lwidth(medium) fcolor("225 225 225") alcolor("225 225 225")) ///
       (scatter mpg weight if !foreign, mcolor("11 93 122%85") mlcolor(white) mlwidth(vthin) msize(6pt)) ///
       (scatter mpg weight if foreign,  mcolor("184 67 15%85") mlcolor(white) mlwidth(vthin) msize(6pt)) ///
    , scheme(pypolish) `SZ' ///
    title("Heavier cars get fewer miles per gallon", `TS') ///
    subtitle("Mileage (mpg) and weight (lbs.), 74 cars, 1978", `SS') note("Source: Stata auto dataset.", `NS') ///
    xtitle("Weight (lbs.)", size(9pt)) ytitle("") xlabel(, `LS' format(%9.0fc)) ylabel(, `LS') ///
    legend(order(3 "Domestic" 4 "Foreign") rows(1) position(11) span size(9.5pt) region(lstyle(none) margin(zero)) ///
           symxsize(*.4) keygap(*.5) colgap(*2.5) bmargin(b+2))
gpolish
gpolish legend, plots(3 4)
gpolish ptlabel make if inlist(make, "VW Diesel", "Linc. Mark V", "Plym. Arrow", "Cad. Seville", "Subaru"), x(weight) y(mpg)
shotBC 05_fitci

* ---------------------------------------------------------------- 06 daily time series
sysuse sp500, clear
line close date, title("S&P 500, 2001") `SZ'
shotA 06_timeseries
quietly summarize close
local lo = r(min)
quietly summarize date if close==`lo'
local dlo = r(mean)
line close date, scheme(pypolish) legend(off) `SZ' lcolor("11 93 122") lwidth(medium) ///
    title("The S&P 500 fell 12 percent in 2001", `TS') subtitle("Daily closing value", `SS') ///
    note("Source: Stata sp500 dataset (Yahoo! Finance).", `NS') ///
    xtitle("") ytitle("") ylabel(, `LS' format(%9.0fc)) xlabel(, `LS' format(%tdMon_CCYY)) graphregion(margin(r+5))
gpolish
gpolish callout "Low of `=strtrim("`: display %4.0f `lo''")'" "on `: display %tdMonth_dd `dlo''", to(`dlo' `lo')
shotBC 06_timeseries

* ---------------------------------------------------------------- 07 coefficient plot built from twoway
sysuse nlsw88, clear
quietly regress wage i.collgrad i.union i.married i.south i.smsa c.tenure
tempname M
matrix `M' = r(table)
clear
set obs 6
gen k = 7 - _n
gen str30 lab = ""
gen b = .
gen lo = .
gen hi = .
local names "1.collgrad 1.union 1.married 1.south 1.smsa tenure"
local labs `""College graduate" "Union member" "Married" "Lives in the South" "Lives in a metro area" "Job tenure (per year)""'
forvalues i = 1/6 {
    local nm : word `i' of `names'
    replace b  = `M'[1, colnumb(`M', "`nm'")] in `i'
    replace lo = `M'[5, colnumb(`M', "`nm'")] in `i'
    replace hi = `M'[6, colnumb(`M', "`nm'")] in `i'
    replace lab = `"`: word `i' of `labs''"' in `i'
}
local yl
forvalues i = 1/6 {
    local yl `yl' `=k[`i']' `"`=lab[`i']'"'
}
twoway (rcap lo hi k, horizontal) (scatter k b), ylabel(`yl', angle(0)) xline(0) ytitle("") ///
    title("Wage regression coefficients") legend(off) `SZ'
shotA 07_coef
twoway (rcap lo hi k, horizontal lcolor("11 93 122") lwidth(medthick) msize(zero)) ///
       (scatter k b, mcolor("11 93 122") mlcolor(white) mlwidth(vthin) msize(7pt)) ///
    , scheme(pypolish) legend(off) `SZ' ylabel(`yl', `LS' nogrid) yscale(range(0.5 6.5)) ///
    xline(0, lcolor("120 120 120") lwidth(thin)) xlabel(, `LS' grid glcolor("228 228 228") glwidth(thin)) ///
    title("A college degree is worth about three dollars an hour", `TS') ///
    subtitle("Change in hourly wage (1988 dollars), with 95% confidence intervals", `SS') ///
    note("Source: NLSW 1988 extract. Linear regression of hourly wage; N = 2,231.", `NS') xtitle("") ytitle("")
gpolish
shotBC 07_coef

* ---------------------------------------------------------------- 08 histogram
sysuse nlsw88, clear
histogram wage, title("Hourly wage") `SZ'
shotA 08_histogram
quietly summarize wage, detail
local med = r(p50)
histogram wage, scheme(pypolish) width(1) start(0) frequency `SZ' ///
    title("Most women earned under ten dollars an hour", `TS') ///
    subtitle("Number of women by hourly wage (1988 dollars), one-dollar bins", `SS') ///
    note("Source: NLSW 1988 extract.", `NS') xtitle("") ytitle("") xlabel(0(5)40, `LS') ylabel(, `LS')
gpolish
gpolish callout "Median wage:" "`: display %4.2f `med'' dollars", at(12 285) to(`med' 318) curve(0.2)
shotBC 08_histogram

* ---------------------------------------------------------------- 09 ranked horizontal bars
* graph bar is not a twoway graph: the scheme applies and gpolish bolds the title,
* but the layout commands (endlabel, callout, ptlabel) are twoway only. gr2mpl redraws it.
sysuse nlsw88, clear
graph hbar (mean) wage, over(industry, sort(1) descending) title("Mean wage by industry") `SZ'
shotA 09_hbar
graph hbar (mean) wage, over(industry, sort(1) descending label(`LS')) scheme(pypolish) `SZ' ///
    title("Mining and utilities pay the most", `TS') subtitle("Mean hourly wage (1988 dollars) by industry", `SS') ///
    note("Source: NLSW 1988 extract.", `NS') ytitle("") ylabel(, `LS')
gpolish
shotBC 09_hbar

* ---------------------------------------------------------------- 10 box plot
graph box wage, over(race) title("Hourly wage by race") `SZ'
shotA 10_box
graph box wage, over(race, label(`LS')) scheme(pypolish) `SZ' ///
    title("Wage distributions overlap far more than their means suggest", `TS') ///
    subtitle("Hourly wage (1988 dollars) by race", `SS') note("Source: NLSW 1988 extract.", `NS') ///
    ytitle("") ylabel(, `LS')
gpolish
shotBC 10_box

* ---------------------------------------------------------------- 11 small multiples with by()
preserve
keep if inlist(industry, 4, 6, 7, 11, 12) & inrange(age, 34, 45)
collapse (mean) wage, by(age industry)
line wage age, by(industry, title("Mean wage by age")) xsize(7) ysize(4.6)
shotA 11_by
line wage age, scheme(pypolish) lcolor("11 93 122") xtitle("Age", size(9pt)) ytitle("") xlabel(, `LS') ylabel(, `LS') ///
    by(industry, title("Wages are flat across the late thirties and early forties", `TS') ///
       subtitle("Mean hourly wage (1988 dollars) by age, five industries", `SS') ///
       note("Source: NLSW 1988 extract.", `NS')) xsize(7) ysize(4.6)
gpolish
shotBC 11_by
restore

* ---------------------------------------------------------------- 12 combined panels
sysuse auto, clear
scatter mpg weight, title("Mileage and weight") name(c1, replace) nodraw
graph bar (mean) mpg, over(rep78) title("Mileage by repair record") name(c2, replace) nodraw
histogram price, title("Price") name(c3, replace) nodraw
line mpg weight if foreign, sort || line mpg weight if !foreign, sort title("Two lines") legend(order(1 "Foreign" 2 "Domestic")) name(c4, replace) nodraw
graph combine c1 c2 c3 c4, title("Four graphs combined") `SZ'
shotA 12_combine
local o scheme(pypolish) nodraw
scatter mpg weight, `o' mcolor("11 93 122%85") mlcolor(white) mlwidth(vthin) title("Mileage and weight", size(10pt)) xtitle("Weight (lbs.)") ytitle("") name(c1, replace)
graph bar (mean) mpg, over(rep78) `o' title("Mileage by repair record", size(10pt)) ytitle("") name(c2, replace)
histogram price, `o' title("Price", size(10pt)) xtitle("") ytitle("") name(c3, replace)
line mpg weight if foreign, sort || line mpg weight if !foreign, sort `o' title("Foreign and domestic", size(10pt)) ///
    legend(order(1 "Foreign" 2 "Domestic") rows(1) position(11) region(lstyle(none))) xtitle("Weight (lbs.)") ytitle("") name(c4, replace)
graph combine c1 c2 c3 c4, scheme(pypolish) `SZ' title("Four views of the 1978 automobile data", `TS') note("Source: Stata auto dataset.", `NS')
gpolish
shotBC 12_combine

di as res "gallery done"
