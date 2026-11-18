* gpolish check battery (Stata 16+). Run from the repository root:
*   stata-mp -b do tests/gpolish_battery.do
version 16
set more off
set varabbrev off
clear all
adopath ++ "`c(pwd)'/src"
global NCHK 0
capture program drop chk
program chk
    gettoken what 0 : 0
    capture assert `0'
    if _rc {
        di as err "FAILED: `what'   [`0']"
        exit 9
    }
    global NCHK = $NCHK + 1
end
capture program drop ntext
program ntext, rclass
    args g arr
    local k `.`g'.plotregion1.`arr'.arrnels'
    if "`k'"=="" local k 0
    return scalar k = `k'
end
graph set window fontface "Open Sans"

* ---- 1. style ---------------------------------------------------------------
sysuse uslifeexp, clear
label var le_wfemale "White women"
label var le_wmale   "White men"
label var le_bfemale "Black women"
label var le_bmale   "Black men"
line le_wfemale le_wmale le_bfemale le_bmale year, scheme(pypolish) legend(off) title("A title") name(g1, replace)
gpolish
chk style_bold  substr(`"`.g1.title.text[1]'"',1,4)=="{bf:"
gpolish
chk style_idempotent  `"`.g1.title.text[1]'"'=="{bf:A title}"

* ---- 2. endlabel: counts, labels, repel -------------------------------------
gpolish endlabel, values dots
ntext g1 added_text
chk end_ntext r(k)==8
ntext g1 added_markers
chk end_nmark r(k)==4
chk end_label `"`.g1.plotregion1.added_text[1].text[1]'"'=="{bf:White women}"
chk end_value `"`.g1.plotregion1.added_text[2].text[1]'"'=="79.9"
chk end_right `.g1.plotregion1.added_text[1].xpos.val' > 1999
* repel: Black women (74.7) and White men (74.6) must be separated by at least one text height
gpolish geom, name(g1)
local sep = abs(`.g1.plotregion1.added_text[3].ypos.val' - `.g1.plotregion1.added_text[5].ypos.val')*r(yb)
chk end_repel `sep' >= 0.99*1.3*9.5/72*r(gpi)
* colour follows the line
local c1 `.g1.plotregion1.plot1.style.line.color.rgb'
local c2 `.g1.plotregion1.added_text[1].style.color.rgb'
chk end_colour "`: list retokenize c1'"=="`: list retokenize c2'"

* ---- 3. named, non-current graph --------------------------------------------
line le_wfemale le_bmale year, legend(off) name(g2, replace)
line le year, name(g3, replace)
gpolish endlabel, name(g2)
ntext g2 added_text
chk named_graph r(k)==2
ntext g3 added_text
chk named_untouched r(k)==0

* ---- 4. wrap ----------------------------------------------------------------
label var le_bmale "Black men, the group with the lowest life expectancy"
line le_wfemale le_bmale year, legend(off) name(g4, replace)
gpolish endlabel, wrap(12)
chk wrap_lines `.g4.plotregion1.added_text[2].text.arrnels' >= 3
label var le_bmale "Black men"

* ---- 5. log y axis ----------------------------------------------------------
line le_wfemale le_bmale year, legend(off) yscale(log) name(g5, replace)
gpolish endlabel
chk logy_pos abs(`.g5.plotregion1.added_text[1].ypos.val' - 79.9) < 1.5

* ---- 6. marginsplot: sersets built from tempvars ----------------------------
sysuse nlsw88, clear
quietly regress wage c.ttl_exp##i.collgrad
quietly margins collgrad, at(ttl_exp=(0(7)28))
marginsplot, recast(line) recastci(rarea) legend(off) name(g6, replace)
gpolish endlabel, labels("No degree" "College grad")
ntext g6 added_text
chk margins_lines_only r(k)==2
chk margins_label `"`.g6.plotregion1.added_text[2].text[1]'"'=="{bf:College grad}"

