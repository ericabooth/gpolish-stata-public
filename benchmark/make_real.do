* Label-placement benchmark: the real-data scenarios.
* Writes data/<scenario>.csv (x, y, label, lab) for the four real-data scenarios of the main set
* and data/manifest_real.csv; then, for the perm set, the same four scenarios with their rows in
* 10 random orders (permutation seeds 1 to 10): data/<scenario>_p01.csv to _p10.csv and
* data/manifest_perm.csv. Draws no graphs and changes no settings.
* Run from the benchmark folder:  stata-mp -b do make_real.do
version 16
set more off
clear all
capture mkdir "data"
tempname mf
file open `mf' using "data/manifest_real.csv", write text replace
file write `mf' "scenario,set,design,seed,n,nlab,fit,fa,fb,fx0,fx1,label_pt,marker_pt" _n
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
local fit_life `fa',`fb',`fx0',`fx1'
file write `mf' "life12,main,life12,0,`=_N',`r(N)',1,`fit_life',8.6,6.0" _n
replace lab = 1
export delimited x y label lab using "data/lifeall.csv", replace
file write `mf' "lifeall,main,lifeall,0,`=_N',`=_N',1,`fit_life',8.6,6.0" _n
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
local fit_auto `fa',`fb',`fx0',`fx1'
file write `mf' "autosub,main,autosub,0,`=_N',`r(N)',1,`fit_auto',8.6,6.0" _n
replace lab = 1
export delimited x y label lab using "data/autoall.csv", replace
file write `mf' "autoall,main,autoall,0,`=_N',`=_N',1,`fit_auto',8.6,6.0" _n
file close `mf'

* ---------------------------------------------------------------- perm set: 10 random row orders
file open `mf' using "data/manifest_perm.csv", write text replace
file write `mf' "scenario,set,design,seed,n,nlab,fit,fa,fb,fx0,fx1,label_pt,marker_pt" _n
foreach scen in life12 lifeall autosub autoall {
    local fit `fit_life'
    if substr("`scen'", 1, 4) == "auto" local fit `fit_auto'
    forvalues p = 1/10 {
        import delimited using "data/`scen'.csv", clear varnames(1) stringcols(3) encoding("utf-8") asdouble
        set seed `p'
        gen double u = runiform()
        sort u
        drop u
        local tag = string(`p', "%02.0f")
        export delimited x y label lab using "data/`scen'_p`tag'.csv", replace
        quietly count if lab
        file write `mf' "`scen'_p`tag',perm,`scen',`p',`=_N',`r(N)',1,`fit',8.6,6.0" _n
    }
}
file close `mf'
* ---------------------------------------------------------------- rule set: a rule-based subset
* the 12 countries farthest from the fitted line (largest absolute residual), a rule fixed before running.
* Written only for extra.py (BENCH_EXTRA=1), so the main run never draws it.
local extra : environment BENCH_EXTRA
if "`extra'" == "" {
    di as res "real-data scenarios written"
    exit
}
file open `mf' using "data/manifest_rule.csv", write text replace
file write `mf' "scenario,set,design,seed,n,nlab,fit,fa,fb,fx0,fx1,label_pt,marker_pt" _n
import delimited using "data/lifeall.csv", clear varnames(1) stringcols(3) encoding("utf-8") asdouble
gen double ares = abs(y - (`=word(subinstr("`fit_life'", ",", " ", .), 1)' + `=word(subinstr("`fit_life'", ",", " ", .), 2)'*x))
gen long o = _n
gsort -ares
replace lab = _n <= 12
sort o
list label ares if lab, noobs
drop ares o
export delimited x y label lab using "data/liferes12.csv", replace
quietly count if lab
file write `mf' "liferes12,rule,liferes12,0,`=_N',`r(N)',1,`fit_life',8.6,6.0" _n
file close `mf'

* ---------------------------------------------------------------- realhold set: held-out real data
* Four scatterplots from Stata example datasets that were never used while gpolish was developed or
* tuned. The rule, fixed before any of them was drawn: every dataset that sysuse or webuse provides
* with 20 to 80 named units and that this benchmark had not used (census, hsng and states, all 50 US
* states), one pair of variables each with a plain relation, every unit labelled, and a fitted line;
* plus, for the first, every fourth state by x labelled (the autosub rule). webuse needs an internet
* connection. Written only for extra.py (BENCH_EXTRA=1); rhperm holds each in 10 random row orders.
file open `mf' using "data/manifest_realhold.csv", write text replace
file write `mf' "scenario,set,design,seed,n,nlab,fit,fa,fb,fx0,fx1,label_pt,marker_pt" _n
foreach scen in censall censsub hsngall statesall {
    if inlist("`scen'", "censall", "censsub") {
        sysuse census, clear
        gen double x = medage
        gen double y = 1000*death/pop
        gen label = state
    }
    else if "`scen'" == "hsngall" {
        webuse hsng, clear
        gen double x = faminc/1000
        gen double y = rent
        gen label = state
    }
    else {
        webuse states, clear
        gen double x = median_age
        gen double y = divorce_rate/100
        gen label = state
    }
    quietly regress y x
    local fa = _b[_cons]
    local fb = _b[x]
    quietly summarize x
    local fit_`scen' `fa',`fb',`r(min)',`r(max)'
    * rows stay in the dataset's own order (the "original order"); censsub picks every fourth state by x
    gen long o = _n
    sort x label
    gen byte lab = 1
    if "`scen'" == "censsub" replace lab = mod(_n, 4) == 1
    sort o
    export delimited x y label lab using "data/`scen'.csv", replace
    quietly count if lab
    file write `mf' "`scen',realhold,`scen',0,`=_N',`r(N)',1,`fit_`scen'',8.6,6.0" _n
}
file close `mf'
file open `mf' using "data/manifest_rhperm.csv", write text replace
file write `mf' "scenario,set,design,seed,n,nlab,fit,fa,fb,fx0,fx1,label_pt,marker_pt" _n
foreach scen in censall censsub hsngall statesall {
    forvalues p = 1/10 {
        import delimited using "data/`scen'.csv", clear varnames(1) stringcols(3) encoding("utf-8") asdouble
        set seed `p'
        gen double u = runiform()
        sort u
        drop u
        local tag = string(`p', "%02.0f")
        export delimited x y label lab using "data/`scen'_p`tag'.csv", replace
        quietly count if lab
        file write `mf' "`scen'_p`tag',rhperm,`scen',`p',`=_N',`r(N)',1,`fit_`scen'',8.6,6.0" _n
    }
}
file close `mf'
di as res "real-data scenarios written"
