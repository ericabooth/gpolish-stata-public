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
* r(k) counts the visible objects (endlabel keeps a hidden record box); r(all) counts all
program ntext, rclass
    args g arr
    local k `.`g'.plotregion1.`arr'.arrnels'
    if "`k'"=="" local k 0
    local v 0
    forvalues j = 1/`k' {
        if "`.`g'.plotregion1.`arr'[`j'].draw_view.setting'"!="no" local ++v
    }
    return scalar k = `v'
    return scalar all = `k'
end
* the window font is a saved preference: note it here and put it back at the end
quietly graph set window
local _wf0 `"`r(fontface)'"'
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
* a font without a width table (set through GPOLISH_FONT, which also works in batch mode)
global GPOLISH_FONT "Comic Sans MS"
sysuse uslifeexp, clear
line le_wfemale le_bmale year, legend(off) name(g10, replace)
gpolish endlabel
ntext g10 added_text
chk unknown_font r(k)==2
chk font_override "$GPL_FONT"=="comic sans ms"
global GPOLISH_FONT
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
chk esc_labels strpos(`"`.e2.plotregion1.added_text[4].text[1]'"', "{c 36}foo")>0
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
chk rerun_visible r(k)==4
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

* ---- 20. edits survive graph save and graph use --------------------------------
sysuse uslifeexp, clear
line le_wfemale le_bmale year, name(sv, replace)
gpolish
gpolish endlabel, values dots
gpolish note "Saved note", at(1950 45)
tempfile gph
graph save sv "`gph'", replace
graph drop sv
graph use "`gph'", name(sv2)
ntext sv2 added_text
chk save_text r(k)==5
ntext sv2 added_markers
chk save_markers r(k)==2
chk save_box "`.sv2.plotregion1.added_text[6].style.drawbox.setting'"=="yes"
chk save_title substr(`"`.sv2.title.text[1]'"',1,4)=="{bf:" | `"`.sv2.title.text[1]'"'==""

* ---- 21. leader lines in crowded point labels ---------------------------------------
sysuse auto, clear
scatter mpg weight, name(ld1, replace)
gpolish ptlabel make, x(weight) y(mpg)
ntext ld1 added_text
chk lead_all r(k)==74
ntext ld1 added_lines
chk lead_some r(k) > 0
local nlead = r(k)
scatter mpg weight, name(ld2, replace)
gpolish ptlabel make, x(weight) y(mpg) noleader
ntext ld2 added_lines
chk noleader r(k)==0
sysuse lifeexp, clear
scatter lexp gnppc, xscale(log) name(ld3, replace)
gpolish ptlabel country if inlist(country, "Haiti", "Bolivia", "Canada"), x(gnppc) y(lexp)
ntext ld3 added_lines
chk sparse_noleader r(k)==0

* ---- 22. leader search where a leader's path crosses no obstacle --------------------
clear
set obs 400
set seed 2026
gen double x = rnormal()
gen double y = rnormal()
gen double r = x^2 + y^2
sort r
gen str12 nm = "Point " + string(_n)
scatter y x, name(cc, replace)
capture noisily gpolish ptlabel nm in 1/2, x(x) y(y)
chk lead_empty_path _rc==0
ntext cc added_text
chk lead_empty_text r(k)==2

