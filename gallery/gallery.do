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
    if "$GALLERY_FIDELITY" != "" exit
    graph export "gallery/img/`tag'_a.png", replace width(1400)
end
capture program drop shotBC
program shotBC
    args tag opts
    if "$GALLERY_FIDELITY" != "" {
        * fidelity.do: Stata's SVG plus gr2mpl's spec folder, no gallery images
        graph export "$GALLERY_FIDELITY/`tag'.svg", replace
        capture noisily gr2mpl, saving("$GALLERY_FIDELITY/`tag'_c.png") replace width(1400) ///
            keepspec specdir("$GALLERY_FIDELITY/`tag'") `opts'
        if _rc di as err "gr2mpl could not draw `tag'"
        exit
    }
    graph export "gallery/img/`tag'_b.png", replace width(1400)
    capture noisily gr2mpl, saving("gallery/img/`tag'_c.png") replace width(1400) `opts'
    if _rc di as err "gr2mpl could not draw `tag'"
end
* options shared by every polished version
local SZ xsize(7) ysize(4.6)
local TS size(13.5pt)
local SS size(10pt)
local NS size(8pt)
local LS labsize(9pt)

* ---------------------------------------------------------------- 01 added-variable plot after regress
sysuse auto, clear
quietly regress price mpg weight foreign
avplot weight, title("Added-variable plot") `SZ'
shotA 01_avplot
local b = strtrim("`: display %4.2f _b[weight]'")
avplot weight, scheme(pypolish) `SZ' mcolor("11 93 122%85") mlcolor(white) mlwidth(vthin) msize(6pt) ///
    rlopts(lcolor("184 67 15") lwidth(medthick)) note("Source: Stata auto dataset. Linear regression of price on mileage, weight and origin.", `NS') ///
    title("Holding mileage and origin fixed, heavier cars cost more", `TS') ///
    subtitle("Added-variable plot: price and weight, both net of the other regressors", `SS') ///
    xtitle("Weight, residualized (lbs.)", size(9pt)) ytitle("") xlabel(, `LS' format(%9.0fc)) ylabel(, `LS' format(%9.0fc))
gpolish
gpolish note "{bf:`b' dollars per pound}" "after adjusting for mileage" "and foreign origin", at(-850 4600)
shotBC 01_avplot

* ---------------------------------------------------------------- 02 correlation heatmap from twoway tiles
sysuse auto, clear
local vars price mpg weight length displacement gear_ratio headroom turn
local labs `""Price" "Mileage" "Weight" "Length" "Displacement" "Gear ratio" "Headroom" "Turn circle""'
quietly correlate `vars'
matrix C = r(C)
clear
set obs 64
gen i = ceil(_n/8)
gen j = _n - 8*(i-1)
gen r = C[i, j]
gen y0 = j - 0.5
gen y1 = j + 0.5
gen str5 rtxt = strtrim(string(r, "%4.2f"))
gen bin = 1 + (r > -0.6) + (r > -0.2) + (r > 0.2) + (r > 0.6)
local al
forvalues k = 1/8 {
    local al `al' `k' `"`: word `k' of `labs''"'
}
twoway (scatter j i [aweight=abs(r)], msymbol(S)) (scatter j i, msymbol(none) mlabel(rtxt) mlabpos(0)), ///
    xlabel(`al', angle(45)) ylabel(`al', angle(0)) yscale(reverse) legend(off) title("Correlations") `SZ'
shotA 02_heatmap
local c1 "184 67 15"
local c2 "240 163 94"
local c3 "240 240 236"
local c4 "111 177 199"
local c5 "11 93 122"
local layers
forvalues k = 1/5 {
    local layers `layers' (rbar y0 y1 i if bin==`k', barwidth(1) color("`c`k''") lcolor(white) lwidth(vthin))
}
twoway `layers' ///
       (scatter j i if inlist(bin, 2, 3, 4), msymbol(none) mlabel(rtxt) mlabpos(0) mlabsize(8pt) mlabcolor("26 26 26")) ///
       (scatter j i if inlist(bin, 1, 5), msymbol(none) mlabel(rtxt) mlabpos(0) mlabsize(8pt) mlabcolor(white)) ///
    , scheme(pypolish) `SZ' yscale(reverse) xlabel(`al', labsize(8pt) angle(35) nogrid) ylabel(`al', labsize(8pt) nogrid) ///
    xtitle("") ytitle("") xscale(noline) plotregion(margin(zero)) ///
    title("Bigger cars cost more and travel less far on a gallon", `TS') ///
    subtitle("Pairwise correlations, 74 cars", `SS') note("Source: Stata auto dataset.", `NS') ///
    legend(order(1 "Below -0.6" 2 "-0.6 to -0.2" 3 "-0.2 to 0.2" 4 "0.2 to 0.6" 5 "Above 0.6") rows(1) position(11) span ///
           size(8.5pt) region(lstyle(none) margin(zero)) symxsize(*.35) keygap(*.5) colgap(*1.6) bmargin(b+1))
gpolish
shotBC 02_heatmap

* ---------------------------------------------------------------- 03 coefplot with shaded confidence bands
capture which coefplot
if !_rc {
    sysuse nlsw88, clear
    gen expcat = min(floor(ttl_exp/3), 7)
    forvalues g = 0/1 {
        quietly regress wage ib0.expcat i.race i.collgrad i.union if south==`g'
        estimates store m`g'
    }
    local cl 1.expcat="3-5" 2.expcat="6-8" 3.expcat="9-11" 4.expcat="12-14" 5.expcat="15-17" 6.expcat="18-20" 7.expcat="21+"
    coefplot (m0, label("Outside the South")) (m1, label("South")), keep(*.expcat) vertical coeflabels(`cl') yline(0) ///
        title("Wage gain by experience") `SZ'
    shotA 03_coefplot
    local a "11 93 122"
    local b "184 67 15"
    coefplot (m0, lcolor("`a'") ciopts(recast(rarea rarea rarea) fcolor("`a'%12" "`a'%20" "`a'%30") lwidth(none none none))) ///
             (m1, lcolor("`b'") ciopts(recast(rarea rarea rarea) fcolor("`b'%12" "`b'%20" "`b'%30") lwidth(none none none))) ///
        , keep(*.expcat) vertical recast(line) lwidth(medthick) levels(95 80 50) nooffsets coeflabels(`cl') ///
        yline(0, lcolor("120 120 120") lwidth(thin)) scheme(pypolish) legend(off) `SZ' ///
        title("Experience pays in both regions, and pays less in the South", `TS') ///
        subtitle("Hourly wage gain over women with under three years of experience (1988 dollars)", `SS') ///
        note("Source: NLSW 1988 extract. Separate regressions with race, degree and union controls." "Bands: 50, 80 and 95% confidence intervals. Drawn with coefplot.", `NS') ///
        xtitle("Years of work experience", size(9pt)) ytitle("") xlabel(, `LS') ylabel(, `LS')
    gpolish
    gpolish endlabel, values dots labels("Outside the South" "South") format(%4.2f)
    gpolish note "{bf:Shaded bands}" "darker = narrower interval" "(50, 80, 95 percent)", at(0.75 5.3) size(8.2)
    shotBC 03_coefplot
}
* ---------------------------------------------------------------- 04 lines
sysuse uslifeexp, clear
label var le_wfemale "White women"
label var le_wmale   "White men"
label var le_bfemale "Black women"
label var le_bmale   "Black men"
line le_wfemale le_wmale le_bfemale le_bmale year, title("Life expectancy at birth") `SZ'
shotA 04_lines
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
shotBC 04_lines

* ---------------------------------------------------------------- 05 labelled scatter
sysuse lifeexp, clear
drop if missing(gnppc, lexp)
gen lngnp = ln(gnppc)
quietly regress lexp lngnp
local a = _b[_cons]
local b = _b[lngnp]
twoway (scatter lexp gnppc if region==1) (scatter lexp gnppc if region==2) (scatter lexp gnppc if region==3), ///
    xscale(log) legend(order(1 "Europe & C. Asia" 2 "North America" 3 "South America")) ///
    title("Life expectancy and GNP per capita") `SZ'
shotA 05_scatter
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
shotBC 05_scatter

* ---------------------------------------------------------------- 06 marginsplot
sysuse nlsw88, clear
quietly regress wage c.ttl_exp##i.collgrad i.race
quietly margins collgrad, at(ttl_exp=(0(4)28))
marginsplot, `SZ'
shotA 06_margins
marginsplot, scheme(pypolish) recast(line) recastci(rarea) ciopts(color(%18) lwidth(none)) legend(off) `SZ' ///
    title("College graduates start higher and pull away with experience", `TS') ///
    subtitle("Predicted hourly wage (1988 dollars) by total work experience", `SS') ///
    note("Source: NLSW 1988 extract. Linear model with race controls; bands are 95% confidence intervals.", `NS') ///
    xtitle("Years of work experience", size(9pt)) ytitle("") xlabel(, `LS') ylabel(, `LS')
gpolish
gpolish endlabel, values format(%4.2f) dots labels("Not a college graduate" "College graduate") wrap(16)
shotBC 06_margins

* ---------------------------------------------------------------- 07 one series highlighted
sysuse uslifeexp, clear
label var le_bfemale "Black women"
line le_wmale le_wfemale le_bmale le_male le_female le le_bfemale year if year>=1950, title("Life expectancy, 1950-1999") `SZ'
shotA 07_highlight
local g "205 205 205"
line le_wmale le_wfemale le_bmale le_male le_female le le_bfemale year if year>=1950, scheme(pypolish) legend(off) `SZ' ///
    lcolor("`g'" "`g'" "`g'" "`g'" "`g'" "`g'" "184 67 15") lwidth(medium medium medium medium medium medium thick) ///
    title("Black women gained the most after 1950", `TS') ///
    subtitle("Life expectancy at birth, years; other groups in gray", `SS') ///
    note("Source: National Vital Statistics Reports, Vol. 50, No. 6.", `NS') ///
    xtitle("") ytitle("") xlabel(1950(10)1990 1999, `LS') ylabel(, `LS')
gpolish
gpolish endlabel, plots(7) values dots
shotBC 07_highlight

* ---------------------------------------------------------------- 08 finding box, brace and callout
sysuse auto, clear
quietly regress mpg weight
local slope = strtrim("`: display %3.1f -1000*_b[weight]'")
twoway (scatter mpg weight) (lfit mpg weight), title("Mileage and weight") `SZ'
shotA 08_overlays
twoway (lfit mpg weight, lcolor("60 60 60") lwidth(medium)) ///
       (scatter mpg weight, mcolor("11 93 122%85") mlcolor(white) mlwidth(vthin) msize(6pt)) ///
    , scheme(pypolish) legend(off) `SZ' title("Weight explains most of the difference in mileage", `TS') ///
    subtitle("Mileage (mpg) and weight (lbs.), 74 cars, 1978", `SS') note("Source: Stata auto dataset.", `NS') ///
    xtitle("Weight (lbs.)", size(9pt)) ytitle("") xlabel(, `LS' format(%9.0fc)) ylabel(, `LS') yscale(range(8 42))
gpolish
gpolish note "{bf:Finding}" "Each extra 1,000 lbs. costs" "about `slope' miles per gallon", at(3350 34)
gpolish brace "Every car over 4,000 lbs." "gets under 22 mpg", from(3980 23) to(4860 23)
gpolish callout "VW Diesel: 41 mpg", to(2040 41)
shotBC 08_overlays

* ---------------------------------------------------------------- 09 group means with CI braces
sysuse nlsw88, clear
drop if missing(union)
collapse (mean) m=wage (semean) se=wage (count) n=wage, by(union)
gen lo = m - invttail(n-1, 0.025)*se
gen hi = m + invttail(n-1, 0.025)*se
gen x = union + 1
twoway (bar m x) (rcap lo hi x), xlabel(1 "Nonunion" 2 "Union") title("Mean wage by union status") `SZ'
shotA 09_cibrace
local m1 = m[1]
local m2 = m[2]
local lo2 = lo[2]
local hi2 = hi[2]
local gap = strtrim("`: display %4.2f `m2'-`m1''")
twoway (bar m x if x==1, barwidth(0.55) color("111 177 199")) (bar m x if x==2, barwidth(0.55) color("11 93 122")) ///
       (rcap lo hi x, lcolor("26 26 26") lwidth(medium)) ///
    , scheme(pypolish) legend(off) `SZ' xlabel(1 "Nonunion" 2 "Union", `LS') xscale(range(0.4 3.3)) ///
    ylabel(0(2)10, `LS') yscale(range(0 10)) xtitle("") ytitle("") ///
    title("Union members earned about a dollar more an hour", `TS') ///
    subtitle("Mean hourly wage (1988 dollars), with 95% confidence intervals", `SS') note("Source: NLSW 1988 extract.", `NS')
gpolish
gpolish brace "95% confidence" "interval", from(2.33 `lo2') to(2.33 `hi2') flip width(5)
gpolish brace "{bf:`gap' dollars}", from(1.5 `m1') to(1.5 `m2') width(5) color("184 67 15") lcolor("184 67 15")
shotBC 09_cibrace

* ---------------------------------------------------------------- 10 flow chart of sample restrictions
sysuse nlsw88, clear
local n0 = _N
quietly count if missing(union)
local d1 = r(N)
drop if missing(union)
local n1 = _N
quietly count if missing(tenure, hours)
local d2 = r(N)
drop if missing(tenure, hours)
local n2 = _N
quietly count if hours < 35
local d3 = r(N)
drop if hours < 35
local n3 = _N
foreach k in n0 n1 n2 n3 d1 d2 d3 {
    local `k' = strtrim(string(``k'', "%9.0fc"))
}
clear
set obs 2
gen x = cond(_n==1, 0, 100)
gen y = x
scatter y x, msymbol(none) xscale(off) yscale(off) xlabel(, nogrid) ylabel(, nogrid) title("Sample restrictions") ///
    text(90 35 "Women in the extract: `n0'", box) text(64 35 "Union status known: `n1'", box) ///
    text(38 35 "Tenure and hours known: `n2'", box) text(12 35 "Working full time: `n3'", box) `SZ'
shotA 10_flow
scatter y x, msymbol(none) scheme(pypolish) xscale(off range(0 100)) yscale(off range(0 100)) ///
    xlabel(, nogrid) ylabel(, nogrid) `SZ' plotregion(margin(zero)) ///
    title("From the full extract to the estimation sample", `TS') ///
    subtitle("National Longitudinal Survey of Women, 1988 extract", `SS') note("Source: NLSW 1988 extract.", `NS')
gpolish, keepyline keepyticks
local main fill("232 241 245") border("11 93 122") align(center) size(9.5) pad(7)
local drop fill("253 243 220") border("224 161 0") align(center) size(8.8) pad(6)
gpolish note "{bf:`n0'}" "women in the extract", at(35 90) `main'
gpolish note "{bf:`n1'}" "union status known", at(35 64) `main'
gpolish note "{bf:`n2'}" "tenure and hours known", at(35 38) `main'
gpolish note "{bf:`n3'}" "working 35 hours or more" "(estimation sample)", at(35 10) `main'
gpolish note "`d1' dropped:" "union status missing", at(76 77) `drop'
gpolish note "`d2' dropped:" "tenure or hours missing", at(76 51) `drop'
gpolish note "`d3' dropped:" "part-time workers", at(76 25) `drop'
gpolish arrow, from(35 83) to(35 71)
gpolish arrow, from(35 57) to(35 45)
gpolish arrow, from(35 31) to(35 19)
gpolish arrow, from(35 77) to(64.5 77) headsize(3.5)
gpolish arrow, from(35 51) to(63 51) headsize(3.5)
gpolish arrow, from(35 25) to(65.5 25) headsize(3.5)
shotBC 10_flow

* ---------------------------------------------------------------- 11 scatter with fit and band
sysuse auto, clear
twoway (lfitci mpg weight) (scatter mpg weight), title("Mileage and weight") `SZ'
shotA 11_fitci
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
shotBC 11_fitci

* ---------------------------------------------------------------- 12 daily time series
sysuse sp500, clear
line close date, title("S&P 500, 2001") `SZ'
shotA 12_timeseries
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
shotBC 12_timeseries

* ---------------------------------------------------------------- 13 coefficient plot built from twoway
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
shotA 13_coef
twoway (rcap lo hi k, horizontal lcolor("11 93 122") lwidth(medthick) msize(zero)) ///
       (scatter k b, mcolor("11 93 122") mlcolor(white) mlwidth(vthin) msize(7pt)) ///
    , scheme(pypolish) legend(off) `SZ' ylabel(`yl', `LS' nogrid) yscale(range(0.5 6.5)) ///
    xline(0, lcolor("120 120 120") lwidth(thin)) xlabel(, `LS' grid glcolor("228 228 228") glwidth(thin)) ///
    title("A college degree is worth about three dollars an hour", `TS') ///
    subtitle("Change in hourly wage (1988 dollars), with 95% confidence intervals", `SS') ///
    note("Source: NLSW 1988 extract. Linear regression of hourly wage; N = 2,231.", `NS') xtitle("") ytitle("")
gpolish
shotBC 13_coef

* ---------------------------------------------------------------- 14 histogram
sysuse nlsw88, clear
histogram wage, title("Hourly wage") `SZ'
shotA 14_histogram
quietly summarize wage, detail
local med = r(p50)
histogram wage, scheme(pypolish) width(1) start(0) frequency `SZ' ///
    title("Most women earned under ten dollars an hour", `TS') ///
    subtitle("Number of women by hourly wage (1988 dollars), one-dollar bins", `SS') ///
    note("Source: NLSW 1988 extract.", `NS') xtitle("") ytitle("") xlabel(0(5)40, `LS') ylabel(, `LS')
gpolish
gpolish callout "Median wage:" "`: display %4.2f `med'' dollars", at(12 285) to(`med' 318) curve(0.2)
shotBC 14_histogram

* ---------------------------------------------------------------- 15 ranked horizontal bars
* graph bar is not a twoway graph: the scheme applies and gpolish bolds the title,
* but the layout commands (endlabel, callout, ptlabel) are twoway only. gr2mpl redraws it.
sysuse nlsw88, clear
graph hbar (mean) wage, over(industry, sort(1) descending) title("Mean wage by industry") `SZ'
shotA 15_hbar
graph hbar (mean) wage, over(industry, sort(1) descending label(`LS')) scheme(pypolish) `SZ' ///
    title("Mining and utilities pay the most", `TS') subtitle("Mean hourly wage (1988 dollars) by industry", `SS') ///
    note("Source: NLSW 1988 extract.", `NS') ytitle("") ylabel(, `LS')
gpolish
shotBC 15_hbar

* ---------------------------------------------------------------- 16 box plot
graph box wage, over(race) title("Hourly wage by race") `SZ'
shotA 16_box
graph box wage, over(race, label(`LS')) scheme(pypolish) `SZ' ///
    title("Wage distributions overlap far more than their means suggest", `TS') ///
    subtitle("Hourly wage (1988 dollars) by race", `SS') note("Source: NLSW 1988 extract.", `NS') ///
    ytitle("") ylabel(, `LS')
gpolish
shotBC 16_box

* ---------------------------------------------------------------- 17 small multiples with by()
preserve
keep if inlist(industry, 4, 6, 7, 11, 12) & inrange(age, 34, 45)
collapse (mean) wage, by(age industry)
line wage age, by(industry, title("Mean wage by age")) xsize(7) ysize(4.6)
shotA 17_by
line wage age, scheme(pypolish) lcolor("11 93 122") xtitle("Age", size(9pt)) ytitle("") xlabel(, `LS') ylabel(, `LS') ///
    by(industry, title("Wages are flat across the late thirties and early forties", `TS') ///
       subtitle("Mean hourly wage (1988 dollars) by age, five industries", `SS') ///
       note("Source: NLSW 1988 extract.", `NS')) xsize(7) ysize(4.6)
gpolish
shotBC 17_by
restore

* ---------------------------------------------------------------- 18 combined panels
sysuse auto, clear
scatter mpg weight, title("Mileage and weight") name(c1, replace) nodraw
graph bar (mean) mpg, over(rep78) title("Mileage by repair record") name(c2, replace) nodraw
histogram price, title("Price") name(c3, replace) nodraw
line mpg weight if foreign, sort || line mpg weight if !foreign, sort title("Two lines") legend(order(1 "Foreign" 2 "Domestic")) name(c4, replace) nodraw
graph combine c1 c2 c3 c4, title("Four graphs combined") `SZ'
shotA 18_combine
local o scheme(pypolish) nodraw
scatter mpg weight, `o' mcolor("11 93 122%85") mlcolor(white) mlwidth(vthin) title("Mileage and weight", size(10pt)) xtitle("Weight (lbs.)") ytitle("") name(c1, replace)
graph bar (mean) mpg, over(rep78) `o' title("Mileage by repair record", size(10pt)) ytitle("") name(c2, replace)
histogram price, `o' title("Price", size(10pt)) xtitle("") ytitle("") name(c3, replace)
line mpg weight if foreign, sort || line mpg weight if !foreign, sort `o' title("Foreign and domestic", size(10pt)) ///
    legend(order(1 "Foreign" 2 "Domestic") rows(1) position(11) region(lstyle(none))) xtitle("Weight (lbs.)") ytitle("") name(c4, replace)
graph combine c1 c2 c3 c4, scheme(pypolish) `SZ' title("Four views of the 1978 automobile data", `TS') note("Source: Stata auto dataset.", `NS')
gpolish
shotBC 18_combine

* ---------------------------------------------------------------- 19 scatterplot matrix
sysuse auto, clear
graph matrix price mpg weight length, half title("Scatterplot matrix") `SZ'
shotA 19_matrix
graph matrix price mpg weight length, half scheme(pypolish) `SZ' mcolor("11 93 122%70") msize(3.5pt) ///
    title("Four measures of a car, two at a time", `TS') subtitle("Price, mileage, weight and length, 74 cars", `SS') ///
    note("Source: Stata auto dataset.", `NS')
gpolish
shotBC 19_matrix

* ---------------------------------------------------------------- 20 cluster dendrogram
sysuse auto, clear
keep if foreign
foreach v of varlist price mpg weight length {
    quietly summarize `v'
    gen z_`v' = (`v' - r(mean))/r(sd)
}
cluster wardslinkage z_price z_mpg z_weight z_length, name(w)
cluster dendrogram w, labels(make) xlabel(, angle(90) labsize(small)) title("Dendrogram") `SZ'
shotA 20_dendrogram
cluster dendrogram w, labels(make) horizontal scheme(pypolish) `SZ' lcolor("11 93 122") lwidth(medium) ///
    ylabel(, labsize(8pt) nogrid) xlabel(, `LS' grid glcolor("228 228 228") glwidth(thin)) xtitle("Dissimilarity (Ward's linkage)", size(9pt)) ytitle("") ///
    title("The imported cars fall into three families", `TS') ///
    subtitle("Hierarchical clustering on price, mileage, weight and length (standardized)", `SS') ///
    note("Source: Stata auto dataset, 22 foreign cars.", `NS')
gpolish
shotBC 20_dendrogram

* ---------------------------------------------------------------- 21 statplot (community command)
capture which statplot
if !_rc {
    sysuse nlsw88, clear
    statplot wage hours tenure, over(collgrad) title("Means by college degree") `SZ'
    shotA 21_statplot
    statplot wage hours tenure, over(collgrad) scheme(pypolish) `SZ' ///
        title("College graduates earn more for similar hours and tenure", `TS') ///
        subtitle("Means of hourly wage, weekly hours and job tenure (years)", `SS') note("Source: NLSW 1988 extract. Drawn with statplot.", `NS') ytitle("")
    gpolish
    shotBC 21_statplot
}

* ---------------------------------------------------------------- 22 heatplot (community command)
capture which heatplot
if !_rc {
    sysuse nlsw88, clear
    heatplot wage tenure, title("Wage and tenure") `SZ'
    shotA 22_heatplot
    heatplot wage tenure if wage < 25, scheme(pypolish) `SZ' color(viridis, reverse) levels(8) ///
        legend(position(3) cols(1) rows(8) region(lstyle(none)) size(8pt)) ///
        title("Most women had short tenure and modest pay", `TS') subtitle("Share of women by hourly wage and job tenure", `SS') ///
        note("Source: NLSW 1988 extract. Drawn with heatplot.", `NS') xtitle("Job tenure (years)", size(9pt)) ytitle("") ///
        xlabel(, `LS') ylabel(, `LS')
    gpolish
    shotBC 22_heatplot
}

di as res "gallery done"
