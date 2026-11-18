* Tuning run for gpolish ptlabel: draws every tuning scenario with one candidate setting.
* Called by tune.py; the folder in TUNE_DIR holds a copy of gpolish.ado with that setting.
* Uses only data/manifest_tuning.csv (tuning seeds), never the test scenarios.
version 16
set more off
clear all
local dir : environment TUNE_DIR
adopath ++ "`c(pwd)'/../src"
adopath ++ "`dir'"
* the candidate copy in TUNE_DIR must be the gpolish that runs
quietly findfile gpolish.ado
if `"`r(fn)'"' != `"`dir'/gpolish.ado"' {
    di as err `"gpolish.ado resolves to `r(fn)', not to the candidate in `dir'"'
    exit 498
}
graph set svg fontface "Open Sans"
graph set window fontface "Open Sans"
tempname gf
file open `gf' using "`dir'/geometry_gpolish.csv", write text replace
file write `gf' "scenario,method,W,H,px0,py0,px1,py1,xA,xB,yA,yB,seconds,rc" _n
import delimited using "data/manifest_tuning.csv", clear varnames(1) stringcols(1 2)
local N = _N
forvalues r = 1/`N' {
    local scen`r' = scenario[`r']
}
forvalues r = 1/`N' {
    local scen `scen`r''
    import delimited using "data/`scen'.csv", clear varnames(1) stringcols(3) encoding("utf-8")
    twoway (scatter y x, msymbol(O) msize(6pt) mcolor("11 93 122%70") mlcolor(white) mlwidth(vthin)), ///
        scheme(pypolish) legend(off) xsize(7) ysize(4.6) xtitle("") ytitle("") ///
        xlabel(, labsize(8pt)) ylabel(, labsize(8pt)) name(g, replace)
    timer clear 1
    timer on 1
    gpolish ptlabel label if lab == 1, x(x) y(y) size(8.6) msize(6) color("0 0 0")
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    graph export "`dir'/`scen'__gpolish.svg", replace
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
    file write `gf' "`scen',gpolish,`W',`H',`px0',`py0',`px1',`py1',`xA',`xB',`yA',`yB',`secs',0" _n
}
file close `gf'