* ---- 23. the endlabel record belongs to one graph and survives other edits ---------
sysuse uslifeexp, clear
* a graph redrawn under the same name (in the same second) has no record: notes stay
line le_wfemale le_bmale year, name(rg, replace)
gpolish endlabel
line le_wfemale le_bmale year, name(rg, replace) title("Second")
local mg0 = `.rg.style.margin.gright.val'
gpolish note "Note A", at(1910 75)
gpolish note "Note B", at(1910 70)
gpolish endlabel
chk samename_notes "`.rg.plotregion1.added_text[1].draw_view.setting'`.rg.plotregion1.added_text[2].draw_view.setting'"=="yesyes"
ntext rg added_text
chk samename_count r(k)==4
* a re-run after an arrow (which adds lines) still replaces the labels
line le_wfemale le_bmale year, name(ra, replace)
local mg0 = `.ra.style.margin.gright.val'
gpolish endlabel, values
local mg1 = `.ra.style.margin.gright.val'
gpolish arrow, from(1950 50) to(1960 60)
gpolish callout "Flu", to(1918 36.6)
gpolish endlabel, values
ntext ra added_text
chk rerun_after_arrow r(k)==5
chk rerun_after_arrow_margin abs(`.ra.style.margin.gright.val' - `mg1') < 1e-6
gpolish clear
chk clear_after_arrow_margin abs(`.ra.style.margin.gright.val' - `mg0') < 1e-6
chk clear_after_arrow_legend "`.ra.legend.draw_view.setting'"=="yes"
* graph save and graph use under another name: the record travels with the graph
line le_wfemale le_bmale year, name(su, replace)
local mg0 = `.su.style.margin.gright.val'
gpolish endlabel
tempfile gsu
graph save su "`gsu'", replace
graph drop su
graph use "`gsu'", name(su2)
gpolish endlabel, values
ntext su2 added_text
chk use_rerun r(k)==4
gpolish clear
chk use_clear_margin abs(`.su2.style.margin.gright.val' - `mg0') < 1e-6
chk use_clear_legend "`.su2.legend.draw_view.setting'"=="yes"
* a recorded label changed by other means makes the record stale: nothing is hidden
line le_wfemale le_bmale year, name(st, replace)
gpolish endlabel
_gm_edit .st.plotregion1.added_text[1].text = {}
_gm_edit .st.plotregion1.added_text[1].text.Arrpush "Edited by hand"
gpolish endlabel
chk stale_kept "`.st.plotregion1.added_text[1].draw_view.setting'"!="no"

* ---- 24. plots() counts plots, not added objects ------------------------------------
line le_wfemale le_bmale year, name(pc, replace)
gpolish callout "x", to(1950 60)
capture gpolish endlabel, plots(3)
chk plots_count_range _rc==198
ntext pc added_text
chk plots_count_noedit r(k)==1
gpolish endlabel, plots(2)
ntext pc added_text
chk plots_count_ok r(k)==2

* ---- 25. second y axis --------------------------------------------------------------
gen pop = 1000 + 20*(year-1900)
label var pop "Population"
twoway (line le year) (line pop year, yaxis(2)), name(y2, replace)
local mg0 = `.y2.style.margin.gright.val'
local pm0 = `.y2.plotregion1.style.margin.gright.val'
gpolish endlabel, values
ntext y2 added_text
chk y2_both r(k)==4
* the y2 label sits at the last population value, read on the second axis
gpolish geom, name(y2)
local gy = r(ya) + r(yb)*`.y2.plotregion1.added_text[3].ypos.val'
local want = `.y2.plotregion2.drawn_yalpha' + `.y2.plotregion2.drawn_ybeta'*2980
chk y2_ypos abs(`gy' - `want') < 1.3*9.5/72*r(gpi)
* the room is made inside the plot regions, so the labels clear the y2 axis
chk y2_inner abs(`.y2.style.margin.gright.val' - `mg0') < 1e-6 & `.y2.plotregion2.style.margin.gright.val' > `pm0'
local gx = r(xa) + r(xb)*`.y2.plotregion1.added_text[4].xpos.val'
chk y2_clear_axis `gx' < `.y2.yaxis2.gdi_x0'
gpolish clear
chk y2_clear abs(`.y2.plotregion2.style.margin.gright.val' - `pm0') < 1e-6
twoway (line le year) (line pop year, yaxis(2)), name(y2l, replace)
gpolish legend
local c1 `.y2l.plotregion2.plot2.style.line.color.rgb'
local c2 `.y2l.legend.plotregion1.label[2].style.color.rgb'
chk y2_legend "`: list retokenize c1'"=="`: list retokenize c2'"
gpolish callout "Index 2000", to(1950 2000) yaxis(2)
gpolish geom, name(y2l)
local gtx = `.y2l.plotregion1.added_lines[24].x1'
local gty = r(ya) + r(yb)*`.y2l.plotregion1.added_lines[24].y1'
local want = `.y2l.plotregion2.drawn_yalpha' + `.y2l.plotregion2.drawn_ybeta'*2000
chk y2_callout abs(`gty' - `want') < 0.1*r(gpi) & abs(`gtx' - 1950) < 3
capture gpolish callout "x", to(1950 2000) yaxis(3)
chk y2_noaxis _rc==198
* a graph whose only y axis is yaxis(2)
line le year, yaxis(2) title("Only axis 2") name(o2, replace)
capture noisily gpolish
chk only_y2 _rc==0
chk only_y2_bold substr(`"`.o2.title.text[1]'"',1,4)=="{bf:"
gpolish endlabel
ntext o2 added_text
chk only_y2_endlabel r(k)==1
* ptlabel on a second axis
sysuse auto, clear
twoway (scatter mpg weight) (scatter price weight, yaxis(2)), name(y2p, replace)
gpolish ptlabel make if make=="Cad. Seville", x(weight) y(price) yaxis(2)
gpolish geom, name(y2p)
local gy = r(ya) + r(yb)*`.y2p.plotregion1.added_text[1].ypos.val'
local want = `.y2p.plotregion2.drawn_yalpha' + `.y2p.plotregion2.drawn_ybeta'*15906
chk y2_ptlabel abs(`gy' - `want') < 0.4*r(gpi)

* ---- 26. side(left) and an axis on the labelled side ------------------------------
sysuse uslifeexp, clear
line le_wfemale le_bmale year, name(sl, replace)
local pm0 = `.sl.plotregion1.style.margin.gleft.val'
gpolish endlabel, side(left) values
gpolish geom, name(sl)
local gx = r(xa) + r(xb)*`.sl.plotregion1.added_text[2].xpos.val'
chk left_clear_axis `gx' > `.sl.yaxis1.gdi_x1'
chk left_inner `.sl.plotregion1.style.margin.gleft.val' > `pm0'
line le_wfemale le_bmale year, yscale(alt) name(sa, replace)
gpolish endlabel, values
gpolish geom, name(sa)
local gx = r(xa) + r(xb)*`.sa.plotregion1.added_text[2].xpos.val'
chk alt_clear_axis `gx' < `.sa.yaxis1.gdi_x0'

* ---- 27. legend keeps multi-line labels; a literal } is not wrapped -------------------
line le_male le_female year, legend(label(1 "Men," "all races") label(2 "Women: a}b")) name(lg2, replace)
gpolish legend
chk legend_lines `.lg2.legend.plotregion1.label[1].text.arrnels'==2
chk legend_line2 `"`.lg2.legend.plotregion1.label[1].text[2]'"'=="{bf:all races}"
chk legend_brace `"`.lg2.legend.plotregion1.label[2].text[1]'"'=="Women: a}b"
label var le_female "Women: a}b"
line le_male le_female year, name(lb, replace)
gpolish endlabel
chk endlabel_brace `"`.lb.plotregion1.added_text[2].text[1]'"'=="Women: a}b"
chk endlabel_bold substr(`"`.lb.plotregion1.added_text[1].text[1]'"',1,4)=="{bf:"
label var le_female ""

* ---- 28. arrows with no length, bad segments(), unknown subcommands -----------------
line le year, name(z0, replace)
capture gpolish arrow, from(1950 50) to(1950 50)
chk arrow_zero _rc==198
ntext z0 added_lines
chk arrow_zero_noedit r(k)==0
capture noisily gpolish callout "Influenza pandemic", at(1915 40) to(1920 40)
chk callout_inside _rc==0
ntext z0 added_text
chk callout_inside_text r(k)==1
ntext z0 added_lines
chk callout_inside_noarrow r(k)==0
capture gpolish callout "seg0", to(1950 60) segments(0)
chk seg_zero _rc==198
capture gpolish arrow, from(1930 50) to(1960 60) segments(-3)
chk seg_neg _rc==198
ntext z0 added_text
chk seg_noedit r(k)==1
capture gpolish endlable, values
chk unknown_sub _rc==199
capture gpolish , nobold
chk comma_style _rc==0

* ---- 29. r() is kept, and expressions may read it -----------------------------------
summarize le
local mx = r(max)
gpolish callout "max", to(1999 r(max))
chk r_kept r(max)==`mx'
chk r_expr abs(`.z0.plotregion1.added_lines[24].x1' - 1999) < 3
gpolish
chk r_kept_style r(max)==`mx'
gpolish geom
chk geom_returns r(gpi) > 0

* ---- 30. friendly errors ---------------------------------------------------------------
graph pie le_male if year > 1995, over(year) name(pie, replace)
capture gpolish callout "x", at(1 1)
chk pie_refused _rc==198
graph drop _all
capture gpolish render
chk render_nograph _rc==111
clear
set obs 5
gen x = _n - 1
gen y = _n
gen lab = "p" + string(_n)
scatter y x, xscale(log) name(lz, replace)
capture noisily gpolish ptlabel lab if x==0, x(x) y(y)
chk ptlabel_log0 _rc==0
ntext lz added_text
chk ptlabel_log0_none r(k)==0

* ---- 31. bracket: expressions, label, ticks follow the screen -----------------------
sysuse sp500, clear
line close date, name(bd, replace)
capture noisily gpolish bracket "Drop", x(td(21sep2001)) y0(966) y1(1100)
chk bracket_expr _rc==0
chk bracket_expr_x abs(`.bd.plotregion1.added_lines[1].x0' - td(21sep2001)) < 1e-6
ntext bd added_text
chk bracket_label r(k)==1
clear
set obs 30
gen x = _n
gen y = 10 + mod(_n*7, 13)
scatter y x, xscale(reverse) name(br, replace)
gpolish bracket, x(25) y0(12) y1(20)
gpolish geom, name(br)
local sp = r(xa) + r(xb)*`.br.plotregion1.added_lines[2].x0'
local tk = r(xa) + r(xb)*`.br.plotregion1.added_lines[2].x1'
chk bracket_screen_right `tk' > `sp'
gpolish bracket, x(5) y0(12) y1(20) left
local sp = r(xa) + r(xb)*`.br.plotregion1.added_lines[5].x0'
local tk = r(xa) + r(xb)*`.br.plotregion1.added_lines[5].x1'
chk bracket_screen_left `tk' < `sp'

* ---- 32. a filled box's edge sits on at() ---------------------------------------------
scatter y x, xline(12 18) name(bxa, replace)
gpolish note "Left-aligned", at(12 16)
gpolish note "Right-aligned", at(18 18) align(right)
chk box_left abs(`.bxa.plotregion1.added_text[1].xpos.val' - 12) < 1e-6
chk box_right abs(`.bxa.plotregion1.added_text[2].xpos.val' - 18) < 1e-6

* ---- 33. end labels: CJK widths, and labels kept inside the plot height -------------
sysuse uslifeexp, clear
label var le_male "男性预期寿命增长率"
line le_male le_female year, name(cj, replace)
gpolish endlabel, values
gpolish geom, name(cj)
local d = (`.cj.plotregion1.added_text[2].xpos.val' - `.cj.plotregion1.added_text[1].xpos.val')*r(xb)
chk cjk_width `d' > 9*9.5/72*r(gpi)
clear
set obs 20
gen t = _n
forvalues k = 1/25 {
    gen s`k' = t + `k'/100
    label var s`k' "Series `k'"
}
line s* t, legend(off) name(mn, replace)
gpolish endlabel
gpolish geom, name(mn)
local h = 1.3*9.5/72*r(gpi)
local ok 1
forvalues k = 1/25 {
    local gy = r(ya) + r(yb)*`.mn.plotregion1.added_text[`k'].ypos.val'
    if `gy' - 0.45*`h' < r(gy0) | `gy' + 0.45*`h' > r(gy1) local ok 0
}
chk repel_inside `ok'==1

* ---- 33b. the endlabel note counts overlapping pairs and close pairs apart ----------
capture program drop shownote
* runs a command with its output logged; r(note) is 1 when the output contains the text
program shownote, rclass
    gettoken what 0 : 0
    tempfile f
    quietly log using "`f'", text replace name(_shownote)
    `0'
    quietly log close _shownote
    tempname fh
    local found 0
    file open `fh' using "`f'", read text
    file read `fh' line
    while r(eof)==0 {
        if strpos(`"`macval(line)'"', `"`what'"') local found 1
        file read `fh' line
    }
    file close `fh'
    return scalar note = `found'
end
capture program drop endgaps
* r(min) and r(max): the smallest and largest distance between neighbouring visible end labels,
* in text sizes
program endgaps, rclass
    args g
    gpolish geom, name(`g')
    local em = 9.5/72*r(gpi)
    local yb = r(yb)
    local k `.`g'.plotregion1.added_text.arrnels'
    clear
    quietly set obs `k'
    quietly gen double gy = .
    forvalues j = 1/`k' {
        if "`.`g'.plotregion1.added_text[`j'].draw_view.setting'"=="no" continue
        quietly replace gy = `yb'*`.`g'.plotregion1.added_text[`j'].ypos.val' in `j'
    }
    quietly drop if missing(gy)
    sort gy
    quietly gen double d = (gy - gy[_n-1])/`em'
    summarize d, meanonly
    return scalar min = r(min)
    return scalar max = r(max)
end
clear
set obs 10
gen t = _n
forvalues i = 1/25 {
    gen s`i' = 5 + 0.01*`i'*(t==10)
}
line s* t, scheme(pypolish) name(cl, replace)
shownote "are closer than gap() asks but do not overlap" gpolish endlabel
chk note_close r(note)==1
shownote "of end labels overlap" gpolish endlabel
chk note_close_noovl r(note)==0
endgaps cl
chk note_close_premise r(min) > 0.95 & r(min) < 1.3
* not enough height: the labels are spread evenly and the note says they overlap
clear
set obs 10
gen t = _n
forvalues i = 1/25 {
    gen s`i' = 5 + 0.01*`i'*(t==10)
    label var s`i' "Sg`i'y"
}
line s* t, scheme(pypolish) ysize(2.8) name(ov, replace)
shownote "24 pair(s) of end labels overlap" gpolish endlabel
chk note_ovl r(note)==1
endgaps ov
chk ovl_even r(max) - r(min) < 0.01 & r(max) < 0.95
* a roomy graph gives no note
sysuse uslifeexp, clear
line le_wfemale le_bmale year, name(nn, replace)
shownote "pair(s)" gpolish endlabel
chk note_none r(note)==0

* ---- 33c. a graph keeps at most one endlabel record box -------------------------------
sysuse uslifeexp, clear
line le_wfemale le_wmale le_bfemale year, name(rb, replace)
forvalues r = 1/4 {
    gpolish endlabel, values
}
local nrec 0
local k `.rb.plotregion1.added_text.arrnels'
forvalues j = 1/`k' {
    if substr(`"`.rb.plotregion1.added_text[`j'].text[1]'"', 1, 16)=="gpolish-endlabel" local ++nrec
}
chk rec_one `nrec'==1
ntext rb added_text
chk rec_visible r(k)==6
* the reused record still undoes the latest labels
gpolish endlabel
ntext rb added_text
chk rec_rerun r(k)==3
gpolish clear
ntext rb added_text
chk rec_clear r(all)==0
chk rec_clear_legend "`.rb.legend.draw_view.setting'"=="yes"

* ---- 33d. ptlabel stops when y() or x() is drawn on another axis only -----------------
sysuse auto, clear
twoway (scatter mpg weight) (scatter price weight, yaxis(2)), name(ax2, replace)
capture gpolish ptlabel make if price > 12000, x(weight) y(price)
chk ax_y_rc _rc==198
ntext ax2 added_text
chk ax_y_noedit r(all)==0
capture gpolish ptlabel make if price > 12000, x(weight) y(price) yaxis(2)
chk ax_y_ok _rc==0
capture gpolish ptlabel make in 1, x(weight) y(mpg)
chk ax_y1_ok _rc==0
twoway (scatter mpg weight) (scatter mpg length, xaxis(2)), name(ax3, replace)
capture gpolish ptlabel make in 1, x(length) y(mpg)
chk ax_x_rc _rc==198
capture gpolish ptlabel make in 1, x(length) y(mpg) xaxis(2)
chk ax_x_ok _rc==0
* a variable that is not plotted is not checked
gen w2 = weight
twoway scatter mpg weight, name(ax4, replace)
capture gpolish ptlabel make in 1, x(w2) y(mpg)
chk ax_unplotted _rc==0

* ---- 33e. obstacle boxes cover the whole of a long band and line --------------------
clear
set obs 30000
gen x = _n
gen hi = cond(x > 28000 & x < 29000, 9, 1)
gen lo = 0
gen y = cond(x > 29000, 5, 1)
twoway (rarea lo hi x) (line y x), yscale(range(0 10)) name(lb, replace)
gpolish callout "x", to(15000 0.5)
gpolish geom, name(lb)
local gx = r(xa) + r(xb)*28500
local gy = r(ya) + r(yb)*8
local gxl = r(xa) + r(xb)*29500
local gl = r(ya) + r(yb)*5
mata: O = *findexternal("_gpl_OBS")
mata: st_local("cov", strofreal(sum((O[,1] :<= `gx') :& (O[,3] :>= `gx') :& (O[,2] :<= `gy') :& (O[,4] :>= `gy'))))
chk long_band `cov' > 0
mata: st_local("cov", strofreal(sum((O[,1] :<= `gxl') :& (O[,3] :>= `gxl') :& (O[,2] :<= `gl') :& (O[,4] :>= `gl'))))
chk long_line `cov' > 0
mata: st_local("nobs", strofreal(rows(O)))
chk long_rows `nobs' <= 40010
mata: mata drop O

* ---- 34. placement avoids bars and reference lines ---------------------------------
clear
set obs 12
gen m = _n
gen v = 80 - 3*abs(m-6)
replace v = 40 if m==6
twoway bar v m, base(0) yscale(range(0 110)) ylabel(0(20)100) name(ob1, replace)
gpolish callout "Strike month", to(6 40)
chk avoid_bars `.ob1.plotregion1.added_text[1].ypos.val' > 80
sysuse auto, clear
twoway (scatter price weight) (lfit price weight), xline(2500) name(ob2, replace)
gpolish ptlabel make if make=="BMW 320i", x(weight) y(price)
* the label's box (its width estimated from 8 characters) must not reach over the line
gpolish geom, name(ob2)
local gx = r(xa) + r(xb)*`.ob2.plotregion1.added_text[1].xpos.val'
local gl = r(xa) + r(xb)*2500
local w = 8*0.55*8.6/72*r(gpi)
local hz `.ob2.plotregion1.added_text[1].style.horizontal.setting'
local x0 = cond("`hz'"=="left", `gx', cond("`hz'"=="right", `gx' - `w', `gx' - `w'/2))
chk avoid_xline `gl' < `x0' | `gl' > `x0' + `w' 

* ---- 35. font detection in batch mode -------------------------------------------------
if "`c(mode)'"=="batch" {
    sysuse uslifeexp, clear
    line le year, name(fb, replace)
    gpolish endlabel
    quietly graph set svg
    chk batch_font "$GPL_FONT"==lower("`r(fontface)'") | ("`r(fontface)'"=="" & "$GPL_FONT"=="helvetica")
}

gpolish limits

if `"`_wf0'"'!="" graph set window fontface `"`_wf0'"'
di as res _n "gpolish battery: $NCHK checks passed (Stata `c(stata_version)')"
