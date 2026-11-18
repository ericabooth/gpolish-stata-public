* Label-placement benchmark, Stata side.
* Draws every scenario three ways and records where the labels landed:
*   default   Stata's own marker labels, mlabel() at position 3
*   gpolish   gpolish ptlabel (this package)
*   labrepel  labrepel from Asjad Naqvi's graphfunctions (SSC), labels drawn at _xcoord/_ycoord
*             with leader lines back to their points
* Run from the benchmark folder after make_synthetic.py:
*   stata-mp -b do run_stata.do
* labrepel must be installed (ssc install graphfunctions); if the environment variable
* BENCH_PLUS names another ado folder, it is added to the end of the ado path to find it.
* The gpolish under test is always this package's src folder, which is put first on the ado
* path; the run stops if another copy of gpolish would be used.
version 16
set more off
clear all
local src "`c(pwd)'/../src"
adopath ++ "`src'"
local bp : environment BENCH_PLUS
if `"`bp'"' != "" adopath + `"`bp'"'
quietly findfile gpolish.ado
if `"`r(fn)'"' != `"`src'/gpolish.ado"' {
    di as err `"gpolish.ado resolves to `r(fn)', not to this package's src folder"'
    exit 498
}
which gpolish
graph set svg fontface "Open Sans"
graph set window fontface "Open Sans"
capture mkdir "out"
capture mkdir "out/stata"

* ---------------------------------------------------------------- real-data scenarios
tempname mf
file open `mf' using "data/manifest_real.csv", write text replace
file write `mf' "scenario,design,seed,n,nlab,fit,fa,fb,fx0,fx1" _n
sysuse lifeexp, clear
drop if missing(gnppc, lexp)
gen double x = ln(gnppc)
gen double y = lexp
gen label = country
quietly regress y x
local fa = _b[_cons]
local fb = _b[x]
quietly summarize x
local fx0 = r(min)
local fx1 = r(max)
gen byte lab = inlist(country, "Haiti", "United States", "Switzerland", "Bolivia", "Russian Federation", "Moldova") ///
    | inlist(country, "Armenia", "Brazil", "Kazakhstan", "Canada", "Guatemala", "Denmark")
export delimited x y label lab using "data/life12.csv", replace
quietly count if lab
file write `mf' "life12,life12,0,`=_N',`r(N)',1,`fa',`fb',`fx0',`fx1'" _n
replace lab = 1
export delimited x y label lab using "data/lifeall.csv", replace
file write `mf' "lifeall,lifeall,0,`=_N',`=_N',1,`fa',`fb',`fx0',`fx1'" _n
sysuse auto, clear
gen double x = weight
gen double y = mpg
gen label = make
quietly regress y x
local fa = _b[_cons]
local fb = _b[x]
quietly summarize x
local fx0 = r(min)
local fx1 = r(max)
sort weight make
gen byte lab = mod(_n, 4) == 1
export delimited x y label lab using "data/autosub.csv", replace
quietly count if lab
file write `mf' "autosub,autosub,0,`=_N',`r(N)',1,`fa',`fb',`fx0',`fx1'" _n
replace lab = 1
export delimited x y label lab using "data/autoall.csv", replace
file write `mf' "autoall,autoall,0,`=_N',`=_N',1,`fa',`fb',`fx0',`fx1'" _n
file close `mf'

* ---------------------------------------------------------------- scenario list
import delimited using "data/manifest_real.csv", clear varnames(1) stringcols(1 2)
tempfile real
save `real'
import delimited using "data/manifest_synthetic.csv", clear varnames(1) stringcols(1 2)
append using `real'
* BENCH_SCENARIOS limits the run to some scenarios, e.g. "life12 syn60all_s01 syn60all_s02"
local only_s : environment BENCH_SCENARIOS
if `"`only_s'"' != "" {
    gen byte keep_s = 0
    foreach s of local only_s {
        quietly replace keep_s = 1 if scenario == "`s'"
    }
    quietly keep if keep_s
    drop keep_s
}
local N = _N
forvalues r = 1/`N' {
    local scen`r' = scenario[`r']
    local fit`r' = fit[`r']
    local fa`r' = fa[`r']
    local fb`r' = fb[`r']
    local fx0`r' = fx0[`r']
    local fx1`r' = fx1[`r']
    local png`r' = (seed[`r'] <= 1)
}

