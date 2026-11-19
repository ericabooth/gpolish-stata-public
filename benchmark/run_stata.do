* Label-placement benchmark, Stata side.
* Draws every scenario with the Stata methods and records where the labels and leader lines landed:
*   default     Stata's own marker labels, mlabel() at position 3
*   gpolish     gpolish ptlabel (this package, src folder)
*   gpolish060  gpolish ptlabel from the src folder with _gpl_placeparms() set to the hand-set
*               values of release 0.6.0 (out/gpolish060/gpolish.ado, written by make_gpolish060.py)
*   labrepel    labrepel from Asjad Naqvi's graphfunctions (SSC), labels drawn at _xcoord/_ycoord
*               with leader lines back to their points
* Run from the benchmark folder after make_real.do and make_synthetic.py:
*   stata-mp -b do run_stata.do
*   BENCH_METHODS=gpolish060 stata-mp -b do run_stata.do      (a separate run: see below)
* Environment variables:
*   BENCH_METHODS    methods to run (default: default gpolish labrepel). gpolish060 must run on its own,
*                    because one Stata session cannot hold two versions of gpolish.
*   BENCH_SETS       scenario sets to run (main perm scale fontmark holdout rule realhold rhperm; default: all
*                    whose manifest exists). The tuning set (synthetic seeds 101 to 110) runs only when named here.
*   BENCH_SCENARIOS  run only these scenarios
*   BENCH_PLUS       another ado folder, added to the end of the ado path to find labrepel
*   BENCH_SEED       the random seed set before each labrepel call (default 12345)
* Writes out/stata/<scenario>__<method>.svg, out/stata/geometry_<method>_<set>.csv and, for methods
* that draw leader lines, out/stata/leaders_<method>_<set>.csv.
* Fonts: every label is drawn in Open Sans. The run records the current graph set svg fontface (and,
* when Stata has a graph window, the window fontface), sets it to Open Sans if it is not already,
* and sets it back to the recorded value at the end, also when the run stops with an error.
* gpolish reads its text-width table from that setting; the run prints the table it used and stops
* if it is not Open Sans's. Several copies can run at once (for example one per method and set, each
* from its own small do-file that calls this one, so that each has its own log) only when the svg
* fontface is already Open Sans: otherwise one copy would set the old font back while another runs.
version 16
set more off
clear all
local src "`c(pwd)'/../src"
adopath ++ "`src'"
local bp : environment BENCH_PLUS
if `"`bp'"' != "" adopath + `"`bp'"'

capture which labrepel
local methods default gpolish
if !_rc local methods `methods' labrepel
else di as txt "note: labrepel is not installed; that method is skipped"
local only : environment BENCH_METHODS
if `"`only'"' != "" local methods `only'

* the gpolish under test: src, or the 0.6.0-settings copy for gpolish060
local want "`src'/gpolish.ado"
if strpos(" `methods' ", " gpolish060 ") {
    if strpos(" `methods' ", " gpolish ") {
        di as err "gpolish060 must be run on its own (BENCH_METHODS=gpolish060)"
        exit 198
    }
    local v "`c(pwd)'/out/gpolish060"
    capture confirm file "`v'/gpolish.ado"
    if _rc {
        di as err "out/gpolish060/gpolish.ado not found: run python make_gpolish060.py first"
        exit 601
    }
    adopath ++ "`v'"
    local want "`v'/gpolish.ado"
}
quietly findfile gpolish.ado
if `"`r(fn)'"' != `"`want'"' {
    di as err `"gpolish.ado resolves to `r(fn)', not to `want'"'
    exit 498
}
which gpolish
* a font the user set for gpolish would override the setting this run makes
global GPOLISH_FONT