* ---- 7. callout: explicit and automatic -------------------------------------
sysuse uslifeexp, clear
line le_wfemale le_bmale year, legend(off) name(g7, replace)
gpolish callout "Explicit" "two lines", at(1950 45) to(1918 39)
ntext g7 added_text
chk callout_text r(k)==1
chk callout_lines `.g7.plotregion1.added_text[1].text.arrnels'==2
ntext g7 added_lines
chk callout_segs r(k)==26
gpolish callout "Automatic", to(1918 39)
gpolish geom, name(g7)
local gx = r(xa) + r(xb)*`.g7.plotregion1.added_text[2].xpos.val'
local gy = r(ya) + r(yb)*`.g7.plotregion1.added_text[2].ypos.val'
chk auto_inside `gx' >= r(gx0) & `gx' <= r(gx1) & `gy' >= r(gy0) & `gy' <= r(gy1)
* the automatic box must not sit on the explicit one
chk auto_distinct abs(`.g7.plotregion1.added_text[2].xpos.val' - 1950) > 3 | abs(`.g7.plotregion1.added_text[2].ypos.val' - 45) > 3
gpolish callout "Text only", at(1960 50)
ntext g7 added_lines
chk textonly_noarrow r(k)==52
gpolish bracket, x(1900) y0(40) y1(50)
ntext g7 added_lines
chk bracket r(k)==55
capture gpolish callout "nothing"
chk callout_needs_pos _rc==198

* ---- 8. ptlabel + legend on a log-x scatter ---------------------------------
sysuse lifeexp, clear
drop if missing(gnppc, lexp)
twoway (scatter lexp gnppc if region==1) (scatter lexp gnppc if region==2), xscale(log) ///
    legend(order(1 "Europe" 2 "N. America")) name(g8, replace)
gpolish ptlabel country if inlist(country, "Haiti", "Canada", "Albania", "Norway"), x(gnppc) y(lexp)
ntext g8 added_text
chk pt_n r(k)==4
gpolish geom, name(g8)
forvalues k = 1/4 {
    local gx = r(xa) + r(xb)*ln(`.g8.plotregion1.added_text[`k'].xpos.val')
    chk pt_inside`k' `gx' >= r(gx0) & `gx' <= r(gx1)
}
gpolish legend
local c1 `.g8.plotregion1.plot2.style.marker.fillcolor.rgb'
local c2 `.g8.legend.plotregion1.label[2].style.color.rgb'
chk legend_colour "`: list retokenize c1'"=="`: list retokenize c2'"

* ---- 9. rotation: quarter turn drawn, other angles stored + noted ------------
gpolish callout "Vertical", at(1000 60) angle(90)
gpolish callout "Tilted", at(2000 60) angle(20)
chk angle_stored "`.g8.plotregion1.added_text[6].style.angle.setting'"=="20"

* ---- 10. refusals and fallbacks ---------------------------------------------
graph bar (mean) lexp, over(region) name(g9, replace)
capture noisily gpolish endlabel
chk refuse_bar _rc==198
graph set window fontface "Comic Sans MS"
sysuse uslifeexp, clear
line le_wfemale le_bmale year, legend(off) name(g10, replace)
gpolish endlabel
ntext g10 added_text
chk unknown_font r(k)==2
graph set window fontface "Open Sans"
scatter le year, name(g11, replace)
capture noisily gpolish endlabel
chk no_lines _rc==198
* ---- 11. note, brace, arrow ----------------------------------------------------
sysuse auto, clear
scatter mpg weight, name(g12, replace)
gpolish note "{bf:Finding}" "two lines", at(3500 35)
chk note_box "`.g12.plotregion1.added_text[1].style.drawbox.setting'"=="yes"
chk note_lines `.g12.plotregion1.added_text[1].text.arrnels'==2
ntext g12 added_lines
chk note_noarrow r(k)==0
gpolish note "Auto", to(3000 20)
ntext g12 added_lines
chk note_arrow r(k)==26
gpolish brace "Range", from(4000 12) to(4800 12)
ntext g12 added_lines
chk brace_segs r(k)==26+43
ntext g12 added_text
chk brace_label r(k)==3
chk brace_above `.g12.plotregion1.added_text[3].ypos.val' > 12
gpolish brace, from(2000 20) to(2000 30) flip
ntext g12 added_text
chk brace_nolabel r(k)==3
gpolish arrow, from(2500 35) to(2500 28)
ntext g12 added_lines
chk arrow_segs r(k)==26+43+43+26

* ---- 12. bold title on a non-twoway graph ---------------------------------------
graph bar (mean) mpg, over(foreign) title("Bar title") name(g13, replace)
gpolish
chk bar_bold `"`.g13.title.text[1]'"'=="{bf:Bar title}"

* ---- 13. $ and backticks in text are kept literally -----------------------------
global foo X
sysuse uslifeexp, clear
line le_wfemale le_bmale year, legend(off) name(e1, replace)
gpolish callout "Cost \$foo here", at(1950 45)
chk esc_callout strpos(`"`.e1.plotregion1.added_text[1].text[1]'"', "{c 36}foo")>0
label var le_bmale "Black men \$foo"
line le_wfemale le_bmale year, name(e2, replace)
gpolish endlabel
chk esc_varlabel strpos(`"`.e2.plotregion1.added_text[2].text[1]'"', "{c 36}foo")>0
gpolish endlabel, labels("A \$foo" "B")
chk esc_labels strpos(`"`.e2.plotregion1.added_text[3].text[1]'"', "{c 36}foo")>0
label var le_bmale "Black men"
sysuse auto, clear
replace make = "Car \$foo" in 1
scatter mpg weight, name(e3, replace)
gpolish ptlabel make in 1, x(weight) y(mpg)
chk esc_ptlabel strpos(`"`.e3.plotregion1.added_text[1].text[1]'"', "{c 36}foo")>0

* ---- 14. reversed axis and side(left) --------------------------------------------
sysuse uslifeexp, clear
line le_wfemale le_bmale year, xscale(reverse) name(r1, replace)
gpolish endlabel
chk rev_side `.r1.plotregion1.added_text[1].xpos.val' < 1900
chk legend_off "`.r1.legend.draw_view.setting'"=="no"
line le_wfemale le_bmale year, name(r2, replace)
gpolish endlabel, side(left) values
chk side_left `.r2.plotregion1.added_text[1].xpos.val' < 1900
chk side_left_val `.r2.plotregion1.added_text[2].xpos.val' < `.r2.plotregion1.added_text[1].xpos.val'
line le_wfemale le_bmale year, name(r3, replace)
gpolish endlabel, keeplegend color("0 0 0")
chk keeplegend "`.r3.legend.draw_view.setting'"=="yes"
local c `.r3.plotregion1.added_text[1].style.color.rgb'
chk colour_opt "`: list retokenize c'"=="0 0 0"

* ---- 15. empty series ------------------------------------------------------------
gen empty = .
line le_wfemale empty year, name(m1, replace)
gpolish endlabel
ntext m1 added_text
chk empty_skipped r(k)==1
line empty year, name(m2, replace)
local mg0 = `.m2.style.margin.gright.val'
capture gpolish endlabel
chk empty_all _rc==2000
chk empty_nomargin abs(`.m2.style.margin.gright.val' - `mg0') < 1e-6