capture which labrepel
local methods default gpolish
if !_rc local methods `methods' labrepel
else di as txt "note: labrepel is not installed; that method is skipped"
* BENCH_METHODS limits the run to some methods, e.g. "gpolish"
local only : environment BENCH_METHODS
if `"`only'"' != "" local methods `only'

tempname gf
foreach method of local methods {
    file open `gf' using "out/stata/geometry_`method'.csv", write text replace
    file write `gf' "scenario,method,W,H,px0,py0,px1,py1,xA,xB,yA,yB,seconds,rc" _n
    forvalues r = 1/`N' {
        local scen `scen`r''
        import delimited using "data/`scen'.csv", clear varnames(1) stringcols(3) encoding("utf-8")
        local fitlayer
        if `fit`r'' == 1 local fitlayer (function y = `fa`r'' + `fb`r''*x, range(`fx0`r'' `fx1`r'') lcolor(gs9) lwidth(medium))
        local base scheme(pypolish) legend(off) xsize(7) ysize(4.6) xtitle("") ytitle("") ///
            xlabel(, labsize(8pt)) ylabel(, labsize(8pt)) name(g, replace)
        local pts (scatter y x, msymbol(O) msize(6pt) mcolor("11 93 122%70") mlcolor(white) mlwidth(vthin)
        local secs 0
        local rc 0
        timer clear 1
        if "`method'" == "default" {
            gen lshow = cond(lab == 1, label, "")
            twoway `fitlayer' `pts' mlabel(lshow) mlabsize(8.6pt) mlabposition(3) mlabcolor(black)), `base'
        }
        else if "`method'" == "gpolish" {
            twoway `fitlayer' `pts'), `base'
            timer on 1
            capture noisily gpolish ptlabel label if lab == 1, x(x) y(y) size(8.6) msize(6) color("0 0 0")
            local rc = _rc
            timer off 1
        }
        else {
            * labrepel 1.0 accepts seed() but does not apply it; its random jitter draws from the
            * session's random-number stream. Setting the seed here makes each graph's result the
            * same whichever scenarios ran before it.
            set seed 12345
            timer on 1
            capture noisily labrepel y x if lab == 1, label(label) mlabsize(2.6) xsize(7) ysize(4.6) seed(12345)
            local rc = _rc
            timer off 1
            if `rc' == 0 {
                twoway `fitlayer' (pcspike y x _ycoord _xcoord if lab == 1, lcolor(gs10) lwidth(vthin)) ///
                    `pts') (scatter _ycoord _xcoord if lab == 1, msymbol(none) mlabel(label) ///
                    mlabposition(0) mlabsize(8.6pt) mlabcolor(black)), `base'
            }
            else twoway `fitlayer' `pts'), `base'
        }
        if "`method'" != "default" {
            quietly timer list 1
            local secs = r(t1)
        }
        graph export "out/stata/`scen'__`method'.svg", replace
        if `png`r'' graph export "out/stata/`scen'__`method'.png", replace width(1400)
        * plot geometry in points (y up): x_pt = xA + xB*x, y_pt = yA + yB*y
        local W = 7*72
        local H = 4.6*72
        local G1x = `.g.gdi_x1'
        local G1y = `.g.gdi_y1'
        local pr .g.plotregion1
        local xA = ``pr'.drawn_xalpha'/`G1x'*`W'
        local xB = ``pr'.drawn_xbeta'/`G1x'*`W'
        local yA = ``pr'.drawn_yalpha'/`G1y'*`H'
        local yB = ``pr'.drawn_ybeta'/`G1y'*`H'
        local px0 = min(``pr'.gdi_x0', ``pr'.gdi_x1')/`G1x'*`W'
        local px1 = max(``pr'.gdi_x0', ``pr'.gdi_x1')/`G1x'*`W'
        local py0 = min(``pr'.gdi_y0', ``pr'.gdi_y1')/`G1y'*`H'
        local py1 = max(``pr'.gdi_y0', ``pr'.gdi_y1')/`G1y'*`H'
        file write `gf' "`scen',`method',`W',`H',`px0',`py0',`px1',`py1',`xA',`xB',`yA',`yB',`secs',`rc'" _n
    }
    file close `gf'
}
di as res "stata benchmark done"
