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

* ---- 33d. ptlabel reads x() and y() on the plot region that draws them ----------------
capture program drop ptfar
* r(max): the largest distance, in inches, from a visible label to the nearest selected point,
* with the points placed on the scales of plot region `treg'
program ptfar, rclass
    args g treg xv yv cond
    preserve
    quietly keep if `cond'
    local pr .`g'.plotregion`treg'
    quietly gen double px = ``pr'.drawn_xalpha' + ``pr'.drawn_xbeta'*`xv'
    quietly gen double py = ``pr'.drawn_yalpha' + ``pr'.drawn_ybeta'*`yv'
    gpolish geom, name(`g')
    local gpi = r(gpi)
    local xa = r(xa)
    local xb = r(xb)
    local ya = r(ya)
    local yb = r(yb)
    local k `.`g'.plotregion1.added_text.arrnels'
    if "`k'"=="" local k 0
    local mx 0
    local nl 0
    forvalues j = 1/`k' {
        if "`.`g'.plotregion1.added_text[`j'].draw_view.setting'"=="no" continue
        local ++nl
        local lx = `xa' + `xb'*`.`g'.plotregion1.added_text[`j'].xpos.val'
        local ly = `ya' + `yb'*`.`g'.plotregion1.added_text[`j'].ypos.val'
        quietly gen double d = sqrt((px-`lx')^2 + (py-`ly')^2)/`gpi'
        quietly summarize d, meanonly
        local mx = max(`mx', r(min))
        drop d
    }
    restore
    return scalar max = `mx'
    return scalar n = `nl'
end
sysuse auto, clear
* y() drawn on the second axis only: read on that axis's region with no option
twoway (scatter mpg weight) (scatter price weight, yaxis(2)), name(ax2, replace)
capture gpolish ptlabel make if price > 12000, x(weight) y(price)
chk ax_auto_rc _rc==0
ptfar ax2 2 weight price "price > 12000"
chk ax_auto_near r(n)==5 & r(max) < 1
* an axis option that contradicts the variable's axis stops before any edit
twoway (scatter mpg weight) (scatter price weight, yaxis(2)), name(ax2b, replace)
capture gpolish ptlabel make if price > 12000, x(weight) y(price) yaxis(1)
chk ax_y_rc _rc==198
ntext ax2b added_text
chk ax_y_noedit r(all)==0
capture gpolish ptlabel make if price > 12000, x(weight) y(price) yaxis(2)
chk ax_y_ok _rc==0
ptfar ax2b 2 weight price "price > 12000"
chk ax_y_near r(max) < 1
* the only plot is on yaxis(2) or xaxis(2): plot region 1 holds it
twoway scatter price weight, yaxis(2) name(ax5, replace)
capture gpolish ptlabel make if price > 12000, x(weight) y(price)
chk ax_only_y2 _rc==0
ptfar ax5 1 weight price "price > 12000"
chk ax_only_y2_near r(n)==5 & r(max) < 1
twoway scatter mpg weight, xaxis(2) name(ax6, replace)
capture gpolish ptlabel make if mpg > 30, x(weight) y(mpg)
chk ax_only_x2 _rc==0
* one plot drawn with yaxis(1 2): either axis, or none, reads the same region
foreach o in "" "yaxis(1)" "yaxis(2)" {
    twoway scatter mpg weight, yaxis(1 2) name(ax7, replace)
    capture gpolish ptlabel make if mpg > 30, x(weight) y(mpg) `o'
    chk ax_y12_rc _rc==0
    ptfar ax7 1 weight mpg "mpg > 30"
    chk ax_y12_near r(n)==5 & r(max) < 1
}
* plot 1 on yaxis(2), plot 2 on axis 1: each variable is read on its own region
twoway (scatter price weight, yaxis(2)) (scatter mpg weight), name(ax8, replace)
capture gpolish ptlabel make if mpg > 30, x(weight) y(mpg)
chk ax_p1y2_mpg _rc==0
ptfar ax8 2 weight mpg "mpg > 30"
chk ax_p1y2_mpg_near r(n)==5 & r(max) < 1
twoway (scatter price weight, yaxis(2)) (scatter mpg weight), name(ax9, replace)
capture gpolish ptlabel make if price > 12000, x(weight) y(price) yaxis(2)
chk ax_p1y2_price _rc==0
ptfar ax9 1 weight price "price > 12000"
chk ax_p1y2_price_near r(n)==5 & r(max) < 1
twoway (scatter price weight, yaxis(2)) (scatter mpg weight), name(ax10, replace)
capture gpolish ptlabel make if mpg > 30, x(weight) y(mpg) yaxis(2)
chk ax_p1y2_wrong _rc==198
* x() drawn on the second x axis only
twoway (scatter mpg weight) (scatter mpg length, xaxis(2)), name(ax3, replace)
capture gpolish ptlabel make in 1, x(length) y(mpg)
chk ax_x_auto _rc==0
twoway (scatter mpg weight) (scatter mpg length, xaxis(2)), name(ax3b, replace)
capture gpolish ptlabel make in 1, x(length) y(mpg) xaxis(1)
chk ax_x_rc _rc==198
capture gpolish ptlabel make in 1, x(length) y(mpg) xaxis(2)
chk ax_x_ok _rc==0
* no plot region carries an axis of each variable
twoway (scatter price length, yaxis(2)) (scatter mpg weight, xaxis(2)), name(ax11, replace)
capture gpolish ptlabel make if price > 12000, x(weight) y(price)
chk ax_noregion _rc==198
* a variable that is not plotted is not checked
gen w2 = weight
twoway scatter mpg weight, name(ax4, replace)
capture gpolish ptlabel make in 1, x(w2) y(mpg)
chk ax_unplotted _rc==0
* positions on yaxis(2) when plot 1 is on yaxis(2) and a later plot on axis 1
twoway (scatter price weight, yaxis(2)) (scatter mpg weight), name(ax12, replace)
capture gpolish callout "x", to(3000 5000) yaxis(2)
chk ax_callout_y2 _rc==0
capture gpolish callout "y", to(3000 20) yaxis(1)
chk ax_callout_y1 _rc==0
capture gpolish arrow, from(2000 4000) to(3000 5000) yaxis(2)
chk ax_arrow_y2 _rc==0
gpolish geom, name(ax12)
local gy = r(ya) + r(yb)*`.ax12.plotregion1.added_text[2].ypos.val'
local want = `.ax12.plotregion2.drawn_yalpha' + `.ax12.plotregion2.drawn_ybeta'*20
local gy1 = r(ya) + r(yb)*`.ax12.plotregion1.added_text[1].ypos.val'
local want1 = `.ax12.plotregion1.drawn_yalpha' + `.ax12.plotregion1.drawn_ybeta'*5000
chk ax_callout_pos abs(`gy' - `want') < 1.5*r(gpi) & abs(`gy1' - `want1') < 1.5*r(gpi)

* ---- 33f. end labels made by gpolish 0.6.1 or earlier (no record) ---------------------
capture program drop oldend
* the edits gpolish 0.6.1 endlabel made, in the same order: margin, legend off, then per line
* an optional dot, a label box styled with linegap(1pt) and an optional value box at its height
program oldend
    args g side values dots
    local m 30
    _gm_edit .`g'.style.editstyle margin(`side'+`m') editcopy
    _gm_edit .`g'.legend.draw_view.setstyle, style(no)
    local nt 0`.`g'.plotregion1.added_text.arrnels'
    local nm 0`.`g'.plotregion1.added_markers.arrnels'
    foreach y in 70 74 78 {
        if "`dots'"=="dots" {
            local ++nm
            _gm_edit .`g'.plotregion1.AddMarker added_markers editor 1999 `y'
            _gm_edit .`g'.plotregion1.added_markers_new = `nm'
            _gm_edit .`g'.plotregion1.added_markers_rec = `nm'
            _gm_edit .`g'.plotregion1.added_markers[`nm'].style.editstyle marker(symbol(circle)) editcopy
        }
        local ++nt
        _gm_edit .`g'.plotregion1.AddTextBox added_text editor `y' 2001
        _gm_edit .`g'.plotregion1.added_text_new = `nt'
        _gm_edit .`g'.plotregion1.added_text_rec = `nt'
        _gm_edit .`g'.plotregion1.added_text[`nt'].style.editstyle size(9.5pt) color("26 26 26") horizontal(left) vertical(middle) box_alignment(east) linegap(1pt)  editcopy
        _gm_edit .`g'.plotregion1.added_text[`nt'].text = {}
        _gm_edit .`g'.plotregion1.added_text[`nt'].text.Arrpush "{bf:Line `y'}"
        if "`values'"=="values" {
            local ++nt
            _gm_edit .`g'.plotregion1.AddTextBox added_text editor `y' 2010
            _gm_edit .`g'.plotregion1.added_text_new = `nt'
            _gm_edit .`g'.plotregion1.added_text_rec = `nt'
            _gm_edit .`g'.plotregion1.added_text[`nt'].style.editstyle size(9.5pt) color("26 26 26") horizontal(right) vertical(middle) box_alignment(west) linegap(1.5pt)  editcopy
            _gm_edit .`g'.plotregion1.added_text[`nt'].text = {}
            _gm_edit .`g'.plotregion1.added_text[`nt'].text.Arrpush "`y'.0"
        }
    }
end
capture program drop przx
program przx, rclass
    args g
    quietly graph display `g'
    return scalar x0 = `.`g'.plotregion1.gdi_x0'
    return scalar x1 = `.`g'.plotregion1.gdi_x1'
end
sysuse uslifeexp, clear
line le_wfemale le_wmale le_bfemale year, name(old0, replace)
przx old0
local bx0 = r(x0)
local bx1 = r(x1)
line le_wfemale le_wmale le_bfemale year, name(oldref, replace)
gpolish endlabel
przx oldref
local rx0 = r(x0)
local rx1 = r(x1)
tempfile oldg
foreach v in "r values dots" "r" "l" {
    line le_wfemale le_wmale le_bfemale year, name(old1, replace)
    oldend old1 `v'
    graph save old1 "`oldg'", replace
    graph drop old1
    * endlabel replaces the old labels and makes its own margin only
    graph use "`oldg'", name(old2)
    gpolish endlabel
    ntext old2 added_text
    chk old_end_text r(k)==3
    ntext old2 added_markers
    chk old_end_dots r(k)==0
    przx old2
    chk old_end_margin abs(r(x1) - `rx1') < 1 & abs(r(x0) - `rx0') < 1
    chk old_end_legend "`.old2.legend.draw_view.setting'"=="no"
    * a second run uses the new record
    gpolish endlabel
    ntext old2 added_text
    chk old_end_rerun r(k)==3
    przx old2
    chk old_end_rerun_margin abs(r(x1) - `rx1') < 1
    graph drop old2
    * clear gives back the margin and the legend
    graph use "`oldg'", name(old3)
    gpolish clear
    ntext old3 added_text
    chk old_clear_text r(all)==0
    przx old3
    chk old_clear_margin abs(r(x1) - `bx1') < 1 & abs(r(x0) - `bx0') < 1
    chk old_clear_legend "`.old3.legend.draw_view.setting'"=="yes"
    gpolish clear
    przx old3
    chk old_clear_twice abs(r(x1) - `bx1') < 1
    graph drop old3
}
* two old runs stacked by 0.6.1 in separate sessions, and a callout added after them
line le_wfemale le_wmale le_bfemale year, name(old4, replace)
oldend old4 r
oldend old4 r values
gpolish callout "kept", at(1950 60)
gpolish endlabel
ntext old4 added_text
chk old_stack_text r(k)==4
przx old4
chk old_stack_margin abs(r(x1) - `rx1') < 1
* an old run that was already given back is left alone
line le_wfemale le_wmale le_bfemale year, name(old5, replace)
oldend old5 r
_gm_edit .old5.style.editstyle margin(r-30) editcopy
_gm_edit .old5.legend.draw_view.setstyle, style(yes)
gpolish clear
przx old5
chk old_undone_margin abs(r(x1) - `bx1') < 1
* a legend switched off by the user stays off
line le_wfemale le_wmale le_bfemale year, legend(off) name(old6, replace)
przx old6
local ox1 = r(x1)
_gm_edit .old6.style.editstyle margin(r+30) editcopy
_gm_edit .old6.plotregion1.AddTextBox added_text editor 70 2001
_gm_edit .old6.plotregion1.added_text[1].style.editstyle size(9.5pt) linegap(1pt) editcopy
gpolish clear
przx old6
chk old_userlegend "`.old6.legend.draw_view.setting'"=="no" & abs(r(x1) - `ox1') < 1
* a second clear on an old graph changes nothing and prints no note
local nlog `.old6.__LOG.arrnels'
shownote "0.6.1" gpolish clear
chk old_clear2_note r(note)==0
chk old_clear2_noedit `.old6.__LOG.arrnels'==`nlog'

* ---- 33g. one clear undoes every endlabel run; a second clear changes nothing ---------
* After any sequence of endlabel runs (some of them made stale by a hand edit, some with
* keeplegend, side(left), values or dots, across graph save and graph use), one gpolish clear
* leaves the plot region where it was before the first run, the legend as it was, and no added
* objects. A second clear makes no edit and prints no note.
capture program drop clrchk
program clrchk
    args g tag x0 x1 leg
    gpolish clear, name(`g')
    ntext `g' added_text
    chk `tag'_text r(all)==0
    ntext `g' added_markers
    chk `tag'_marks r(all)==0
    przx `g'
    chk `tag'_margin abs(r(x0) - `x0') < 1 & abs(r(x1) - `x1') < 1
    chk `tag'_legend "`.`g'.legend.draw_view.setting'"=="`leg'"
    local nlog `.`g'.__LOG.arrnels'
    shownote "note:" gpolish clear, name(`g')
    chk `tag'_clear2_note r(note)==0
    chk `tag'_clear2_noedit `.`g'.__LOG.arrnels'==`nlog'
    przx `g'
    chk `tag'_clear2_margin abs(r(x0) - `x0') < 1 & abs(r(x1) - `x1') < 1
end
capture program drop handedit
program handedit
    args g k
    _gm_edit .`g'.plotregion1.added_text[`k'].text = {}
    _gm_edit .`g'.plotregion1.added_text[`k'].text.Arrpush "Edited by hand"
end
sysuse uslifeexp, clear
* the stale case: run 1's record goes stale, run 2 still gives back run 1's margin and legend
line le_wfemale le_wmale le_bfemale year, name(sc1, replace)
przx sc1
local bx0 = r(x0)
local bx1 = r(x1)
gpolish endlabel
handedit sc1 1
shownote "changed or" gpolish endlabel
chk stale_note r(note)==1
ntext sc1 added_text
chk stale_hidden r(k)==4
chk stale_edit_kept "`.sc1.plotregion1.added_text[1].draw_view.setting'"!="no" & "`.sc1.plotregion1.added_text[2].draw_view.setting'"=="no"
przx sc1
chk stale_margin abs(r(x1) - `rx1') < 1 & abs(r(x0) - `rx0') < 1
chk stale_legend "`.sc1.legend.draw_view.setting'"=="no"
clrchk sc1 staleclr `bx0' `bx1' yes
* a single stale run
line le_wfemale le_wmale le_bfemale year, name(sc2, replace)
gpolish endlabel, values dots
handedit sc2 2
clrchk sc2 stale1 `bx0' `bx1' yes
* a chain of stale runs with mixed options
line le_wfemale le_wmale le_bfemale year, name(sc3, replace)
gpolish endlabel
handedit sc3 1
gpolish endlabel, values
handedit sc3 6
gpolish endlabel, side(left) dots
handedit sc3 11
gpolish endlabel, keeplegend
gpolish endlabel, values side(left)
clrchk sc3 chain `bx0' `bx1' yes
* keeplegend first, then a run that switches the legend off
line le_wfemale le_wmale le_bfemale year, name(sc4, replace)
gpolish endlabel, keeplegend
handedit sc4 1
gpolish endlabel
chk keep_then_off "`.sc4.legend.draw_view.setting'"=="no"
clrchk sc4 keepoff `bx0' `bx1' yes
* a legend switched off by the user stays off
line le_wfemale le_wmale le_bfemale year, legend(off) name(sc5, replace)
przx sc5
local ux0 = r(x0)
local ux1 = r(x1)
gpolish endlabel
handedit sc5 1
gpolish endlabel, values
clrchk sc5 userleg `ux0' `ux1' no
* across graph save and graph use, with a callout between the runs
line le_wfemale le_wmale le_bfemale year, name(sc6, replace)
gpolish endlabel
handedit sc6 2
tempfile gsc
graph save sc6 "`gsc'", replace
graph drop sc6
graph use "`gsc'", name(sc7)
gpolish callout "kept until clear", at(1950 60)
gpolish endlabel, dots
tempfile gsc2
graph save sc7 "`gsc2'", replace
graph drop sc7
graph use "`gsc2'", name(sc8)
clrchk sc8 saved `bx0' `bx1' yes
* labels made inside the plot regions (a second y axis on the right)
generate pop = 1000 + 20*(year-1900)
twoway (line le year) (line pop year, yaxis(2)), name(sc9, replace)
local pm1 = `.sc9.plotregion1.style.margin.gright.val'
local pm2 = `.sc9.plotregion2.style.margin.gright.val'
przx sc9
local px0 = r(x0)
local px1 = r(x1)
gpolish endlabel
handedit sc9 1
gpolish endlabel, values
clrchk sc9 inner `px0' `px1' yes
chk inner_pm abs(`.sc9.plotregion1.style.margin.gright.val' - `pm1') < 1e-6 & abs(`.sc9.plotregion2.style.margin.gright.val' - `pm2') < 1e-6
drop pop

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

* ---- 36. endlabel text follows the legend; ptlabel skips points off the plot -------
* the texts of the added boxes of graph g, joined by |, in the local alltext
capture program drop _alltext
program _alltext
    args g
    local n `.`g'.plotregion1.added_text.arrnels'
    if "`n'"=="" local n 0
    local t
    forvalues k = 1/`n' {
        local t `"`t'|`.`g'.plotregion1.added_text[`k'].text[1]'"'
    }
    c_local alltext `"`t'|"'
end
sysuse auto, clear
twoway (line price mpg, sort) (lfit price mpg), name(el1, replace)
gpolish endlabel
_alltext el1
local h = strpos(`"`alltext'"', "Fitted values") > 0
chk lfit_label `h'
local h = strpos(`"`alltext'"', "Price") > 0
chk lfit_data `h'
quietly regress price mpg i.foreign
quietly margins foreign, at(mpg=(12(4)40))
marginsplot, name(el2, replace)
gpolish endlabel
_alltext el2
local h = strpos(`"`alltext'"', "Domestic") > 0
chk mplot_dom `h'
local h = strpos(`"`alltext'"', "Foreign") > 0
chk mplot_for `h'
chk mplot_noleg "`.el2.legend.draw_view.setting'"=="no"
sysuse uslifeexp, clear
twoway (line le year if year<1950) (line le year if year>=1950), name(el3, replace)
gpolish endlabel
chk dup_keepleg "`.el3.legend.draw_view.setting'"=="yes"
gpolish endlabel, labels("Before 1950" "From 1950")
_alltext el3
local h = strpos(`"`alltext'"', "From 1950") > 0
chk dup_labels `h'
chk dup_labels_leg "`.el3.legend.draw_view.setting'"=="no"
* a second clear prints nothing
gpolish clear
tempfile clog
log using `"`clog'"', text name(_clr) replace
gpolish clear
log close _clr
mata: st_local("cl", strofreal(sum(strpos(cat(st_local("clog")), "removed")) > 0))
chk clear_silent `cl'==0
* points selected by ptlabel but outside the axis range are skipped
sysuse auto, clear
scatter price mpg if rep78==4, name(pt1, replace)
quietly count if price>8000 & rep78==4
local ndrawn = r(N)
gpolish ptlabel make if price>8000, x(mpg) y(price)
local nt `.pt1.plotregion1.added_text.arrnels'
chk off_plot `nt' < 14 & `nt' >= `ndrawn'
gpolish geom, name(pt1)
local ok 1
forvalues k = 1/`nt' {
    local yy = r(ya) + r(yb)*`.pt1.plotregion1.added_text[`k'].ypos.val'
    if `yy' > r(gy1) + 0.05*(r(gy1)-r(gy0)) local ok 0
}
chk off_plot_inside `ok'
twoway scatter price mpg if price<5000, name(pt2, replace)
gpolish ptlabel make if price>14000, x(mpg) y(price)
chk off_plot_none "`.pt2.plotregion1.added_text.arrnels'"=="" | "`.pt2.plotregion1.added_text.arrnels'"=="0"
* maxlabels() refuses a selection larger than it
scatter price mpg, name(pt3, replace)
capture gpolish ptlabel make, x(mpg) y(price) maxlabels(10)
chk maxlabels_rc _rc==198
chk maxlabels_noedit "`.pt3.plotregion1.added_text.arrnels'"=="" | "`.pt3.plotregion1.added_text.arrnels'"=="0"
capture gpolish ptlabel make, x(mpg) y(price) maxlabels(0)
chk maxlabels_bad _rc==198

* ---- 35. font detection in batch mode -------------------------------------------------
if "`c(mode)'"=="batch" {
    sysuse uslifeexp, clear
    line le year, name(fb, replace)
    gpolish endlabel
    quietly graph set svg
    chk batch_font "$GPL_FONT"==lower("`r(fontface)'") | ("`r(fontface)'"=="" & "$GPL_FONT"=="helvetica")
}

* ---- 36. round 3: off-axis targets, wide labels, empty text, bracket ends, value column, numeric labels
sysuse uslifeexp, clear
line le_wmale year, name(r3a, replace)
capture gpolish callout "Far away", to(2100 100)
chk r3_callout_off _rc==198
chk r3_callout_off_noedit "`.r3a.plotregion1.added_text.arrnels'"=="" | "`.r3a.plotregion1.added_text.arrnels'"=="0"
* round 3b: a box placed by hand with at() off the plot region gets a note and is drawn
capture noisily gpolish note "Far", at(1950 1e10)
chk r3_note_at_off _rc==0
chk r3_note_at_drawn "`.r3a.plotregion1.added_text.arrnels'"=="1"
* a box in the top margin with an arrow into the plot (worked before 0.7.0)
line le_wmale year, name(r3m, replace)
capture noisily gpolish callout "Box in margin", at(1990 90) to(1950 60)
chk r3_margin_at_ok _rc==0
chk r3_margin_at_drawn "`.r3m.plotregion1.added_text.arrnels'"=="1"
* the arrow target is still checked when at() is given
capture gpolish callout "Box", at(1990 70) to(2100 100)
chk r3_margin_to_off _rc==198
capture gpolish note "", at(1950 60)
chk r3_note_empty _rc==198
capture gpolish callout " ", to(1950 60)
chk r3_callout_empty _rc==198
capture gpolish bracket, x(1950) y0(60) y1(60)
chk r3_bracket_equal _rc==198
capture noisily gpolish callout "Fine", to(1950 60)
chk r3_callout_ok _rc==0
capture gpolish arrow, from(1950 60) to(2100 60)
chk r3_arrow_off_note _rc==0
local wide = 70*"W"
capture gpolish callout "`wide'", to(1950 60)
chk r3_callout_wide _rc==198
* a line that ends early: every value still sits in one column
sysuse uslifeexp, clear
replace le_bmale = . if year==2000
line le_wmale le_wfemale le_bmale year, name(r3b, replace)
gpolish endlabel, values
local x2 `.r3b.plotregion1.added_text[2].xpos.val'
local x4 `.r3b.plotregion1.added_text[4].xpos.val'
local x6 `.r3b.plotregion1.added_text[6].xpos.val'
chk r3_valcol abs(`x2'-`x6') < 1e-6 & abs(`x4'-`x6') < 1e-6
* a label wider than the plot is skipped, the others are placed
sysuse auto, clear
gen str80 s = make
replace s = 60*"W" in 1
scatter price mpg, name(r3c, replace)
gpolish ptlabel s in 1/3, x(mpg) y(price)
chk r3_wide_skip "`.r3c.plotregion1.added_text.arrnels'"=="2"
* numeric label variables: value label, else display format
scatter price mpg, name(r3d, replace)
gpolish ptlabel foreign if price>13000, x(mpg) y(price)
chk r3_num_vl inlist(`"`.r3d.plotregion1.added_text[1].text[1]'"', "Domestic", "Foreign")
scatter price mpg, name(r3e, replace)
gpolish ptlabel rep78 if price>13000 & !missing(rep78), x(mpg) y(price)
local t `"`.r3e.plotregion1.added_text[1].text[1]'"'
chk r3_num_fmt inlist(`"`t'"', "1", "2", "3", "4", "5")

* round 3b: geom and clear are refused on graph bar, like the other layout commands
graph bar (mean) mpg, over(foreign) name(r3g, replace)
capture gpolish geom, name(r3g)
chk r3_geom_bar _rc==198
capture gpolish clear, name(r3g)
chk r3_clear_bar _rc==198
* the bracket label sits at a fixed spot: the same with or without data under it
twoway scatteri 10 10 20 20, name(r3k1, replace) xscale(range(0 30)) yscale(range(0 30))
gpolish bracket "Span", x(15) y0(5) y1(25)
local bx1 `.r3k1.plotregion1.added_text[1].xpos.val'
twoway scatteri 10 10 20 20 15 16 15 17 15 18, name(r3k2, replace) xscale(range(0 30)) yscale(range(0 30))
gpolish bracket "Span", x(15) y0(5) y1(25)
local bx2 `.r3k2.plotregion1.added_text[1].xpos.val'
chk r3_bracket_fixed abs(`bx1'-`bx2') < 1e-6

* ---- 37. round 4: legend order(), endlabel with aspectratio(), dotsize(), horizontal bracket
* legend labels take the colour of the key beside them when order() reorders the keys
sysuse uslifeexp, clear
twoway line le le_male le_female year, legend(order(3 "F" 1 "All")) name(r4l, replace)
gpolish legend
local p1 `.r4l.plotregion1.plot1.style.line.color.rgb'
local p1 : list retokenize p1
local p3 `.r4l.plotregion1.plot3.style.line.color.rgb'
local p3 : list retokenize p3
local c `.r4l.legend.plotregion1.label[1].style.color.rgb'
local c : list retokenize c
chk r4_leg_order1 "`c'"=="`p3'" & 1
local c `.r4l.legend.plotregion1.label[2].style.color.rgb'
local c : list retokenize c
chk r4_leg_order2 "`c'"=="`p1'" & 1
* plots() names plot numbers, not legend slots
twoway line le le_male le_female year, legend(order(3 "F" 1 "All")) name(r4m, replace)
local s1 `.r4m.legend.plotregion1.label[1].style.color.rgb'
local s1 : list retokenize s1
gpolish legend, plots(1)
local c `.r4m.legend.plotregion1.label[2].style.color.rgb'
local c : list retokenize c
chk r4_leg_plots1 "`c'"=="`p1'" & 1
local c `.r4m.legend.plotregion1.label[1].style.color.rgb'
local c : list retokenize c
chk r4_leg_plots2 "`c'"=="`s1'" & 1
twoway line le le_male le_female year, legend(order(3 "F" 1 "All")) name(r4n, replace)
gpolish legend, plots(1 3)
local c `.r4n.legend.plotregion1.label[1].style.color.rgb'
local c : list retokenize c
chk r4_leg_plots13a "`c'"=="`p3'" & 1
local c `.r4n.legend.plotregion1.label[2].style.color.rgb'
local c : list retokenize c
chk r4_leg_plots13b "`c'"=="`p1'" & 1
* endlabel stops before any edit on aspectratio() with a y axis on the label side
twoway (line le year) (line le_wmale year, yaxis(2)), aspectratio(1) name(r4a, replace)
local m0 `.r4a.plotregion1.style.margin.right.val'
local m0 : list retokenize m0
capture gpolish endlabel
chk r4_aspect_rc _rc==198
ntext r4a added_text
chk r4_aspect_noedit r(all)==0
local m1 `.r4a.plotregion1.style.margin.right.val'
local m1 : list retokenize m1
chk r4_aspect_margin "`m1'"=="`m0'" & 1
* one y axis with aspectratio() still works
twoway (line le year) (line le_wmale year), aspectratio(1) name(r4b, replace)
capture gpolish endlabel
chk r4_aspect_1ax _rc==0
twoway (line le year) (line le_wmale year), aspectratio(1) name(r4c, replace)
capture gpolish endlabel, side(left)
chk r4_aspect_left _rc==198
ntext r4c added_text
chk r4_aspect_left_noedit r(all)==0
* dotsize() implies dots; dots(#) is no longer read as dotsize()
twoway line le year, name(r4d, replace)
gpolish endlabel, dotsize(8)
chk r4_dotsize_dots "`.r4d.plotregion1.added_markers.arrnels'"=="1"
* dotsize() at the default value still turns dots on; no dotsize() leaves them off
twoway line le year, name(r4f, replace)
gpolish endlabel, dotsize(5.5)
chk r4_dotsize_default_dots "`.r4f.plotregion1.added_markers.arrnels'"=="1"
twoway line le year, name(r4g, replace)
gpolish endlabel
chk r4_nodotsize_nodots "0`.r4g.plotregion1.added_markers.arrnels'"=="0" | "0`.r4g.plotregion1.added_markers.arrnels'"=="00"
twoway line le year, name(r4i, replace)
capture gpolish endlabel, dotsize(0)
chk r4_dotsize_zero _rc==198
twoway line le year, name(r4e, replace)
capture gpolish endlabel, dots(20)
chk r4_dots_num _rc==198
* horizontal bracket across two bars; label centred above, or below with below
sysuse auto, clear
collapse mpg, by(rep78)
twoway bar mpg rep78, name(r4h, replace)
gpolish bracket "p<.05", y(23) x0(2) x1(4)
chk r4_hbr_lines "`.r4h.plotregion1.added_lines.arrnels'"=="3"
chk r4_hbr_xmid abs(`.r4h.plotregion1.added_text[1].xpos.val' - 3) < 1e-6
chk r4_hbr_above `.r4h.plotregion1.added_text[1].ypos.val' > 23
gpolish bracket "n.s.", y(18.5) x0(3) x1(1+4) below
chk r4_hbr_below `.r4h.plotregion1.added_text[2].ypos.val' < 18.5
chk r4_hbr_lines2 "`.r4h.plotregion1.added_lines.arrnels'"=="6"
capture gpolish bracket "x", y(23) x0(2) y1(4)
chk r4_hbr_mix _rc==198
capture gpolish bracket "x", y(23) x0(2)
chk r4_hbr_partial _rc==198
capture gpolish bracket "x", y(23) x0(2) x1(2)
chk r4_hbr_same _rc==198
capture gpolish bracket "x", y(23) x0(2) x1(4) left
chk r4_hbr_left _rc==198
capture gpolish bracket "x", x(3) y0(20) y1(22) below
chk r4_vbr_below _rc==198
chk r4_hbr_nochange "`.r4h.plotregion1.added_lines.arrnels'"=="6"

* ---- r5: endlabel clears a plot-region outline; log-axis checks; bracket outside note --
sysuse uslifeexp, clear
line le_male year, scheme(s1mono) name(r5o, replace)
gpolish endlabel, values
gpolish geom, name(r5o)
local labx = r(xa) + r(xb)*`.r5o.plotregion1.added_text[1].xpos.val'
* the label starts at least gap() (4pt) beyond the outlined plot-region edge
chk r5_outline_gap `labx' >= r(gx1) + 4/72*r(gpi)
local valx = r(xa) + r(xb)*`.r5o.plotregion1.added_text[2].xpos.val'
chk r5_outline_val `valx' > `labx'
* default scheme: no outline, the label still sits beyond the line end
line le_male year, name(r5d, replace)
gpolish endlabel
gpolish geom, name(r5d)
chk r5_noout_gap r(xa) + r(xb)*`.r5d.plotregion1.added_text[1].xpos.val' > r(xa) + r(xb)*1999
sysuse auto, clear
scatter price mpg, yscale(log) name(r5l, replace)
capture gpolish bracket "zero", x(30) y0(0) y1(10000)
chk r5_log_bracket _rc==198
capture gpolish bracket "neg", y(-1) x0(20) x1(30)
chk r5_log_hbracket _rc==198
capture gpolish brace "neg", from(30 -5) to(30 10000)
chk r5_log_brace _rc==198
capture gpolish arrow, from(30 0) to(20 10000)
chk r5_log_arrow _rc==198
chk r5_log_nothing "`.r5l.plotregion1.added_lines.arrnels'"=="" | "`.r5l.plotregion1.added_lines.arrnels'"=="0"
gpolish bracket "ok", x(30) y0(5000) y1(10000)
chk r5_log_ok "`.r5l.plotregion1.added_lines.arrnels'"=="3"
scatter price weight, name(r5b, replace)
capture log close _r5b
tempfile r5lg
log using `"`r5lg'"', text name(_r5b) replace
gpolish bracket "hi", x(6000) y0(20) y1(30)
gpolish bracket "in", x(3000) y0(5000) y1(9000)
log close _r5b
local nn 0
local nr 0
tempname fh
file open `fh' using `"`r5lg'"', read text
file read `fh' line
while r(eof)==0 {
    if strpos(`"`macval(line)'"', "note: gpolish bracket") local ++nn
    if strpos(`"`macval(line)'"', "make roo") local ++nr
    file read `fh' line
}
file close `fh'
* only x(6000) is off the plot (y0() and y1() lie inside the y range): one note naming x()
chk r5_bracket_note `nn'==1
chk r5_bracket_hint `nr'==1
chk r5_bracket_drawn "`.r5b.plotregion1.added_lines.arrnels'"=="6"

* ---- r6. size checks, labels() count, clock-time positions, bracket notes ---
capture program drop logcount
* r(n) counts lines of log file f holding text s
program logcount, rclass
    args f s
    local n 0
    tempname fh
    file open `fh' using `"`f'"', read text
    file read `fh' line
    while r(eof)==0 {
        if strpos(`"`macval(line)'"', `"`s'"') local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar n = `n'
end
sysuse uslifeexp, clear
twoway line le le_male le_female year, name(r6e, replace)
capture gpolish endlabel, size(-2)
chk r6_endlabel_negsize _rc==198
capture gpolish endlabel, size(0)
chk r6_endlabel_zerosize _rc==198
capture gpolish endlabel, wrap(-3)
chk r6_endlabel_negwrap _rc==198
capture gpolish endlabel, values format(abc)
chk r6_endlabel_badformat _rc==198
chk r6_endlabel_untouched "`.r6e.plotregion1.added_text.arrnels'"=="" | "`.r6e.plotregion1.added_text.arrnels'"=="0"
capture log close _r6
tempfile r6lg
log using `"`r6lg'"', text name(_r6) replace
gpolish endlabel, labels("only one")
log close _r6
logcount `"`r6lg'"' "labels() has 1 entries for 3 plots"
chk r6_labels_few_note r(n)==1
ntext r6e added_text
chk r6_labels_few_drawn r(k)==3
twoway line le_male le_female year, name(r6f, replace)
log using `"`r6lg'"', text name(_r6) replace
gpolish endlabel, labels("a" "b" "c")
log close _r6
logcount `"`r6lg'"' "labels() has 3 entries for 2 plots"
chk r6_labels_many_note r(n)==1
twoway line le_male le_female year, name(r6g, replace)
log using `"`r6lg'"', text name(_r6) replace
gpolish endlabel, labels("a" "b")
log close _r6
logcount `"`r6lg'"' "labels() has"
chk r6_labels_match_quiet r(n)==0
sysuse auto, clear
scatter price mpg, name(r6p, replace)
capture gpolish ptlabel make if price>13000, x(mpg) y(price) size(-1)
chk r6_ptlabel_negsize _rc==198
capture gpolish ptlabel make if price>13000, x(mpg) y(price) offset(-1)
chk r6_ptlabel_negoffset _rc==198
capture gpolish callout "Hi", to(20 10000) size(-3)
chk r6_callout_negsize _rc==198
capture gpolish note "Hi", at(20 10000) size(0)
chk r6_note_zerosize _rc==198
capture gpolish callout "Hi", to(20 10000) headsize(-1)
chk r6_callout_neghead _rc==198
capture gpolish callout "Hi", to(20 10000) pad(-1)
chk r6_callout_negpad _rc==198
capture gpolish arrow, from(20 10000) to(25 8000) headsize(0)
chk r6_arrow_zerohead _rc==198
capture gpolish brace "b", from(20 5000) to(20 9000) size(-1)
chk r6_brace_negsize _rc==198
capture gpolish bracket "b", x(30) y0(5000) y1(10000) size(-1)
chk r6_bracket_negsize _rc==198
chk r6_nothing_added "`.r6p.plotregion1.added_text.arrnels'"=="" | "`.r6p.plotregion1.added_text.arrnels'"=="0"
* a %tc position written as the standard literal, with a space inside the parentheses
clear
set obs 48
gen double t = tc(01jan2020 00:00:00) + (_n-1)*3600000
format t %tc
gen y = sin(_n/5)
line y t, name(r6t, replace)
capture noisily gpolish callout "Hour 30", to(tc(02jan2020 05:00:00) 0) at(tc(01jan2020 12:00:00) 0.5)
chk r6_tc_space _rc==0
ntext r6t added_text
chk r6_tc_drawn r(k)==1
capture gpolish callout "x", to(tc(02jan2020 05:00:00) 0 1)
chk r6_tc_three _rc==198
capture gpolish callout "x", to(1 2 3)
chk r6_xy_three _rc==198
* bracket: only the option that is off the plot is named
clear
input grp mean
1 3
2 5
3 4.2
end
twoway bar mean grp, name(r6b, replace)
log using `"`r6lg'"', text name(_r6) replace
gpolish bracket "p<0.01", x0(1) x1(2) y(5.6)
log close _r6
logcount `"`r6lg'"' "y() lies outside"
chk r6_bracket_y_named r(n)==1
logcount `"`r6lg'"' "x0() lies outside"
local n0 = r(n)
logcount `"`r6lg'"' "x1() lies outside"
chk r6_bracket_ends_quiet `n0'==0 & r(n)==0
logcount `"`r6lg'"' "yscale(range(5.6))"
chk r6_bracket_hint_value r(n)==1

* ---- r7. endlabel quotes and apostrophes, side(left) tick room, note box past the edge ---
tempfile r7lg
sysuse uslifeexp, clear
label var le_male `"Men "all" $5 50%"'
label var le_female "Women's {x}"
line le_male le_female year, name(r7a, replace)
log using `"`r7lg'"', text name(_r7) replace
capture noisily gpolish endlabel
local rc1 = _rc
* a second run undoes the first; its record check reads the label with the apostrophe
capture noisily gpolish endlabel
local rc2 = _rc
log close _r7
chk r7_quote_label_rc `rc1'==0 & `rc2'==0
logcount `"`r7lg'"' "too few quotes"
chk r7_quote_label_quiet r(n)==0
local found 0
local nt `.r7a.plotregion1.added_text.arrnels'
forvalues k = 1/`nt' {
    if "`.r7a.plotregion1.added_text[`k'].draw_view.setting'"=="no" continue
    local t `"`.r7a.plotregion1.added_text[`k'].text[1]'"'
    if strpos(`"`t'"', `""all""') local ++found
}
chk r7_quote_label_kept `found'==1
ntext r7a added_text
chk r7_quote_label_two r(k)==2
* labels() with an entry in compound quotes
line le_male le_female year, name(r7b, replace)
log using `"`r7lg'"', text name(_r7) replace
capture noisily gpolish endlabel, labels(`"Men "M""' "Women's")
local rc1 = _rc
log close _r7
chk r7_labels_quote_rc `rc1'==0
logcount `"`r7lg'"' "too few quotes"
chk r7_labels_quote_quiet r(n)==0
chk r7_labels_quote_text strpos(`"`.r7b.plotregion1.added_text[1].text[1]'"', `""M""')>0
chk r7_labels_apostrophe strpos(`"`.r7b.plotregion1.added_text[2].text[1]'"', "Women's")>0
* side(left) with the legend switched off keeps room for the last x tick label
foreach fmt in comma tm {
    sysuse uslifeexp, clear
    if "`fmt'"=="tm" {
        replace year = tm(2015m1) + year - 1900
        format year %tm
        line le_male le_female year, xlabel(, labsize(large)) name(r7c, replace)
    }
    else line le_male le_female year, xlabel(1900(20)2000, format(%9.0fc) labsize(large)) xscale(range(1900 2000)) name(r7c, replace)
    gr_draw r7c
    local gw `.r7c.gdi_x1'
    local room0 = `gw' - max(`.r7c.plotregion1.gdi_x0', `.r7c.plotregion1.gdi_x1')
    gpolish endlabel, side(left)
    gr_draw r7c
    quietly graph describe r7c
    local gpi = `.r7c.gdi_y1'/real("`r(ysize)'")
    local tl = max(`.r7c.xaxis1.major.dlg_tickpos.arrnels', 1)
    local tt `"`.r7c.xaxis1.major.dlg_ticklabel[`tl']'"'
    local tsz = `.r7c.xaxis1.style.majorstyle.tickstyle.textstyle.size.val'
    * a lower bound on half the last tick label (0.3 em per character), in device units; without the margin the room is near 0
    local need = 0.5*0.3*strlen(`"`tt'"')*`tsz'/(100/(72*min(real("`r(xsize)'"), real("`r(ysize)'"))))/72*`gpi'
    local room1 = `gw' - max(`.r7c.plotregion1.gdi_x0', `.r7c.plotregion1.gdi_x1')
    chk r7_left_tick_room_`fmt' `room1' >= `need'
    gpolish clear
    gr_draw r7c
    local room2 = `gw' - max(`.r7c.plotregion1.gdi_x0', `.r7c.plotregion1.gdi_x1')
    chk r7_left_tick_clear_`fmt' abs(`room2' - `room0') < 1
}
* a note box placed with at() that runs past the right edge gets a note
sysuse auto, clear
scatter price mpg, name(r7d, replace)
log using `"`r7lg'"', text name(_r7) replace
gpolish note `"A "quoted" note"' "line 2", at(39.5 14000)
gpolish note "inside", at(20 14000)
log close _r7
logcount `"`r7lg'"' "runs past the right edge of the graph"
chk r7_note_edge_once r(n)==1
logcount `"`r7lg'"' "use align(right)"
chk r7_note_edge_hint r(n)==1
scatter price mpg, name(r7e, replace)
log using `"`r7lg'"', text name(_r7) replace
gpolish note "a much longer note that sits on the left side", at(12 14000) align(right)
log close _r7
logcount `"`r7lg'"' "runs past the left edge of the graph"
chk r7_note_edge_left r(n)==1

* ---- r8. kept legend beside end labels, legend plots() range, ptlabel on drawn points only ----
capture program drop r8gap
program r8gap, rclass
    args g
    gr_draw `g'
    return scalar gap = `.`g'.legend.gdi_x0' - `.`g'.plotregion1.gdi_x1'
end
capture program drop r8rec
program r8rec, rclass
    args g
    local k `.`g'.plotregion1.added_text.arrnels'
    local rec
    forvalues j = 1/`k' {
        local t `"`.`g'.plotregion1.added_text[`j'].text[1]'"'
        if substr(`"`t'"', 1, 17)=="gpolish-endlabel|" local rec `"`t'"'
    }
    * the last field is the legend margin
    local lm = substr(`"`rec'"', strrpos(`"`rec'"', "|")+1, .)
    return local lm `"`lm'"'
end
sysuse auto, clear
* a right-hand legend kept because two plots share a label moves out past the labels
scatter price mpg || lfit price mpg || qfit price mpg, legend(position(3) cols(1)) name(r8a, replace)
r8gap r8a
local gap0 = r(gap)
gpolish endlabel
r8rec r8a
chk r8_dup_legend_recorded "`r(lm)'"!=""
r8gap r8a
local gap1 = r(gap)
chk r8_dup_legend_moved `gap1' > `gap0' + 1000
chk r8_dup_legend_shown "`.r8a.legend.draw_view.setting'"=="yes"
gpolish clear
r8gap r8a
chk r8_dup_legend_back abs(r(gap) - `gap0') < 1
* an explicit keeplegend does the same
scatter price mpg || lfit price mpg || qfit price mpg, legend(position(3) cols(1)) name(r8b, replace)
gpolish endlabel, keeplegend labels("Linear" "Quad")
r8rec r8b
chk r8_keep_legend_recorded "`r(lm)'"!=""
r8gap r8b
local gapk = r(gap)
chk r8_keep_legend_moved `gapk' > `gap0' + 1000
* a rerun undoes the move before it makes its own, so the gap does not grow
gpolish endlabel, keeplegend labels("Linear" "Quad")
r8gap r8b
local gapb = r(gap)
chk r8_keep_legend_rerun abs(`gapb' - `gapk') < 1
* a legend below the plot is left where it is
scatter price mpg || lfit price mpg || qfit price mpg, legend(position(6)) name(r8c, replace)
gpolish endlabel, keeplegend labels("Linear" "Quad")
r8rec r8c
chk r8_bottom_legend_unmoved "`r(lm)'"==""
* legend, plots() checks the plot numbers as endlabel does
twoway line price mpg || line weight mpg, sort name(r8d, replace)
capture gpolish legend, plots(7)
chk r8_legend_plots_range _rc==198
capture gpolish legend, plots(2)
chk r8_legend_plots_ok _rc==0
* ptlabel labels only the points the graph draws
scatter price mpg if foreign, name(r8e, replace)
tempfile r8lg
log using `"`r8lg'"', text name(_r8) replace
gpolish ptlabel make if price>6000, x(mpg) y(price)
log close _r8
quietly count if foreign & price>6000
local nf = r(N)
ntext r8e added_text
chk r8_ptlabel_drawn_only r(k)==`nf'
logcount `"`r8lg'"' "are not drawn in the graph"
chk r8_ptlabel_undrawn_note r(n)==1
* undrawn keeps the selected points inside the plot region
scatter price mpg if foreign, name(r8f, replace)
gpolish ptlabel make if price>6000, x(mpg) y(price) undrawn
ntext r8f added_text
chk r8_ptlabel_undrawn_opt r(k) > `nf'
* a graph that draws every observation gets every label and no note
scatter price mpg, name(r8g, replace)
log using `"`r8lg'"', text name(_r8) replace
gpolish ptlabel make if price>12000, x(mpg) y(price)
log close _r8
quietly count if price>12000
local na = r(N)
ntext r8g added_text
chk r8_ptlabel_all_drawn r(k)==`na'
logcount `"`r8lg'"' "are not drawn in the graph"
chk r8_ptlabel_no_note r(n)==0
* the data in memory are unchanged
chk r8_ptlabel_data_kept _N==74

* x() and y() left out: read from the one scatter plot
scatter price mpg, name(r9a, replace)
gpolish ptlabel make if price>12000
quietly count if price>12000
local na = r(N)
ntext r9a added_text
chk r9_ptlabel_infer r(k)==`na'
* same labels as with x() and y() given
scatter price mpg, name(r9b, replace)
gpolish ptlabel make if price>12000, x(mpg) y(price)
chk r9_ptlabel_infer_same `"`.r9a.plotregion1.added_text[1].text[1]'"'==`"`.r9b.plotregion1.added_text[1].text[1]'"'
* connected plot also qualifies; y() alone is filled in
sort mpg
twoway connected price mpg, name(r9c, replace)
capture noisily gpolish ptlabel make if price>12000, y(price)
chk r9_ptlabel_infer_connected _rc==0
* two scatter plots: cannot infer
twoway scatter price mpg || scatter price weight, name(r9d, replace)
capture noisily gpolish ptlabel make if price>12000
chk r9_ptlabel_two_plots _rc==198
* given y() picks one of the two? both draw price, still two: error
capture noisily gpolish ptlabel make if price>12000, y(price)
chk r9_ptlabel_two_plots_y _rc==198
* x() given narrows two plots to one
capture noisily gpolish ptlabel make if price>12000, x(weight)
chk r9_ptlabel_x_narrows _rc==0
* a line plot draws no markers: cannot infer
twoway line price mpg, name(r9e, replace)
capture noisily gpolish ptlabel make if price>12000
chk r9_ptlabel_line_err _rc==198
* variables not in memory: cannot infer
preserve
gen double zz = price
scatter zz mpg, name(r9f, replace)
drop zz
capture noisily gpolish ptlabel make if price>12000
chk r9_ptlabel_novar_err _rc==198
restore

* ---- r10. round 10 fixes ---------------------------------------------------------
* a wrapped top label pulled back from the top edge pushes the label below it down
clear
set obs 10
gen t = _n
gen a = t
gen b = 0.8*t
line a b t, scheme(s2color) name(r10a, replace)
shownote "pair(s)" gpolish endlabel, wrap(5) labels("x y z w v u t s r q p" "Men")
chk r10_wraptop_nonote r(note)==0
gpolish geom, name(r10a)
local dd = (`.r10a.plotregion1.added_text[1].ypos.val' - `.r10a.plotregion1.added_text[3].ypos.val')*r(yb)/(9.5/72*r(gpi))
chk r10_wraptop_gap abs(`dd' - 2.5*1.3) < 0.01
if c(stata_version) >= 18 {
    sysuse uslifeexp, clear
    line le_male le_female year, scheme(stcolor) name(r10b, replace)
    shownote "pair(s)" gpolish endlabel, wrap(5) labels("Men" "x y z w v u t s r q p")
    chk r10_stcolor_nonote r(note)==0
    gpolish geom, name(r10b)
    local dd = (`.r10b.plotregion1.added_text[3].ypos.val' - `.r10b.plotregion1.added_text[1].ypos.val')*r(yb)/(9.5/72*r(gpi))
    chk r10_stcolor_gap `dd' >= 2.5*1.3 - 0.01
}
* an unlabelled plot with a legend key is named when the legend is switched off
sysuse uslifeexp, clear
twoway rarea le_wmale le_bmale year || line le_female year || lfit le_male year, scheme(s2color) name(r10c, replace)
shownote "plot(s) 1 get no end label and lose their legend key" gpolish endlabel
chk r10_lostkey_note r(note)==1
twoway rarea le_wmale le_bmale year || line le_female year, name(r10d, replace)
shownote "lose their legend key" gpolish endlabel, keeplegend
chk r10_lostkey_keep r(note)==0
line le_male le_female year, name(r10e, replace)
shownote "lose their legend key" gpolish endlabel
chk r10_lostkey_none r(note)==0
* brace width() and arrow shrink() are checked like the other sizes
line le_male le_female year, name(r10f, replace)
capture gpolish brace "x", from(1950 60) to(1970 60) width(-20)
chk r10_brace_negwidth _rc==198
capture gpolish brace "x", from(1950 60) to(1970 60) width(0)
chk r10_brace_zerowidth _rc==198
capture gpolish arrow, from(1950 60) to(1970 60) shrink(-2)
chk r10_arrow_negshrink _rc==198
capture gpolish arrow, from(1950 60) to(1970 60) shrink(0)
chk r10_arrow_zeroshrink _rc==0
* a date typed as the axis shows it gets a hint toward the date functions
gen tm = tm(2015m1) + _n
format tm %tm
line le_male tm, name(r10g, replace)
shownote "use a date function, e.g. tm(2020m8)" capture noisily gpolish callout "peak", to(2020m8 1)
chk r10_date_hint r(note)==1
capture gpolish callout "peak", to(2020m8 1)
chk r10_date_rc _rc==198
capture gpolish callout "peak", to(tm(2020m8) 60)
chk r10_date_fn _rc==0

* ---- r11: align() takes only left, right, center (centre) and their abbreviations; bracket tick() > 0
sysuse auto, clear
foreach a in right r center centre c left l junk q {
    scatter price mpg, name(r11a, replace)
    capture noisily gpolish note "Box", at(25 10000) align(`a')
    local rc_`a' = _rc
    if _rc local x_`a' none
    else local x_`a' `.r11a.plotregion1.added_text[1].style.horizontal.setting'
}
chk r11_align_junk `rc_junk'==198
chk r11_align_q `rc_q'==198
foreach a in right r center centre c left l {
    chk r11_align_ok_`a' `rc_`a''==0
}
* the text style records the normalised alignment
foreach a in right r {
    chk r11_align_h_`a' "`x_`a''"=="right"
}
foreach a in center centre c {
    chk r11_align_h_`a' "`x_`a''"=="center"
}
foreach a in left l {
    chk r11_align_h_`a' "`x_`a''"=="left"
}
scatter price mpg, name(r11a, replace)
capture gpolish callout "Box", at(25 10000) to(30 12000) align(junk)
chk r11_callout_align _rc==198
scatter price mpg, name(r11b, replace)
capture noisily gpolish bracket "neg tick", x(30) y0(5000) y1(10000) tick(-8)
chk r11_bracket_negtick _rc==198
capture gpolish bracket "zero tick", x(30) y0(5000) y1(10000) tick(0)
chk r11_bracket_zerotick _rc==198
capture gpolish bracket "pos tick", x(30) y0(5000) y1(10000) tick(8)
chk r11_bracket_postick _rc==0

* ---- r12: endlabel on the right keeps the last x tick label of a clock-time axis in the graph
clear
set obs 24
gen double tt = tc(01jan2020 00:00:00) + (_n-1)*3600000
format tt %tc
gen y1 = sin(_n/3)
gen y2 = cos(_n/3)
* a small right graph margin, so the overhang shows under every scheme
line y1 y2 tt, name(r12a, replace) graphregion(margin(r=1))
local gm0 `.r12a.style.margin.gright.val'
gpolish endlabel, name(r12a)
local rec
local nt `.r12a.plotregion1.added_text.arrnels'
forvalues k = 1/`nt' {
    if substr(`"`.r12a.plotregion1.added_text[`k'].text[1]'"', 1, 17)=="gpolish-endlabel|" local rec `"`.r12a.plotregion1.added_text[`k'].text[1]'"'
}
* field 9 of the record holds the right margin added for the tick label
local rm = ustrregexra(`"`rec'"', "^([^|]*[|]){8}([^|]*).*$", "$2")
chk r12_tick_rm "`rm'"!="" & real("`rm'")>0
gpolish clear, name(r12a)
chk r12_tick_clear abs(`.r12a.style.margin.gright.val' - `gm0') < 1e-6
* a year axis with long labels needs no extra margin
sysuse uslifeexp, clear
label var le_male "Men in the United States"
label var le_female "Women in the United States"
line le_male le_female year, name(r12b, replace)
gpolish endlabel, name(r12b)
local nt `.r12b.plotregion1.added_text.arrnels'
local rec
forvalues k = 1/`nt' {
    if substr(`"`.r12b.plotregion1.added_text[`k'].text[1]'"', 1, 17)=="gpolish-endlabel|" local rec `"`.r12b.plotregion1.added_text[`k'].text[1]'"'
}
local rm = ustrregexra(`"`rec'"', "^([^|]*[|]){8}([^|]*).*$", "$2")
chk r12_tick_norm "`rm'"==""

* ---- r13: endlabel after gpolish legend uses the plain legend text (no literal {bf: markup)
sysuse uslifeexp, clear
twoway line le_male le_female year, name(r13a, replace)
gpolish legend, name(r13a)
gpolish endlabel, wrap(15) name(r13a)
local nt `.r13a.plotregion1.added_text.arrnels'
local nbad 0
local nlab 0
forvalues k = 1/`nt' {
    local nl `.r13a.plotregion1.added_text[`k'].text.arrnels'
    forvalues q = 1/`nl' {
        local s `"`.r13a.plotregion1.added_text[`k'].text[`q']'"'
        if substr(`"`s'"',1,17)=="gpolish-endlabel|" continue
        local ++nlab
        * a line that opens {bf: must close it on the same line
        if strpos(`"`s'"',"{bf:") & substr(`"`s'"',-1,1)!="}" local ++nbad
        if strpos(`"`s'"',"{bf:{bf:") local ++nbad
        if !strpos(`"`s'"',"{bf:") & strpos(`"`s'"',"}") local ++nbad
    }
}
chk r13_legwrap_lines `nlab' >= 4
chk r13_legwrap_markup `nbad'==0
twoway line le_male le_female year, name(r13b, replace)
gpolish legend, name(r13b)
gpolish endlabel, nobold name(r13b)
local nt `.r13b.plotregion1.added_text.arrnels'
local nbf 0
local nlab 0
forvalues k = 1/`nt' {
    local s `"`.r13b.plotregion1.added_text[`k'].text[1]'"'
    if substr(`"`s'"',1,17)=="gpolish-endlabel|" continue
    if `"`.r13b.plotregion1.added_text[`k'].draw_view.setting'"'=="no" continue
    local ++nlab
    if strpos(`"`s'"',"{bf:") local ++nbf
}
chk r13_legnobold_n `nlab'==2
chk r13_legnobold `nbf'==0
* ---- r13: automatic callout placement and ptlabel avoid text drawn by mlabel()
sysuse auto, clear
gen lab = make + " (a long label)" if price>11000
scatter price mpg, mlabel(lab) mlabsize(small) name(r13c, replace)
gpolish callout "Expensive cars" "cluster here", to(14 13000) name(r13c)
gpolish geom, name(r13c)
local gpi = r(gpi)
local gprel = r(gpi)/72/r(relperpt)
local xa = r(xa)
local xb = r(xb)
local ya = r(ya)
local yb = r(yb)
* the callout box: anchored at its xpos/ypos, about 0.55 em per character, 2 lines
local k `.r13c.plotregion1.added_text.arrnels'
local cx = `xa' + `xb'*`.r13c.plotregion1.added_text[`k'].xpos.val'
local cy = `ya' + `yb'*`.r13c.plotregion1.added_text[`k'].ypos.val'
local csz `.r13c.plotregion1.added_text[`k'].style.size.gmval'
local cw = 14*0.55*`csz'*`gprel'
local ch = 2*1.3*`csz'*`gprel'
local cba `.r13c.plotregion1.added_text[`k'].style.box_alignment.setting'
local cx0 = `cx' - `cw'/2
if "`cba'"=="east" local cx0 = `cx'
if "`cba'"=="west" local cx0 = `cx' - `cw'
local cy0 = `cy' - `ch'/2
if "`cba'"=="north" local cy0 = `cy'
if "`cba'"=="south" local cy0 = `cy' - `ch'
* each marker label: clock 3, starting just right of the marker, 0.55 em per character
local lsz `.r13c.plotregion1.plot1.style.label.textstyle.size.gmval'
local hit 0
forvalues i = 1/`=_N' {
    if lab[`i']=="" continue
    local mx = `xa' + `xb'*mpg[`i']
    local my = `ya' + `yb'*price[`i']
    local lw = ustrlen(lab[`i'])*0.55*`lsz'*`gprel'
    local lh = 1.3*`lsz'*`gprel'
    local ox = min(`cx0'+`cw', `mx'+`lw') - max(`cx0', `mx')
    local oy = min(`cy0'+`ch', `my'+`lh'/2) - max(`cy0', `my'-`lh'/2)
    if `ox' > 0 & `oy' > 0 local ++hit
}
chk r13_callout_mlabel `hit'==0
* ptlabel on a point whose mlabel() text is already drawn moves its label off that text
gen lab2 = "Concord" in 1
scatter price mpg in 1/20, mlabel(lab2) name(r13d, replace)
gpolish ptlabel make in 1, name(r13d)
gpolish geom, name(r13d)
local k `.r13d.plotregion1.added_text.arrnels'
local px = r(xa) + r(xb)*mpg[1]
local py = r(ya) + r(yb)*price[1]
local tx = r(xa) + r(xb)*`.r13d.plotregion1.added_text[`k'].xpos.val'
local ty = r(ya) + r(yb)*`.r13d.plotregion1.added_text[`k'].ypos.val'
local ba `.r13d.plotregion1.added_text[`k'].style.box_alignment.setting'
* clock 3 puts the mlabel to the right of the point at its height; the gpolish label must not
* start at that same spot
local onml = ("`ba'"=="east") & abs(`ty'-`py') < 0.5*1.3*`.r13d.plotregion1.added_text[`k'].style.size.gmval'*r(gpi)/72/r(relperpt) & `tx' > `px'
chk r13_ptlabel_mlabel `onml'==0

gpolish limits

if `"`_wf0'"'!="" graph set window fontface `"`_wf0'"'
else graph set window fontface default
di as res _n "gpolish battery: $NCHK checks passed (Stata `c(stata_version)')"