* ---- 16. re-running endlabel, and gpolish clear -----------------------------------
line le_wfemale le_bmale year, name(c1, replace)
local mg0 = `.c1.style.margin.gright.val'
gpolish endlabel, values dots
local mg1 = `.c1.style.margin.gright.val'
gpolish endlabel, values dots
chk rerun_margin abs(`.c1.style.margin.gright.val' - `mg1') < 1e-6
ntext c1 added_text
local vis 0
forvalues k = 1/`r(k)' {
    if "`.c1.plotregion1.added_text[`k'].draw_view.setting'"!="no" local ++vis
}
chk rerun_visible `vis'==4
gpolish callout "extra", at(1950 40)
gpolish clear
ntext c1 added_text
chk clear_text r(k)==0
ntext c1 added_markers
chk clear_markers r(k)==0
chk clear_margin abs(`.c1.style.margin.gright.val' - `mg0') < 1e-6
chk clear_legend "`.c1.legend.draw_view.setting'"=="yes"
gpolish endlabel
ntext c1 added_text
chk after_clear r(k)==2

* ---- 17. clear errors for bad input ------------------------------------------------
capture gpolish endlabel, name(nosuch)
chk notfound _rc==111
line le year, name(p1, replace)
capture gpolish endlabel, plots(3)
chk plots_range _rc==198
sysuse auto, clear
scatter mpg weight, name(z1, replace)
gpolish ptlabel make if price > 1e9, x(weight) y(mpg)
ntext z1 added_text
chk pt_none r(k)==0
capture gpolish brace, from(3000 20) to(3000 20)
chk brace_zero _rc==198
capture gpolish callout "x", at(3000)
chk xy_count _rc==198
scatter price weight, xscale(log) name(b1, replace)
gpolish bracket, x(3000) y0(5000) y1(10000)
chk bracket_log abs(`.b1.plotregion1.added_lines[2].x1' - 3000) > 5

* ---- 18. dates and expressions in coordinates --------------------------------------
sysuse sp500, clear
line close date, name(d1, replace)
gpolish callout "Low", to(td(21sep2001) 966)
ntext d1 added_text
chk date_callout r(k)==1
gpolish arrow, from(td(01mar2001) 1200) to(td(01apr2001) 1150)
chk date_arrow abs(`.d1.plotregion1.added_lines[30].x0' - td(01mar2001)) < 1 | `.d1.plotregion1.added_lines.arrnels' > 26

* ---- 19. wrap() counts characters --------------------------------------------------
sysuse uslifeexp, clear
label var le_bmale "Black men, the group with the lowest life expectancy"
line le_wfemale le_bmale year, name(w1, replace)
gpolish endlabel, wrap(20)
chk wrap_chars `.w1.plotregion1.added_text[2].text.arrnels' >= 3

gpolish limits

di as res _n "gpolish battery: $NCHK checks passed (Stata `c(stata_version)')"