capture program drop _bench_run
program _bench_run
    args methods
    capture mkdir "out"
    capture mkdir "out/stata"
    * ------------------------------------------------------------ scenario list
    tempfile all
    local first 1
    local only_set : environment BENCH_SETS
    foreach f in real synthetic perm scale fontmark holdout rule realhold rhperm tuning {
        capture confirm file "data/manifest_`f'.csv"
        if _rc continue
        * the tuning seeds are drawn only when BENCH_SETS names them (tune_others.py needs their geometry)
        if "`f'" == "tuning" & !`: list posof "tuning" in only_set' continue
        import delimited using "data/manifest_`f'.csv", clear varnames(1) stringcols(1 2 3) asdouble
        if !`first' append using `all'
        save `all', replace
        local first 0
    }
    if `first' {
        di as err "no manifests in data/: run make_real.do and make_synthetic.py first"
        exit 601
    }
    local only_set : environment BENCH_SETS
    if `"`only_set'"' != "" {
        gen byte keep_s = 0
        foreach s of local only_set {
            quietly replace keep_s = 1 if set == "`s'"
        }
        quietly keep if keep_s
        drop keep_s
    }
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
        foreach v in scenario set fit fa fb fx0 fx1 label_pt marker_pt {
            local `v'`r' = `v'[`r']
        }
        local png`r' = (seed[`r'] <= 1 & set[`r'] == "main")
    }

    tempname gf lh
    local fontshown 0
    foreach method of local methods {
        local msets main perm scale fontmark holdout rule realhold rhperm tuning
        if inlist("`method'", "labrepel", "gpolish060") local msets main perm holdout rule realhold rhperm
        local leaders = inlist("`method'", "gpolish", "gpolish060", "labrepel")
        foreach set of local msets {
            local any 0
            forvalues r = 1/`N' {
                if "`set`r''" == "`set'" local any 1
            }
            if !`any' continue
            file open `gf' using "out/stata/geometry_`method'_`set'.csv", write text replace
            file write `gf' "scenario,method,W,H,px0,py0,px1,py1,xA,xB,yA,yB,seconds,rc,font" _n
            tempfile ldta
            if `leaders' postfile `lh' str40 scenario str244 label double(x0 y0 x1 y1) using `ldta', replace
            forvalues r = 1/`N' {
                if "`set`r''" != "`set'" continue
                local scen `scenario`r''
                local lp `label_pt`r''
                local mk `marker_pt`r''
                import delimited using "data/`scen'.csv", clear varnames(1) stringcols(3) encoding("utf-8")
                local fitlayer
                if `fit`r'' == 1 local fitlayer (function y = `fa`r'' + `fb`r''*x, range(`fx0`r'' `fx1`r'') lcolor(gs9) lwidth(medium))
                local base scheme(pypolish) legend(off) xsize(7) ysize(4.6) xtitle("") ytitle("") ///
                    xlabel(, labsize(8pt)) ylabel(, labsize(8pt)) name(g, replace)
                local pts (scatter y x, msymbol(O) msize(`mk'pt) mcolor("11 93 122%70") mlcolor(white) mlwidth(vthin)
                local secs 0
                local rc 0
                local font
                timer clear 1
                if "`method'" == "default" {
                    gen lshow = cond(lab == 1, label, "")
                    twoway `fitlayer' `pts' mlabel(lshow) mlabsize(`lp'pt) mlabposition(3) mlabcolor(black)), `base'
                }
                else if inlist("`method'", "gpolish", "gpolish060") {
                    twoway `fitlayer' `pts'), `base'
                    timer on 1
                    capture noisily gpolish ptlabel label if lab == 1, x(x) y(y) size(`lp') msize(`mk') color("0 0 0")
                    local rc = _rc
                    timer off 1
                    local font $GPL_FONT
                    if !`fontshown' {
                        di as res "gpolish width table: $GPL_FONT"
                        local fontshown 1
                    }
                    if "$GPL_FONT" != "open sans" {
                        di as err "gpolish used the $GPL_FONT width table, not Open Sans's; stopping"
                        exit 498
                    }
                    if `rc' == 0 {
                        * leader lines: gpolish adds the k-th leader for the k-th label it placed far out,
                        * and only those labels have centre box alignment
                        local nt `.g.plotregion1.added_text.arrnels'
                        local nl `.g.plotregion1.added_lines.arrnels'
                        if "`nt'" == "" local nt 0
                        if "`nl'" == "" local nl 0
                        local j 0
                        forvalues k = 1/`nt' {
                            if "`.g.plotregion1.added_text[`k'].style.box_alignment.setting'" == "center" {
                                local ++j
                                post `lh' ("`scen'") (`"`.g.plotregion1.added_text[`k'].text[1]'"') ///
                                    (`.g.plotregion1.added_lines[`j'].x0') (`.g.plotregion1.added_lines[`j'].y0') ///
                                    (`.g.plotregion1.added_lines[`j'].x1') (`.g.plotregion1.added_lines[`j'].y1')
                            }
                        }
                        if `j' != `nl' {
                            di as err "`scen': `j' centred labels but `nl' leader lines"
                            exit 459
                        }
                    }
                }
                else {
                    * labrepel 1.0 accepts seed() but does not apply it; its random jitter draws from the
                    * session's random-number stream. Setting the seed here makes each graph's result the
                    * same whichever scenarios ran before it.
                    local lseed : environment BENCH_SEED
                    if "`lseed'" == "" local lseed 12345
                    set seed `lseed'
                    timer on 1
                    capture noisily labrepel y x if lab == 1, label(label) mlabsize(2.6) xsize(7) ysize(4.6) seed(`lseed')
                    local rc = _rc
                    timer off 1
                    if `rc' == 0 {
                        twoway `fitlayer' (pcspike y x _ycoord _xcoord if lab == 1, lcolor(gs10) lwidth(vthin)) ///
                            `pts') (scatter _ycoord _xcoord if lab == 1, msymbol(none) mlabel(label) ///
                            mlabposition(0) mlabsize(`lp'pt) mlabcolor(black)), `base'
                        * the drawn leader of each label runs from its point to the label's centre
                        forvalues i = 1/`=_N' {
                            if lab[`i'] == 1 & !missing(_xcoord[`i'], _ycoord[`i']) {
                                post `lh' ("`scen'") (label[`i']) (x[`i']) (y[`i']) (_xcoord[`i']) (_ycoord[`i'])
                            }
                        }
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
                file write `gf' "`scen',`method',`W',`H',`px0',`py0',`px1',`py1',`xA',`xB',`yA',`yB',`secs',`rc',`font'" _n
            }
            file close `gf'
            if `leaders' {
                postclose `lh'
                use `ldta', clear
                format x0 y0 x1 y1 %21.0g
                export delimited using "out/stata/leaders_`method'_`set'.csv", replace
            }
        }
    }
end

* ---------------------------------------------------------------- fonts: record, set, run, restore
local fontsets svg
if "`c(mode)'" != "batch" & "`c(console)'" != "console" local fontsets svg window
foreach s of local fontsets {
    mata: st_rclear()
    quietly graph set `s'
    local old_`s' `"`r(fontface)'"'
    di as txt `"graph set `s' fontface was [`old_`s'']"'
    if `"`old_`s''"' == "" di as err "warning: cannot read graph set `s' fontface; it is left unchanged"
    else if `"`old_`s''"' != "Open Sans" graph set `s' fontface "Open Sans"
}
capture noisily _bench_run "`methods'"
local rc = _rc
foreach s of local fontsets {
    if `"`old_`s''"' != "" & `"`old_`s''"' != "Open Sans" graph set `s' fontface `"`old_`s''"'
    mata: st_rclear()
    quietly graph set `s'
    di as txt `"graph set `s' fontface is now [`r(fontface)']"'
}
if `rc' exit `rc'
di as res "stata benchmark done"
