*! gpolish 0.7.0  18nov2026  post-hoc polish + layout layer for Stata graphs
*! gpolish [style] | endlabel | callout | note | arrow | brace | bracket | ptlabel | legend | clear | render | limits | geom
*! Requires Stata 16+. Uses undocumented graph-object members and gr_edit.
program gpolish
    version 16
    * $ and literal backticks in label text would be expanded again by gr_edit;
    * store them as SMCL character codes, which graph text renders literally
    mata: st_local("0", _gpl_esc(st_local("0")))
    gettoken sub rest : 0, parse(" ,")
    local subs endlabel callout note arrow brace bracket ptlabel legend clear render limits geom style
    mata: st_local("known", strofreal(anyof(tokens(st_local("subs")), st_local("sub"))))
    if `"`sub'"'!="" & `"`sub'"'!="," & !`known' {
        di as err `"gpolish: unknown subcommand {bf:`sub'}"'
        di as err "  valid subcommands: style endlabel callout note arrow brace bracket ptlabel legend clear render limits geom"
        exit 199
    }
    * gpolish is not r-class: the caller's r() is held and given back at the end. Until then it
    * stays readable, so at(), to() and from() may use it, for example to(1999 r(max))
    local keepr = !inlist("`sub'", "geom", "render")
    tempname rhold
    if `keepr' {
        _return hold `rhold'
        _return restore `rhold', hold
        global GPL_RHOLD `rhold'
    }
    if "`sub'"=="endlabel"      capture noisily _gpl_endlabel `rest'
    else if "`sub'"=="callout"  capture noisily _gpl_callout `rest'
    else if "`sub'"=="note"     capture noisily _gpl_callout `rest' isnote
    else if "`sub'"=="arrow"    capture noisily _gpl_arrow `rest'
    else if "`sub'"=="brace"    capture noisily _gpl_brace `rest'
    else if "`sub'"=="bracket"  capture noisily _gpl_bracket `rest'
    else if "`sub'"=="ptlabel"  capture noisily _gpl_ptlabel `rest'
    else if "`sub'"=="legend"   capture noisily _gpl_legend `rest'
    else if "`sub'"=="clear"    capture noisily _gpl_clear `rest'
    else if "`sub'"=="render"   capture noisily _gpl_render `rest'
    else if "`sub'"=="limits"   capture noisily _gpl_limits `rest'
    else if "`sub'"=="geom"     capture noisily _gpl_geomuser `rest'
    else if "`sub'"=="style"    capture noisily _gpl_style `rest'
    else                        capture noisily _gpl_style `0'
    local rc = _rc
    * edits are recorded without redrawing; the finished graph is drawn once here
    if !`rc' & !inlist("`sub'", "render", "limits", "geom") capture gr_draw
    if `keepr' {
        global GPL_RHOLD
        _return restore `rhold'
    }
    exit `rc'
end

* ================================================================ utilities
program _gpl_name, rclass
    args name
    if "`name'"=="" {
        capture quietly graph describe
        if _rc {
            di as err "gpolish: no graph in memory"
            exit 111
        }
        local name `r(fn)'
    }
    capture local fam `.`name'.graphfamily'
    if "`fam'"=="" {
        di as err "gpolish: graph {bf:`name'} not found in memory"
        exit 111
    }
    * a pie chart reports the bar family; gr2mpl cannot redraw it either
    if "`.`name'.classname'"=="piegraph_g" local fam pie
    if "`fam'"!="twoway" {
        di as err "gpolish: graph `name' is a `fam' graph; the layout commands support twoway graphs only."
        if inlist("`fam'", "bar", "by", "combine", "matrix") di as err "         {bf:gpolish render} (gr2mpl) can redraw this `fam' graph in the same style."
        exit 198
    }
    quietly graph display `name'
    _gpl_font
    return local name `name'
end

* the font Stata exports with decides the width table. With a graph window, PNG export uses
* graph set window fontface; in batch or console mode there is no window and Stata exports
* with graph set svg fontface. A global GPOLISH_FONT set by the user overrides both.
program _gpl_font
    if `"$GPOLISH_FONT"'!="" {
        global GPL_FONT = lower(`"$GPOLISH_FONT"')
    }
    else {
        local src window
        if "`c(mode)'"=="batch" | "`c(console)'"=="console" local src svg
        local ff
        * clear r() first, so a value left by an earlier command cannot be mistaken for the font
        mata: st_rclear()
        capture quietly graph set `src'
        if !_rc local ff `"`r(fontface)'"'
        if `"`ff'"'!="" global GPL_FONT = lower(`"`ff'"')
        else {
            global GPL_FONT "helvetica"
            if "$GPL_FONTWARNED"!="(unread)" {
                di as txt "note: gpolish cannot read the graph font (graph set `src'); label spacing assumes Helvetica."
                di as txt `"      Set {bf:global GPOLISH_FONT "Open Sans"} (or the font your exports use) to match it."'
                global GPL_FONTWARNED "(unread)"
            }
        }
    }
    mata: st_local("known", strofreal(_gpl_fontknown("$GPL_FONT")))
    if !`known' & "$GPL_FONTWARNED"!="$GPL_FONT" {
        di as txt "note: gpolish has no width table for font {bf:$GPL_FONT}; using Arial metrics, so label spacing is approximate."
        global GPL_FONTWARNED "$GPL_FONT"
    }
end

* region(#) reads plot region # instead of the first; a plot on a second axis is drawn in its own
* plot region, with its own data-to-device transform
program _gpl_geom, rclass
    syntax [, name(string) REGion(integer 1)]
    if "`name'"=="" {
        quietly graph describe
        local name `r(fn)'
    }
    quietly graph describe `name'
    local xs = real("`r(xsize)'")
    local ys = real("`r(ysize)'")
    if missing(`xs') | missing(`ys') | `xs'==0 | `ys'==0 {
        local xs 5.5
        local ys 4
    }
    local pr .`name'.plotregion`region'
    return scalar xsize = `xs'
    return scalar ysize = `ys'
    return scalar gpi = `.`name'.gdi_y1'/`ys'
    return scalar relperpt = 100/(72*min(`xs',`ys'))
    return scalar xa = ``pr'.drawn_xalpha'
    return scalar xb = ``pr'.drawn_xbeta'
    return scalar ya = ``pr'.drawn_yalpha'
    return scalar yb = ``pr'.drawn_ybeta'
    return scalar gy0 = min(``pr'.gdi_y0', ``pr'.gdi_y1')
    return scalar gy1 = max(``pr'.gdi_y0', ``pr'.gdi_y1')
    return scalar gx0 = min(``pr'.gdi_x0', ``pr'.gdi_x1')
    return scalar gx1 = max(``pr'.gdi_x0', ``pr'.gdi_x1')
    return scalar xlog = ("``pr'.xscale.transform.setting'"=="log")
    return scalar ylog = ("``pr'.yscale.transform.setting'"=="log")
    return local name `name'
end

* evaluate an x y pair; each may be a number or an expression without spaces, e.g. td(01sep2001).
* Results come back in the caller's locals <opt>x and <opt>y. The caller's r() is put back first,
* so an expression may read it, e.g. to(1999 r(max)).
program _gpl_xy
    args opt val
    tokenize `"`val'"'
    if `"`2'"'=="" | `"`3'"'!="" {
        di as err "gpolish: `opt'() needs two values, x and y, for example `opt'(1990 45) or `opt'(td(01sep2001) 1000);"
        di as err "         write each value without spaces"
        exit 198
    }
    if "$GPL_RHOLD"!="" capture _return restore $GPL_RHOLD, hold
    forvalues i = 1/2 {
        capture local v`i' = ``i''
        if _rc | missing(real("`v`i''")) {
            di as err `"gpolish: `opt'(): cannot read {bf:``i''} as a number or expression"'
            exit 198
        }
    }
    c_local `opt'x `v1'
    c_local `opt'y `v2'
end

* evaluate one value the same way; the result comes back in the caller's local <opt>v
program _gpl_val
    args opt val
    if `"`val'"'=="" exit
    if "$GPL_RHOLD"!="" capture _return restore $GPL_RHOLD, hold
    capture local v = `val'
    if _rc | missing(real("`v'")) {
        di as err `"gpolish: `opt'(): cannot read {bf:`val'} as a number or expression"'
        exit 198
    }
    c_local `opt'v `v'
end

* how many plots the graph has, and the plot region that holds each (plots on a second
* axis are drawn in their own region); r(n), r(regs) = region of plot 1, 2, ...
program _gpl_plots, rclass
    args name
    local n `.`name'.n_views'
    if "`n'"=="" {
        local n 0
        while "`.`name'.plotregion1.plot`=`n'+1'.isa'"!="" {
            local ++n
        }
    }
    local npr `.`name'.n_plotregions'
    if "`npr'"=="" local npr 1
    local regs
    forvalues i = 1/`n' {
        local r 1
        forvalues j = 1/`npr' {
            if "`.`name'.plotregion`j'.plot`i'.isa'"!="" local r `j'
        }
        local regs `regs' `r'
    }
    return scalar n = `n'
    return scalar npr = `npr'
    return local regs `regs'
end

* the axes of each plot region: .y_scales and .x_scales hold one quoted entry per plot region,
* each the list of axes that region carries ("2 1" for a plot drawn with yaxis(1 2)).
* r(npr); r(y#) and r(x#) = the y and x axes of plot region #
program _gpl_regaxes, rclass
    args name
    local npr `.`name'.n_plotregions'
    if "`npr'"=="" local npr 1
    local ysc `"`.`name'.y_scales'"'
    local xsc `"`.`name'.x_scales'"'
    foreach d in y x {
        local j 0
        foreach s of local `d'sc {
            local ++j
            local `d'`j' `s'
        }
    }
    forvalues j = 1/`npr' {
        if "`y`j''"=="" local y`j' 1
        if "`x`j''"=="" local x`j' 1
        return local y`j' `y`j''
        return local x`j' `x`j''
    }
    return scalar npr = `npr'
end

* the plot region that carries x axis # and y axis # (either may be empty); r(region)
program _gpl_axregion, rclass
    args name xax yax
    local found 1
    if "`xax'`yax'"!="" {
        _gpl_regaxes `name'
        local npr = r(npr)
        local found 0
        forvalues j = 1/`npr' {
            local yd `r(y`j')'
            local xd `r(x`j')'
            local yok : list yax in yd
            local xok : list xax in xd
            if ("`yax'"=="" | `yok') & ("`xax'"=="" | `xok') {
                local found `j'
                continue, break
            }
        }
    }
    if !`found' {
        local what = trim(cond("`xax'"!="", "xaxis(`xax')", "") + " " + cond("`yax'"!="", "yaxis(`yax')", ""))
        di as err "gpolish: graph {bf:`name'} has no plot on `what'"
        exit 198
    }
    return scalar region = `found'
end

* convert a point from the data units of plot region `reg' to those of plot region 1, where
* gpolish adds its objects; the result comes back in the caller's locals <p>x and <p>y
program _gpl_toreg1
    args name reg p x y
    if "`reg'"=="1" | "`reg'"=="" exit
    _gpl_geom, name(`name') region(`reg')
    local gx = r(xa) + r(xb)*cond(r(xlog), ln(`x'), `x')
    local gy = r(ya) + r(yb)*cond(r(ylog), ln(`y'), `y')
    _gpl_geom, name(`name')
    local x1 = (`gx' - r(xa))/r(xb)
    local y1 = (`gy' - r(ya))/r(yb)
    if r(xlog) local x1 = exp(`x1')
    if r(ylog) local y1 = exp(`y1')
    c_local `p'x `x1'
    c_local `p'y `y1'
end

* is a point (in plot region 1 data units) inside the plot region? cmd opt name x y mode
* mode err stops with rc 198; mode note prints a note. c_local _gpl_out is 1 when outside
program _gpl_inplot
    args cmd opt name x y mode
    _gpl_geom, name(`name')
    local gx = r(xa) + r(xb)*cond(r(xlog), ln(`x'), `x')
    local gy = r(ya) + r(yb)*cond(r(ylog), ln(`y'), `y')
    local tol = 0.001*max(r(gx1)-r(gx0), r(gy1)-r(gy0))
    local out = missing(`gx', `gy') | `gx' < r(gx0)-`tol' | `gx' > r(gx1)+`tol' | `gy' < r(gy0)-`tol' | `gy' > r(gy1)+`tol'
    c_local _gpl_out `out'
    if !`out' exit
    foreach d in x y {
        local D = upper("`d'")
        local a = (r(g`d'0) - r(`d'a))/r(`d'b)
        local b = (r(g`d'1) - r(`d'a))/r(`d'b)
        if r(`d'log) {
            local a = exp(`a')
            local b = exp(`b')
        }
        local `d'lo : di %9.0g min(`a', `b')
        local `d'hi : di %9.0g max(`a', `b')
        local `d'lo = trim("``d'lo'")
        local `d'hi = trim("``d'hi'")
    }
    local msg "gpolish `cmd': `opt'() lies outside the plot region (x range `xlo' to `xhi', y range `ylo' to `yhi')"
    if "`mode'"=="err" {
        di as err "`msg'"
        exit 198
    }
    di as txt "note: `msg'"
end

* an endlabel record, kept in the graph itself as a hidden text box so that it lasts through
* graph save and graph use and belongs to this graph only. Its text is
* gpolish-endlabel|<text boxes>|<markers>|<side>|<margin>|<legend>|<where>|<first-line lengths>
program _gpl_regget, rclass
    args name
    return local ok 0
    _gpl_count `name' added_text
    local nt = r(k)
    local rec 0
    forvalues k = `nt'(-1)1 {
        if substr(`"`.`name'.plotregion1.added_text[`k'].text[1]'"', 1, 17)=="gpolish-endlabel|" {
            local rec `k'
            continue, break
        }
    }
    if `rec'==0 exit
    local s `"`.`name'.plotregion1.added_text[`rec'].text[1]'"'
    mata: _gpl_recparse(st_local("s"))
    _gpl_count `name' added_markers
    local nm = r(k)
    * The record is stale if a recorded object is gone or no longer holds the same text. The margin
    * and the legend change do not depend on the objects, so they are returned either way; of the
    * objects, only those still present and unchanged are returned (r(nchg) counts the others).
    local stale 0
    local nchg 0
    local okt
    local okm
    local q 0
    foreach k of local txt {
        local ++q
        if `k' == `rec' | `k' > `nt' {
            local stale 1
            local ++nchg
            continue
        }
        local L : word `q' of `lens'
        local t `"`.`name'.plotregion1.added_text[`k'].text[1]'"'
        if `"`L'"'!="`=strlen(`"`t'"')'" {
            local stale 1
            local ++nchg
        }
        else local okt `okt' `k'
    }
    foreach k of local mk {
        if `k' > `nm' local stale 1
        else local okm `okm' `k'
    }
    capture confirm number `m'
    if _rc local m
    return local rec `rec'
    return local ok = !`stale'
    return local nchg `nchg'
    return local txt `okt'
    return local mk `okm'
    return local side `side'
    return local m `m'
    return local leg `leg'
    return local pm `pm'
end

* Undo a recorded endlabel: hide its objects, give back its margin, restore the legend. Every run
* undoes the run before it, so at most one run is outstanding, and its record is the live one: one
* gpolish clear returns the graph to its state before the first endlabel run. A record is spent when it
* is used. A stale record (a label changed or removed by other means) still gives back the margin and
* the legend; the labels that were changed or removed are left as they are (the caller's local
* _gpl_nchg counts them).
program _gpl_regundo
    args name
    _gpl_regget `name'
    * copy the record first: an edit clears r()
    local ok `r(ok)'
    local rec `r(rec)'
    local txt `r(txt)'
    local mk `r(mk)'
    local m `r(m)'
    local side `r(side)'
    local leg `r(leg)'
    local pm `r(pm)'
    local nchg `r(nchg)'
    c_local _gpl_legn 0
    c_local _gpl_nchg 0
    if "`rec'"=="" {
        * no record box: end labels added by gpolish 0.6.1 or earlier are found in the edit log
        _gpl_legundo `name'
        c_local _gpl_legn `r(n)'
        exit
    }
    * a record is used once: mark it spent
    _gpl_ge `name' .plotregion1.added_text[`rec'].text = {}
    _gpl_ge `name' .plotregion1.added_text[`rec'].text.Arrpush "gpolish-endlabel-spent"
    if "`nchg'"!="" c_local _gpl_nchg `nchg'
    foreach k of local txt {
        _gpl_ge `name' .plotregion1.added_text[`k'].draw_view.setstyle, style(no)
    }
    foreach k of local mk {
        _gpl_ge `name' .plotregion1.added_markers[`k'].draw_view.setstyle, style(no)
    }
    if "`m'"!="" {
        local s = cond("`side'"=="left", "l", "r")
        if "`pm'"=="1" {
            _gpl_plots `name'
            forvalues j = 1/`r(npr)' {
                _gpl_ge `name' .plotregion`j'.style.editstyle margin(`s'-`m') editcopy
            }
        }
        else _gpl_ge `name' .style.editstyle margin(`s'-`m') editcopy
    }
    if "`leg'"=="1" _gpl_ge `name' .legend.draw_view.setstyle, style(yes)
end

* End labels added by gpolish 0.6.1 or earlier, which kept no record in the graph. A graph keeps every
* edit in its edit log (.__LOG), and graph save keeps the log. There an endlabel run shows as a margin
* edit ".style.editstyle margin(r+#) editcopy" (l+# for side(left)), the legend switched off by the next
* edit, and then its text boxes: each label box is styled with linegap(1pt), and a value box follows
* its label at the same height. Each run whose margin was not given back later in the log is undone
* here: its boxes and markers are hidden, its margin is given back and the legend is shown again.
* A graph whose log shows an endlabel record of this release is not scanned (see _gpl_legscan()).
* r(n) = runs undone
program _gpl_legundo, rclass
    args name
    local nlog `.`name'.__LOG.arrnels'
    if "`nlog'"=="" local nlog 0
    local n 0
    if `nlog' > 0 {
        mata: _gpl_legL = J(`nlog', 1, "")
        forvalues e = 1/`nlog' {
            capture local s `.`name'.__LOG[`e']'
            if _rc continue
            mata: _gpl_legL[`e'] = st_local("s")
        }
        mata: _gpl_legscan(_gpl_legL)
        mata: mata drop _gpl_legL
    }
    if `n' > 0 {
        _gpl_count `name' added_text
        local nt = r(k)
        _gpl_count `name' added_markers
        local nm = r(k)
        foreach k of local txt {
            if `k' <= `nt' _gpl_ge `name' .plotregion1.added_text[`k'].draw_view.setstyle, style(no)
        }
        foreach k of local mk {
            if `k' <= `nm' _gpl_ge `name' .plotregion1.added_markers[`k'].draw_view.setstyle, style(no)
        }
        while "`marg'"!="" {
            gettoken s marg : marg
            gettoken v marg : marg
            _gpl_ge `name' .style.editstyle margin(`s'-`v') editcopy
        }
        if "`leg'"=="1" & "`.`name'.legend.draw_view.setting'"=="no" _gpl_ge `name' .legend.draw_view.setstyle, style(yes)
    }
    return scalar n = `n'
end

* apply one graph edit; the edit is recorded in the graph, and the graph is drawn once
* when the subcommand finishes
program _gpl_ge
    gettoken name 0 : 0
    mata: st_local("0", strltrim(st_local("0")))
    _gm_edit .`name'.`0'
end

* gpolish geom, as typed by a user: check the graph first, then report its geometry
program _gpl_geomuser, rclass
    syntax [, name(string)]
    _gpl_name `name'
    local name `r(name)'
    _gpl_geom, name(`name')
    return add
end

program _gpl_count, rclass
    args name what
    local k `.`name'.plotregion1.`what'.arrnels'
    if "`k'"=="" local k 0
    return scalar k = `k'
end

* add one text box; lines() is a list of quoted strings; returns r(k)
program _gpl_addtext, rclass
    syntax , name(string) x(string) y(string) lines(string asis) [size(real 9) color(string) ///
        hz(string) ba(string) halo angle(real 0) linegap(string) fill(string) border(string) pad(real 5)]
    if "`color'"=="" local color "26 26 26"
    if "`hz'"=="" local hz left
    if "`ba'"=="" local ba east
    if "`linegap'"=="" local linegap 1.5pt
    _gpl_count `name' added_text
    local k = r(k) + 1
    _gpl_ge `name' .plotregion1.AddTextBox added_text editor `y' `x'
    _gpl_ge `name' .plotregion1.added_text_new = `k'
    _gpl_ge `name' .plotregion1.added_text_rec = `k'
    local box
    if "`fill'"!="" {
        if "`border'"=="" local border "`fill'"
        _gpl_geom, name(`name')
        local ph = `pad'*r(relperpt)
        local pv = 0.7*`pad'*r(relperpt)
        local box drawbox(yes) fillcolor("`fill'") linestyle(color("`border'") width(thin)) margin(`ph' `ph' `pv' `pv')
    }
    else if "`halo'"!="" local box drawbox(yes) fillcolor(white%80) linestyle(color(white%0) width(none)) boxmargin(0.5 0.5 0.2 0.2)
    _gpl_ge `name' .plotregion1.added_text[`k'].style.editstyle size(`size'pt) color("`color'") horizontal(`hz') vertical(middle) box_alignment(`ba') linegap(`linegap') `box' editcopy
    _gpl_ge `name' .plotregion1.added_text[`k'].text = {}
    foreach l of local lines {
        _gpl_ge `name' .plotregion1.added_text[`k'].text.Arrpush `"`l'"'
    }
    if `angle'!=0 {
        * store the request; Stata itself only draws quarter turns
        capture _gpl_ge `name' .plotregion1.added_text[`k'].style.editstyle angle(`angle') editcopy
        if inlist(`angle', 90, -270) capture _gpl_ge `name' .plotregion1.added_text[`k'].orientation.setstyle, style(vertical)
        else if inlist(`angle', -90, 270) capture _gpl_ge `name' .plotregion1.added_text[`k'].orientation.setstyle, style(rvertical)
        else _gpl_note rotate `angle'
    }
    return scalar k = `k'
end

program _gpl_addline
    syntax , name(string) seg(string) [lcolor(string) lwidth(string)]
    if "`lcolor'"=="" local lcolor "85 85 85"
    if "`lwidth'"=="" local lwidth thin
    _gpl_count `name' added_lines
    local k = r(k) + 1
    _gpl_ge `name' .plotregion1.AddLine added_lines editor `seg'
    _gpl_ge `name' .plotregion1.added_lines_new = `k'
    _gpl_ge `name' .plotregion1.added_lines_rec = `k'
    _gpl_ge `name' .plotregion1.added_lines[`k'].style.editstyle linestyle(width(`lwidth') color("`lcolor'")) headstyle(symbol(none)) editcopy
end

* one-line notes for things Stata's renderer cannot draw
program _gpl_note
    args what detail
    if "`what'"=="rotate" {
        di as txt "note: Stata cannot draw text at `detail' degrees (quarter turns only). The angle is stored in the graph;"
        di as txt "      {bf:gpolish render} redraws the graph with matplotlib and applies it."
    }
    else if "`what'"=="crowded" {
        di as txt "note: `detail' label(s) could not be placed without overlap. Options: label fewer points, enlarge the graph,"
        di as txt "      or use {bf:gpolish render} for the final image (matplotlib draws a text halo that keeps overlaps legible)."
    }
    else if "`what'"=="inlinecolor" {
        di as txt "note: Stata text has no inline colour markup; the tag was left as typed. Colour whole labels instead"
        di as txt "      ({bf:gpolish legend}, {bf:gpolish endlabel})."
    }
end

* collect what is already drawn: marker points, line paths, text boxes (device units, Mata externals)
program _gpl_obstacles
    args name
    _gpl_plots `name'
    local n = r(n)
    local npr = r(npr)
    local regs `r(regs)'
    forvalues j = 1/`npr' {
        _gpl_geom, name(`name') region(`j')
        foreach v in xa xb ya yb xlog ylog {
            local `v'`j' = r(`v')
        }
    }
    _gpl_geom, name(`name')
    local xa = r(xa)
    local xb = r(xb)
    local ya = r(ya)
    local yb = r(yb)
    local xlog = r(xlog)
    local ylog = r(ylog)
    local gprel = r(gpi)/72/r(relperpt)
    local gpi = r(gpi)
    mata: _gpl_obs_reset()
    forvalues i = 1/`n' {
        local j : word `i' of `regs'
        local pr .`name'.plotregion`j'
        local T `xlog`j'', `ylog`j'', `xa`j'', `xb`j'', `ya`j'', `yb`j''
        local t ``pr'.plot`i'.type.setting'
        if "``pr'.plot`i'.draw_view.setting'"=="no" continue
        local isrange = inlist("`t'","rbar","rarea","rcap","rspike","rcapsym")
        if !inlist("`t'","scatter","connected","line","rline","dot","function","spike","dropline") ///
            & !inlist("`t'","bar","area") & !`isrange' continue
        capture {
            local yv = ``pr'.plot`i'.yvar'
            local xv = ``pr'.plot`i'.xvar'
            local sid = ``pr'.plot`i'.serset.id'
            local y2v
            if `isrange' local y2v = ``pr'.plot`i'.y2var'
        }
        if _rc continue
        local rad = 0
        if inlist("`t'","scatter","connected","dot") {
            local ms ``pr'.plot`i'.style.marker.size.gmval'
            if "`ms'"=="" local ms 1.5
            local sym ``pr'.plot`i'.style.marker.symbol.setting'
            local rad = `ms'*`gprel'/2
            if inlist("`sym'","none","i","point") local rad = 0
        }
        * bars, areas and range plots: which axis the values run along, the base, the bar width
        local horiz = ("``pr'.plot`i'.bar_drop_to.setting'"=="y")
        local base ``pr'.plot`i'.drawn_base'
        if "`base'"=="" | "`base'"=="." local base 0
        local bw ``pr'.plot`i'.bar_size'
        if "`bw'"=="" | "`bw'"=="." local bw 0
        preserve
        capture {
            serset set `sid'
            serset use, clear
            unab all : *
            local yname : word `yv' of `all'
            local xname : word `xv' of `all'
            local y2name
            if "`y2v'"!="" local y2name : word `y2v' of `all'
            if `rad' > 0 mata: _gpl_obs_points("`xname'", "`yname'", `T', `rad')
            if inlist("`t'","connected","line","rline","function") ///
                mata: _gpl_obs_path("`xname'", "`yname'", `T', 4/72*`gpi')
            * kind: 1 bars (width bw in data units), 2 shaded band, 3 thin range spike
            if inlist("`t'","bar","rbar") mata: _gpl_obs_range("`xname'", "`yname'", "`y2name'", `base', `horiz', 1, `bw', `T', 2/72*`gpi')
            if inlist("`t'","area","rarea") mata: _gpl_obs_range("`xname'", "`yname'", "`y2name'", `base', `horiz', 2, 0, `T', 4/72*`gpi')
            if inlist("`t'","rcap","rspike","rcapsym") mata: _gpl_obs_range("`xname'", "`yname'", "`y2name'", `base', `horiz', 3, 0, `T', 3/72*`gpi')
        }
        restore
    }
    * reference lines drawn by xline() and yline(), read in device units
    forvalues j = 1/`npr' {
        local pr .`name'.plotregion`j'
        local k ``pr'._xylines.arrnels'
        if "`k'"=="" local k 0
        forvalues q = 1/`k' {
            if "``pr'._xylines[`q'].draw_view.setting'"=="no" continue
            capture mata: _gpl_obs_add(_gpl_thin((``pr'._xylines[`q'].gdi_x0', ``pr'._xylines[`q'].gdi_y0', ///
                ``pr'._xylines[`q'].gdi_x1', ``pr'._xylines[`q'].gdi_y1'), 2/72*`gpi'))
        }
    }
    * text boxes already on the graph
    local pr .`name'.plotregion1
    foreach arr in added_text {
        _gpl_count `name' `arr'
        local k = r(k)
        forvalues j = 1/`k' {
            if "``pr'.`arr'[`j'].draw_view.setting'"=="no" continue
            capture {
                local tx = ``pr'.`arr'[`j'].xpos.val'
                local ty = ``pr'.`arr'[`j'].ypos.val'
                local sz = ``pr'.`arr'[`j'].style.size.gmval'
                local hz ``pr'.`arr'[`j'].style.horizontal.setting'
                local ba ``pr'.`arr'[`j'].style.box_alignment.setting'
                local nl = ``pr'.`arr'[`j'].text.arrnels'
                local w 0
                forvalues q = 1/`nl' {
                    mata: st_local("wq", strofreal(_gpl_textw(st_global("GPL_FONT"), `"``pr'.`arr'[`j'].text[`q']'"', 0)))
                    local w = max(`w', `wq')
                }
                local gx = `xa' + `xb'*cond(`xlog', ln(`tx'), `tx')
                local gy = `ya' + `yb'*cond(`ylog', ln(`ty'), `ty')
                mata: _gpl_obs_text(`gx', `gy', `w'*`sz'*`gprel', `nl'*`sz'*`gprel'*1.3, "`ba'")
            }
        }
    }
end

* ================================================================ style
program _gpl_style
    syntax [, name(string) noBOLD KEEPYLine KEEPYTicks]
    * the bold title works on every graph family; the axis edits are twoway only
    if "`name'"=="" {
        capture quietly graph describe
        if _rc {
            di as err "gpolish: no graph in memory"
            exit 111
        }
        local name `r(fn)'
    }
    local fam `.`name'.graphfamily'
    if "`fam'"=="" {
        di as err "gpolish: graph {bf:`name'} not found in memory"
        exit 111
    }
    quietly graph display `name'
    if "`fam'"=="twoway" {
        * every y axis the graph has; a graph drawn with yaxis(2) alone has no yaxis1
        forvalues a = 1/9 {
            if "`.`name'.yaxis`a'.isa'"=="" continue
            if "`keepyline'"==""  capture _gpl_ge `name' .yaxis`a'.style.editstyle linestyle(color(none)) editcopy
            if "`keepyticks'"=="" capture _gpl_ge `name' .yaxis`a'.style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
        }
    }
    local nt `.`name'.title.text.arrnels'
    if "`nt'"=="" local nt 0
    forvalues i = 1/`nt' {
        local t`i' `"`.`name'.title.text[`i']'"'
        mata: st_local("t`i'", _gpl_esc(st_local("t`i'")))
        if strpos(`"`t`i''"', "{color") | strpos(`"`t`i''"', "{c #") _gpl_note inlinecolor
    }
    if "`bold'"=="" & `nt' > 0 {
        _gpl_ge `name' .title.text = {}
        forvalues i = 1/`nt' {
            if substr(`"`t`i''"',1,4)=="{bf:" _gpl_ge `name' .title.text.Arrpush `"`t`i''"'
            else _gpl_ge `name' .title.text.Arrpush `"{bf:`t`i''}"'
        }
    }
end

* ================================================================ endlabel
* the text of the legend key drawn for the plot whose object key is given, lines joined by a
* space; r(text) is empty when the graph has no legend or no key for that plot
program _gpl_legtext, rclass
    args name okey
    local nk `.`name'.legend.plotregion1.key.arrnels'
    if "`nk'"=="" | `"`okey'"'=="" exit
    forvalues k = 1/`nk' {
        if `"`.`name'.legend.plotregion1.key[`k'].view.objkey'"'==`"`okey'"' {
            local nl `.`name'.legend.plotregion1.label[`k'].text.arrnels'
            if "`nl'"=="" local nl 0
            local t
            forvalues q = 1/`nl' {
                local s `"`.`name'.legend.plotregion1.label[`k'].text[`q']'"'
                if `"`t'"'=="" local t `"`s'"'
                else if `"`s'"'!="" local t `"`t' `s'"'
            }
            return local text `"`t'"'
            exit
        }
    }
end

program _gpl_endlabel
    syntax [, name(string) SIZe(real 9.5) GAP(real 1.3) VALues FORmat(string) noBOLD ///
              DOTs DOTSIze(real -1) PLOTs(numlist integer >0) XGap(real 8) LABels(string asis) noREPEL ///
              WRAP(integer 0) SIDe(string) COLor(string) KEEPLegend]
    _gpl_name `name'
    local name `r(name)'
    * dotsize() on its own asks for dots
    * the sentinel -1 means not given, so dotsize(5.5) also turns dots on
    if `dotsize'!=-1 {
        if `dotsize'<=0 {
            di as err "dotsize() must be positive"
            exit 198
        }
        local dots dots
    }
    else local dotsize 5.5
    if "`format'"=="" local format %4.1f
    if "`side'"=="" local side right
    if !inlist("`side'", "right", "left") {
        di as err "gpolish endlabel: side() must be right or left"
        exit 198
    }
    * plots are numbered across plot regions; a plot on a second axis is drawn in its own region
    _gpl_plots `name'
    local n = r(n)
    local npr = r(npr)
    local regs `r(regs)'
    if "`plots'"=="" {
        forvalues i = 1/`n' {
            local j : word `i' of `regs'
            if inlist("`.`name'.plotregion`j'.plot`i'.type.setting'","line","connected","rline") local plots `plots' `i'
        }
        if "`plots'"=="" {
            di as err "gpolish endlabel: no line plots found; use plots() to name the plots to label"
            exit 198
        }
    }
    foreach i of local plots {
        if `i' > `n' {
            di as err "gpolish endlabel: plots(`i') is out of range; graph {bf:`name'} has `n' plot(s)"
            exit 198
        }
    }
    * With a y axis on the label side the room is made inside the plot region (see below). On a
    * graph with aspectratio() that margin fights the fixed shape and distorts the axes, so the
    * combination stops here, before any edit.
    local ar `.`name'.style.aspect_ratio.val'
    if "`ar'"!="" & "`ar'"!="0" & "`ar'"!="." {
        _gpl_geom, name(`name')
        local pc0 = (r(gx0) + r(gx1))/2
        local s0 = cond("`side'"=="right", 1, -1)
        forvalues a = 1/9 {
            if "`.`name'.yaxis`a'.isa'"=="" | "`.`name'.yaxis`a'.draw_view.setting'"=="no" continue
            local ax0 `.`name'.yaxis`a'.gdi_x0'
            local ax1 `.`name'.yaxis`a'.gdi_x1'
            if "`ax0'"=="" | "`ax1'"=="" continue
            if `s0'*((`ax0' + `ax1')/2 - `pc0') > 0 {
                di as err "gpolish endlabel: graph {bf:`name'} has aspectratio() and a y axis on the `side' side;"
                di as err "  endlabel cannot make room inside its plot region without distorting the axes."
                di as err "  Drop aspectratio(), or use side() to label the side that has no y axis."
                exit 198
            }
        }
    }
    * a second endlabel replaces the first instead of stacking on it
    _gpl_regundo `name'
    if `_gpl_legn' > 0 {
        di as txt "note: end labels added to graph {bf:`name'} by gpolish 0.6.1 or earlier were found in its"
        di as txt "      edit log; they are hidden and their margin is given back before the new labels"
        di as txt "      are added."
    }
    if `_gpl_nchg' > 0 {
        di as txt "note: `_gpl_nchg' end label(s) of the earlier run on graph {bf:`name'} were changed or"
        di as txt "      removed by other means and are left as they are; the other labels of that"
        di as txt "      run are hidden and its margin is given back. {bf:gpolish clear} removes"
        di as txt "      every added text box."
    }
    * which end of each line sits on the chosen side of the plot, whatever the axis direction
    local s = cond("`side'"=="right", 1, -1)
    forvalues j = 1/`npr' {
        _gpl_geom, name(`name') region(`j')
        local dir`j' = `s'*sign(r(xb))
    }
    local np : word count `plots'
    tempname Y
    matrix `Y' = J(`np', 6, 1)
    local j 0
    local maxn 0
    local maxv 0
    local q 0
    foreach i of local plots {
        local ++q
        local rg : word `i' of `regs'
        local pr .`name'.plotregion`rg'
        local yv = ``pr'.plot`i'.yvar'
        local xv = ``pr'.plot`i'.xvar'
        local sid = ``pr'.plot`i'.serset.id'
        local slab `"``pr'.plot`i'.serset.sers[`yv'].label'"'
        local sname ``pr'.plot`i'.serset.sers[`yv'].name'
        preserve
        quietly {
            serset set `sid'
            serset use, clear
            * address serset columns by position: stored names go stale for tempvars
            unab all : *
            local yname : word `yv' of `all'
            local xname : word `xv' of `all'
            summarize `xname' if !missing(`yname', `xname'), meanonly
            local nobs = r(N)
            local xl = cond(`dir`rg'' > 0, r(max), r(min))
            if `nobs' > 0 {
                summarize `yname' if `xname'==`xl', meanonly
                local yl = r(mean)
            }
        }
        restore
        if `nobs'==0 {
            di as txt "note: plot `i' has no nonmissing values and is not labelled"
            continue
        }
        local ++j
        local plot`j' `i'
        * prefer the variable's own label: it is read raw, while a serset label passes
        * through macro expansion once more (a $ in it would already be lost)
        * the legend key text of the plot comes first when it says something the variable
        * label does not: a fit line (lfit, qfit, lowess) or a marginsplot line keeps the
        * name its legend gave it. Otherwise the raw variable label is used.
        _gpl_legtext `name' `"``pr'.plot`i'.objkey'"'
        local ltx `"`r(text)'"'
        local lab`j'
        capture confirm variable `sname', exact
        if !_rc local lab`j' : variable label `sname'
        if `"`lab`j''"'=="" local lab`j' `"`slab'"'
        * the legend text has passed through global expansion, so it is compared with the label
        * expanded the same way
        mata: st_local("lexp", _gpl_gexp(st_local("lab`j'")))
        if `"`ltx'"'!="" & `"`ltx'"'!=`"`lexp'"' local lab`j' `"`ltx'"'
        if `"`lab`j''"'=="" local lab`j' `sname'
        mata: st_local("lab`j'", _gpl_esc(st_local("lab`j'")))
        if `"`labels'"'=="" | `"`: word `q' of `labels''"'=="" {
            * two plots with one label leave the reader unable to tell them apart
            forvalues jj = 1/`=`j'-1' {
                if `"`lab`jj''"'==`"`lab`j''"' {
                    di as txt `"note: gpolish endlabel: plots `plot`jj'' and `i' get the same label "`lab`j''";"'
                    di as txt "      use labels() to tell them apart; the legend is kept"
                    local keeplegend keeplegend
                    continue, break
                }
            }
        }
        if `"`labels'"'!="" {
            * labels() follow the order of plots(), one per plot
            local ll : word `q' of `labels'
            if `"`ll'"'!="" local lab`j' `"`ll'"'
        }
        * bold wraps the label in {bf:...}; a literal } in the label would close it early,
        * so such a label is left as typed
        mata: st_local("bf`j'", strofreal("`bold'"=="" & _gpl_bfok(st_local("lab`j'"))))
        local col`j' ``pr'.plot`i'.style.line.color.rgb'
        if "``pr'.plot`i'.type.setting'"=="scatter" local col`j' ``pr'.plot`i'.style.marker.fillcolor.rgb'
        local col`j' : list retokenize col`j'
        local tcol`j' `"`col`j''"'
        if `"`color'"'!="" local tcol`j' `"`color'"'
        local val`j' : display `format' `yl'
        local val`j' = strtrim("`val`j''")
        matrix `Y'[`j',1] = `yl'
        matrix `Y'[`j',4] = `xl'
        matrix `Y'[`j',6] = `rg'
        * wrap long labels on word boundaries; wrap() is in characters, measured by rendered width
        mata: _gpl_wrap("lab`j'", "nl`j'", "w", 0.5*`wrap', `bf`j'')
        matrix `Y'[`j',5] = `nl`j''
        local maxn = max(`maxn', `w')
        local w2 0
        if "`values'"!="" mata: st_local("w2", strofreal(_gpl_textw(st_global("GPL_FONT"), st_local("val`j'"), 0)))
        local maxv = max(`maxv', `w2')
    }
    if `j'==0 {
        di as err "gpolish endlabel: none of the plots has nonmissing values to label"
        exit 2000
    }
    local np `j'
    matrix `Y' = `Y'[1..`np', 1...]
    local maxw = `maxn' + `maxv' + cond("`values'"!="", 0.9, 0)
    * make room on the chosen side, then read the (new) transform
    _gpl_geom, name(`name')
    local m = (`xgap' + `maxw'*`size' + 4)*r(relperpt)
    local plotw = 100*r(xsize)/min(r(xsize), r(ysize))
    if `m' > 0.35*`plotw' {
        di as txt "note: the end labels take about `=round(100*`m'/`plotw')'% of the graph width. Shorten them, use wrap(),"
        di as txt "      a smaller size(), or a wider graph (xsize())."
    }
    * Outside the plot the labels would sit on a y axis drawn on that side (its line, ticks and
    * labels). Then the room is made inside the plot region instead, between the axis and the lines.
    local inner 0
    local pc = (r(gx0) + r(gx1))/2
    forvalues a = 1/9 {
        if "`.`name'.yaxis`a'.isa'"=="" | "`.`name'.yaxis`a'.draw_view.setting'"=="no" continue
        local ax0 `.`name'.yaxis`a'.gdi_x0'
        local ax1 `.`name'.yaxis`a'.gdi_x1'
        if "`ax0'"=="" | "`ax1'"=="" continue
        if `s'*((`ax0' + `ax1')/2 - `pc') > 0 local inner 1
    }
    local mside = cond("`side'"=="right", "r", "l")
    if `inner' {
        forvalues rg = 1/`npr' {
            _gpl_ge `name' .plotregion`rg'.style.editstyle margin(`mside'+`m') editcopy
        }
    }
    else _gpl_ge `name' .style.editstyle margin(`mside'+`m') editcopy
    local leg 0
    if "`keeplegend'"=="" & "`.`name'.legend.draw_view.setting'"=="yes" {
        _gpl_ge `name' .legend.draw_view.setstyle, style(no)
        local leg 1
    }
    * the plot region moved: redraw so the transforms below are current
    gr_draw `name'
    forvalues rg = 1/`npr' {
        _gpl_geom, name(`name') region(`rg')
        foreach v in xa xb ya yb xlog ylog {
            local `v'`rg' = r(`v')
        }
    }
    _gpl_geom, name(`name')
    local gpi = r(gpi)
    local gy0 = r(gy0)
    local gy1 = r(gy1)
    * device position of each line end, each on its own region's scale
    forvalues j = 1/`np' {
        local rg = `Y'[`j',6]
        matrix `Y'[`j',2] = `ya`rg'' + `yb`rg''*cond(`ylog`rg'', ln(`Y'[`j',1]), `Y'[`j',1])
        matrix `Y'[`j',3] = `Y'[`j',2]
    }
    local sep = `gap'*`size'/72*`gpi'
    local novl 0
    local nclose 0
    if "`repel'"=="" mata: _gpl_repel("`Y'", `sep', `gy0', `gy1', `size'/72*`gpi', 1/72*`gpi')
    * pairs whose text overlaps, and pairs that do not overlap but sit closer than gap() asks
    local nnear = `nclose' - `novl'
    if `novl' > 0 {
        di as txt "note: `novl' pair(s) of end labels overlap; there is not enough height for them."
        if `nnear' > 0 di as txt "      Another `nnear' pair(s) are closer than gap() asks but do not overlap."
    }
    else if `nnear' > 0 {
        di as txt "note: `nnear' pair(s) of end labels are closer than gap() asks but do not overlap;"
        di as txt "      there is not enough height for the full gap."
    }
    if `nclose' > 0 {
        di as txt "      Label fewer plots (plots()), use a smaller size() or gap(), or a taller graph (ysize())."
    }
    _gpl_count `name' added_markers
    local km = r(k)
    local regtxt
    local regmk
    * labels sit next to the line end; the value column sits beyond them
    local hzl = cond(`s' > 0, "left", "right")
    local bal = cond(`s' > 0, "east", "west")
    local hzv = cond(`s' > 0, "right", "left")
    local bav = cond(`s' > 0, "west", "east")
    * the value column is shared: it sits beyond the line end farthest out on the label side
    local gxe .
    forvalues j = 1/`np' {
        local rg = `Y'[`j',6]
        local xl = `Y'[`j',4]
        local g = `xa`rg'' + `xb`rg''*cond(`xlog`rg'', ln(`xl'), `xl')
        if `gxe'==. local gxe = `g'
        else local gxe = cond(`s' > 0, max(`gxe', `g'), min(`gxe', `g'))
    }
    * every object goes into plot region 1, so positions are given in its data units
    forvalues j = 1/`np' {
        local rg = `Y'[`j',6]
        local ynew = (`Y'[`j',3] - `ya1')/`yb1'
        if `ylog1' local ynew = exp(`ynew')
        local xl = `Y'[`j',4]
        local yl = `Y'[`j',1]
        local gxl = `xa`rg'' + `xb`rg''*cond(`xlog`rg'', ln(`xl'), `xl')
        local xpos = (`gxl' + `s'*`xgap'/72*`gpi' - `xa1')/`xb1'
        local xval = (`gxe' + `s'*(`xgap' + `maxw'*`size')/72*`gpi' - `xa1')/`xb1'
        local xdot = (`gxl' - `xa1')/`xb1'
        local ydot = (`Y'[`j',2] - `ya1')/`yb1'
        if `xlog1' {
            local xpos = exp(`xpos')
            local xval = exp(`xval')
            local xdot = exp(`xdot')
        }
        if `ylog1' local ydot = exp(`ydot')
        if "`dots'"!="" {
            local ++km
            _gpl_ge `name' .plotregion1.AddMarker added_markers editor `xdot' `ydot'
            _gpl_ge `name' .plotregion1.added_markers_new = `km'
            _gpl_ge `name' .plotregion1.added_markers_rec = `km'
            _gpl_ge `name' .plotregion1.added_markers[`km'].style.editstyle marker(symbol(circle) size(`dotsize'pt) fillcolor("`col`j''") linestyle(color(white) width(vthin))) editcopy
            local regmk `regmk' `km'
        }
        local lines
        forvalues q = 1/`nl`j'' {
            if `bf`j'' local lines `"`lines' `"{bf:`lab`j'_`q''}"'"'
            else local lines `"`lines' `"`lab`j'_`q''"'"'
        }
        _gpl_addtext, name(`name') x(`xpos') y(`ynew') lines(`lines') size(`size') color(`"`tcol`j''"') hz(`hzl') ba(`bal') linegap(1pt)
        local regtxt `regtxt' `r(k)'
        if "`values'"!="" {
            _gpl_addtext, name(`name') x(`xval') y(`ynew') lines(`"`val`j''"') size(`size') color(`"`tcol`j''"') hz(`hzv') ba(`bav')
            local regtxt `regtxt' `r(k)'
        }
    }
    * record what was added, in the graph itself, so a re-run or gpolish clear can undo it
    local lens
    foreach k of local regtxt {
        local t `"`.`name'.plotregion1.added_text[`k'].text[1]'"'
        local lens `lens' `=strlen(`"`t'"')'
    }
    local rec `"gpolish-endlabel|`regtxt'|`regmk'|`side'|`m'|`leg'|`inner'|`lens'"'
    * an earlier record box (spent by the undo above) is reused, so a graph holds at most one
    _gpl_count `name' added_text
    local nt = r(k)
    local kr 0
    forvalues k = 1/`nt' {
        if substr(`"`.`name'.plotregion1.added_text[`k'].text[1]'"', 1, 16)=="gpolish-endlabel" {
            local kr `k'
            continue, break
        }
    }
    if `kr' > 0 {
        _gpl_ge `name' .plotregion1.added_text[`kr'].text = {}
        _gpl_ge `name' .plotregion1.added_text[`kr'].text.Arrpush `"`rec'"'
        _gpl_ge `name' .plotregion1.added_text[`kr'].draw_view.setstyle, style(no)
    }
    else {
        _gpl_addtext, name(`name') x(`xpos') y(`ynew') lines(`"`rec'"') size(1)
        _gpl_ge `name' .plotregion1.added_text[`r(k)'].draw_view.setstyle, style(no)
    }
end

* ================================================================ clear
* remove every added text box, line and marker, and undo endlabel's margin and legend changes
program _gpl_clear
    syntax [, name(string)]
    _gpl_name `name'
    local name `r(name)'
    _gpl_regundo `name'
    if `_gpl_legn' > 0 {
        di as txt "note: end labels added to graph {bf:`name'} by gpolish 0.6.1 or earlier were found in its"
        di as txt "      edit log; their margin is given back, and a legend they switched off is shown"
        di as txt "      again."
    }
    foreach a in added_text added_lines added_markers {
        _gpl_count `name' `a'
        local n = r(k)
        local k`a' = `n'
        if "`a'"=="added_text" {
            * endlabel's hidden records are not counted as text boxes
            forvalues k = 1/`n' {
                if substr(`"`.`name'.plotregion1.added_text[`k'].text[1]'"', 1, 16)=="gpolish-endlabel" local --k`a'
            }
        }
        if `n' > 0 {
            _gpl_ge `name' .plotregion1.`a' = {}
            _gpl_ge `name' .plotregion1.`a'_new = 0
            _gpl_ge `name' .plotregion1.`a'_rec = 0
        }
    }
    * a clear with nothing to remove makes no edit and prints nothing
    if `kadded_text' + `kadded_lines' + `kadded_markers' == 0 exit
    di as txt "gpolish clear: removed `kadded_text' text box(es), `kadded_lines' line segment(s) and `kadded_markers' marker(s)"
    di as txt "  (this includes anything added in the Graph Editor; the title and axis edits of {bf:gpolish} stay)"
end

* ================================================================ positions on a second axis
* xaxis(#) and yaxis(#) say which axes at(), to() and from() are given on; the caller's locals
* local _gpl_reg is set to the plot region they belong to (left empty for region 1)
program _gpl_axpos
    args name xax yax
    _gpl_axnum "`xax'" "`yax'"
    _gpl_axregion `name' "`xax'" "`yax'"
    local reg = r(region)
    if `reg'!=1 c_local _gpl_reg `reg'
end

program _gpl_axnum
    args xax yax
    foreach a in xax yax {
        if "``a''"!="" & !inlist("``a''", "1", "2", "3", "4", "5", "6", "7", "8", "9") {
            local o = cond("`a'"=="xax", "xaxis", "yaxis")
            di as err "gpolish: `o'() must be an axis number, 1 to 9"
            exit 198
        }
    }
end

* ptlabel: the plot region whose scales the x() and y() values are read on; r(region).
* Among the plot regions that carry the axes named by xaxis() and yaxis() (all regions when neither is
* given), the first one where a plot draws y() against x() is used. Failing that, the first one that
* carries an axis y() is drawn on and an axis x() is drawn on. A variable that no plot draws puts no
* condition on the region. When no region qualifies, ptlabel stops before any edit and says which
* option to change, because labels read on another axis's scale would sit far from their points.
program _gpl_ptregion, rclass
    args name xvar yvar xax yax
    _gpl_regaxes `name'
    local npr = r(npr)
    forvalues j = 1/`npr' {
        local yd`j' `r(y`j')'
        local xd`j' `r(x`j')'
    }
    _gpl_plots `name'
    local n = r(n)
    local regs `r(regs)'
    local yon
    local xon
    local both
    forvalues i = 1/`n' {
        local j : word `i' of `regs'
        local pr .`name'.plotregion`j'
        local yn
        local xn
        capture {
            local yv = ``pr'.plot`i'.yvar'
            local xv = ``pr'.plot`i'.xvar'
            local yn ``pr'.plot`i'.serset.sers[`yv'].name'
            local xn ``pr'.plot`i'.serset.sers[`xv'].name'
        }
        if "`yn'"=="`yvar'" local yon `yon' `yd`j''
        if "`xn'"=="`xvar'" local xon `xon' `xd`j''
        if "`yn'"=="`yvar'" & "`xn'"=="`xvar'" local both `both' `j'
    }
    local yon : list uniq yon
    local xon : list uniq xon
    * regions that carry the axes the options name
    local cand
    forvalues j = 1/`npr' {
        local yok : list yax in yd`j'
        local xok : list xax in xd`j'
        if ("`yax'"=="" | `yok') & ("`xax'"=="" | `xok') local cand `cand' `j'
    }
    if "`cand'"=="" {
        local what = trim(cond("`xax'"!="", "xaxis(`xax')", "") + " " + cond("`yax'"!="", "yaxis(`yax')", ""))
        di as err "gpolish: graph {bf:`name'} has no plot on `what'"
        exit 198
    }
    local reg 0
    foreach j of local cand {
        if `: list j in both' {
            local reg `j'
            continue, break
        }
    }
    if !`reg' {
        foreach j of local cand {
            local yi : list yd`j' & yon
            local xi : list xd`j' & xon
            if ("`yon'"=="" | "`yi'"!="") & ("`xon'"=="" | "`xi'"!="") {
                local reg `j'
                continue, break
            }
        }
    }
    if !`reg' {
        foreach d in y x {
            local opt = cond("`d'"=="y", "yaxis", "xaxis")
            local a : word 1 of ``d'on'
            if "``d'ax'"!="" & "``d'on'"!="" & !`: list `d'ax in `d'on' {
                local alist : subinstr local `d'on " " " and ", all
                di as err "gpolish ptlabel: `d'() variable {bf:``d'var'} is drawn on `d' axis `alist', not on `d' axis ``d'ax'."
                di as err "  Use {bf:`opt'(`a')} so the labels use that axis's scale."
                exit 198
            }
        }
        * the options rule out the only regions that fit; name the axes of the first region that fits
        forvalues j = 1/`npr' {
            local yi : list yd`j' & yon
            local xi : list xd`j' & xon
            if ("`yon'"=="" | "`yi'"!="") & ("`xon'"=="" | "`xi'"!="") {
                if "`yi'"=="" local yi `yd`j''
                if "`xi'"=="" local xi `xd`j''
                local ys : word 1 of `yi'
                local xs : word 1 of `xi'
                local use
                local what
                if "`xax'"!="" {
                    local use `use' xaxis(`xs')
                    local what `what' xaxis(`xax')
                }
                if "`yax'"!="" {
                    local use `use' yaxis(`ys')
                    local what `what' yaxis(`yax')
                }
                di as err "gpolish ptlabel: no plot region with `what' carries the axes that x() variable {bf:`xvar'} and y() variable {bf:`yvar'} are drawn on."
                di as err "  Use {bf:`use'} so the labels use those axes' scales."
                exit 198
            }
        }
        di as err "gpolish ptlabel: no plot region of graph {bf:`name'} carries both the y axis of {bf:`yvar'} (`yon') and the x axis of {bf:`xvar'} (`xon')."
        di as err "  ptlabel reads both values in one plot region, so it cannot label these points."
        exit 198
    }
    return scalar region = `reg'
end

program _gpl_segcheck
    args segments
    if `segments' < 1 {
        di as err "gpolish: segments() must be a positive integer"
        exit 198
    }
end

* ================================================================ callout
program _gpl_callout
    syntax anything(name=txt id="text" everything), [at(string) to(string) ///
        FRom(string) name(string) CURve(real 0.25) SIZe(real 8.8) COLor(string) ///
        LColor(string) ALign(string) HEADsize(real 4.5) SEGments(integer 24) LWidth(string) ANGle(real 0) HALO noARROW ///
        FILL(string) BORder(string) PAD(real 5) ISNOTE XAXis(string) YAXis(string)]
    local cmd = cond("`isnote'"!="", "note", "callout")
    if `"`at'"'=="" & `"`to'"'=="" {
        di as err "gpolish `cmd': give at(x y) for the text, to(x y) for the arrow target, or both"
        exit 198
    }
    _gpl_segcheck `segments'
    local nonblank 0
    foreach l of local txt {
        if trim(`"`l'"')!="" local nonblank 1
    }
    if !`nonblank' {
        di as err "gpolish `cmd': text is empty"
        exit 198
    }
    * positions first: an expression in them may read the caller's r()
    foreach o in at to from {
        if `"``o''"'!="" _gpl_xy `o' `"``o''"'
    }
    _gpl_name `name'
    local name `r(name)'
    _gpl_axpos `name' "`xaxis'" "`yaxis'"
    foreach o in at to from {
        if `"``o''"'!="" _gpl_toreg1 `name' "`_gpl_reg'" `o' ``o'x' ``o'y'
    }
    * an arrow target off the axes is almost always a typo or the wrong axis; a box placed by
    * hand with at() may sit in the graph margin on purpose, so it gets a note only
    if `"`to'"'!="" _gpl_inplot `cmd' to `name' `tox' `toy' err
    foreach o in at from {
        if `"``o''"'!="" _gpl_inplot `cmd' `o' `name' ``o'x' ``o'y' note
    }
    if "`color'"=="" local color "26 26 26"
    if "`align'"=="" local align left
    if "`isnote'"!="" & "`fill'"=="" {
        * a shaded finding box in the scheme's warm accent
        local fill "253 243 220"
        if "`border'"=="" local border "224 161 0"
    }
    * text box size in ems
    local nl 0
    local w 0
    foreach l of local txt {
        local ++nl
        mata: st_local("wq", strofreal(_gpl_textw(st_global("GPL_FONT"), st_local("l"), 0)))
        local w = max(`w', `wq')
    }
    _gpl_geom, name(`name')
    local gpi = r(gpi)
    local xa = r(xa)
    local xb = r(xb)
    local ya = r(ya)
    local yb = r(yb)
    local xlog = r(xlog)
    local ylog = r(ylog)
    local fs = `size'/72*`gpi'
    local bw = `w'*`fs'
    local bh = `nl'*`fs'*1.3
    if "`fill'"!="" {
        * the padded box is what must fit and what the arrow leaves from
        local bw = `bw' + 2*`pad'/72*`gpi'
        local bh = `bh' + 1.4*`pad'/72*`gpi'
    }
    tempname B
    if `"`at'"'=="" {
        * automatic placement around the target, avoiding what is already drawn
        _gpl_obstacles `name'
        _gpl_geom, name(`name')
        if `bw' > r(gx1) - r(gx0) | `bh' > r(gy1) - r(gy0) {
            di as err "gpolish `cmd': the text is wider or taller than the plot region; shorten it, split it into lines, or use a smaller size()"
            exit 198
        }
        local gtx = `xa' + `xb'*cond(`xlog', ln(`tox'), `tox')
        local gty = `ya' + `yb'*cond(`ylog', ln(`toy'), `toy')
        mata: _gpl_autobox("`B'", `gtx', `gty', `bw', `bh', `fs', `r(gx0)', `r(gx1)', `r(gy0)', `r(gy1)')
        if `B'[1,5] > 0 _gpl_note crowded 1
        local align left
    }
    else {
        local gax = `xa' + `xb'*cond(`xlog', ln(`atx'), `atx')
        local gay = `ya' + `yb'*cond(`ylog', ln(`aty'), `aty')
        local x0 = `gax' - cond("`align'"=="right", `bw', cond("`align'"=="center", `bw'/2, 0))
        matrix `B' = (`x0', `gay' - `bh'/2, `x0' + `bw', `gay' + `bh'/2, 0)
    }
    * anchor of the text box in data units (left-middle, centre or right-middle). Stata draws a
    * boxed text with the box edge on the anchor and the text inset by the padding, so the drawn
    * box is the rectangle B used for placement and for the arrow
    local gx = cond("`align'"=="right", `B'[1,3], cond("`align'"=="center", (`B'[1,1]+`B'[1,3])/2, `B'[1,1]))
    local gy = (`B'[1,2] + `B'[1,4])/2
    local px = (`gx' - `xa')/`xb'
    local py = (`gy' - `ya')/`yb'
    if `xlog' local px = exp(`px')
    if `ylog' local py = exp(`py')
    local ba = cond("`align'"=="right", "west", cond("`align'"=="center", "center", "east"))
    _gpl_addtext, name(`name') x(`px') y(`py') lines(`txt') size(`size') color("`color'") hz(`align') ba(`ba') angle(`angle') `halo' fill(`fill') border(`border') pad(`pad')
    if `"`to'"'=="" | "`arrow'"!="" exit
    local gtx = `xa' + `xb'*cond(`xlog', ln(`tox'), `tox')
    local gty = `ya' + `yb'*cond(`ylog', ln(`toy'), `toy')
    if `"`from'"'!="" {
        local gfx = `xa' + `xb'*cond(`xlog', ln(`fromx'), `fromx')
        local gfy = `ya' + `yb'*cond(`ylog', ln(`fromy'), `fromy')
    }
    else {
        * start the arrow at the point of the text box nearest the target
        local pad = 0.35*`fs'
        local gfx = max(`B'[1,1]-`pad', min(`gtx', `B'[1,3]+`pad'))
        local gfy = max(`B'[1,2]-`pad', min(`gty', `B'[1,4]+`pad'))
    }
    if abs(`gtx'-`gfx') + abs(`gty'-`gfy') < 1 {
        di as txt "note: gpolish `cmd': the arrow would start on its own target (to() lies inside the text, or from() equals to()); no arrow is drawn"
        exit
    }
    tempname P
    mata: _gpl_bezier("`P'", (`gfx', `gfy'), (`gtx', `gty'), `curve', `segments', `headsize'/72*`gpi', ///
        `xa', `xb', `ya', `yb', `xlog', `ylog', 0.3*`fs')
    capture confirm matrix `P'
    if _rc exit
    local rows = rowsof(`P')
    forvalues i = 1/`rows' {
        _gpl_addline, name(`name') seg(`=`P'[`i',1]' `=`P'[`i',2]' `=`P'[`i',3]' `=`P'[`i',4]') lcolor(`lcolor') lwidth(`lwidth')
    }
end

* ================================================================ arrow
program _gpl_arrow
    syntax , FRom(string) to(string) [name(string) CURve(real 0) HEADsize(real 4.5) ///
        SEGments(integer 24) LColor(string) LWidth(string) SHRink(real 0) XAXis(string) YAXis(string)]
    _gpl_segcheck `segments'
    _gpl_xy from `"`from'"'
    _gpl_xy to `"`to'"'
    _gpl_name `name'
    local name `r(name)'
    _gpl_axpos `name' "`xaxis'" "`yaxis'"
    _gpl_toreg1 `name' "`_gpl_reg'" from `fromx' `fromy'
    _gpl_toreg1 `name' "`_gpl_reg'" to `tox' `toy'
    _gpl_inplot arrow from `name' `fromx' `fromy' note
    _gpl_inplot arrow to `name' `tox' `toy' note
    _gpl_geom, name(`name')
    local gfx = r(xa) + r(xb)*cond(r(xlog), ln(`fromx'), `fromx')
    local gfy = r(ya) + r(yb)*cond(r(ylog), ln(`fromy'), `fromy')
    local gtx = r(xa) + r(xb)*cond(r(xlog), ln(`tox'), `tox')
    local gty = r(ya) + r(yb)*cond(r(ylog), ln(`toy'), `toy')
    if abs(`gtx'-`gfx') + abs(`gty'-`gfy') < 1 {
        di as err "gpolish arrow: from() and to() are the same point; an arrow needs two different ends"
        exit 198
    }
    tempname P
    mata: _gpl_bezier("`P'", (`gfx', `gfy'), (`gtx', `gty'), `curve', `segments', `headsize'/72*`r(gpi)', ///
        `r(xa)', `r(xb)', `r(ya)', `r(yb)', `r(xlog)', `r(ylog)', `shrink'/72*`r(gpi)')
    capture confirm matrix `P'
    if _rc {
        di as txt "note: gpolish arrow: shrink() leaves no arrow to draw"
        exit
    }
    local rows = rowsof(`P')
    forvalues i = 1/`rows' {
        _gpl_addline, name(`name') seg(`=`P'[`i',1]' `=`P'[`i',2]' `=`P'[`i',3]' `=`P'[`i',4]') lcolor(`lcolor') lwidth(`lwidth')
    }
end

* ================================================================ brace
* a curly brace between two points, with an optional label at its tip
program _gpl_brace
    syntax [anything(name=txt everything)], FRom(string) to(string) [name(string) ///
        Width(real 7) FLIP SIZe(real 8.8) COLor(string) LColor(string) LWidth(string) GAP(real 4) ///
        XAXis(string) YAXis(string)]
    _gpl_xy from `"`from'"'
    _gpl_xy to `"`to'"'
    _gpl_name `name'
    local name `r(name)'
    _gpl_axpos `name' "`xaxis'" "`yaxis'"
    _gpl_toreg1 `name' "`_gpl_reg'" from `fromx' `fromy'
    _gpl_toreg1 `name' "`_gpl_reg'" to `tox' `toy'
    _gpl_inplot brace from `name' `fromx' `fromy' note
    _gpl_inplot brace to `name' `tox' `toy' note
    _gpl_geom, name(`name')
    local gpi = r(gpi)
    local xa = r(xa)
    local xb = r(xb)
    local ya = r(ya)
    local yb = r(yb)
    local xlog = r(xlog)
    local ylog = r(ylog)
    local gfx = `xa' + `xb'*cond(`xlog', ln(`fromx'), `fromx')
    local gfy = `ya' + `yb'*cond(`ylog', ln(`fromy'), `fromy')
    local gtx = `xa' + `xb'*cond(`xlog', ln(`tox'), `tox')
    local gty = `ya' + `yb'*cond(`ylog', ln(`toy'), `toy')
    if abs(`gtx'-`gfx') + abs(`gty'-`gfy') < 1 {
        di as err "gpolish brace: from() and to() are the same point; a brace needs two different ends"
        exit 198
    }
    tempname P T
    mata: _gpl_bracepath("`P'", "`T'", (`gfx', `gfy'), (`gtx', `gty'), `width'/72*`gpi', "`flip'"!="", `gap'/72*`gpi', ///
        `xa', `xb', `ya', `yb', `xlog', `ylog')
    local rows = rowsof(`P')
    forvalues i = 1/`rows' {
        _gpl_addline, name(`name') seg(`=`P'[`i',1]' `=`P'[`i',2]' `=`P'[`i',3]' `=`P'[`i',4]') lcolor(`lcolor') lwidth(`lwidth')
    }
    if `"`txt'"'!="" {
        * label sits beyond the tip, aligned away from the brace
        local nx = `T'[1,3]
        local ny = `T'[1,4]
        if abs(`nx') >= abs(`ny') {
            local hz = cond(`nx' > 0, "left", "right")
            local ba = cond(`nx' > 0, "east", "west")
        }
        else {
            local hz center
            local ba = cond(`ny' > 0, "north", "south")
        }
        _gpl_addtext, name(`name') x(`=`T'[1,1]') y(`=`T'[1,2]') lines(`txt') size(`size') color("`color'") hz(`hz') ba(`ba')
    }
end

* ================================================================ bracket
* Vertical form: a square bracket from y0() to y1() at x(); its ticks point right on screen,
* or left with left; an optional label sits on the other side of the spine.
* Horizontal form: a bracket from x0() to x1() at y(); its ticks point down on screen, or up
* with below; an optional label is centred on the other side of the spine.
program _gpl_bracket
    syntax [anything(name=txt everything)], [x(string) y0(string) y1(string) y(string) x0(string) x1(string) ///
        name(string) TICK(real 4) LColor(string) LWidth(string) LEFT BELOW SIZe(real 8.8) COLor(string) ///
        GAP(real 4) XAXis(string) YAXis(string)]
    local nv = (`"`x'"'!="") + (`"`y0'"'!="") + (`"`y1'"'!="")
    local nh = (`"`y'"'!="") + (`"`x0'"'!="") + (`"`x1'"'!="")
    if !((`nv'==3 & `nh'==0) | (`nv'==0 & `nh'==3)) {
        di as err "gpolish bracket: give either x(), y0() and y1() (a vertical bracket) or y(), x0() and x1()"
        di as err "  (a horizontal bracket), and not a mix of the two"
        exit 198
    }
    local horiz = (`nh'==3)
    if `horiz' & "`left'"!="" {
        di as err "gpolish bracket: left goes with the vertical form; use below with y(), x0() and x1()"
        exit 198
    }
    if !`horiz' & "`below'"!="" {
        di as err "gpolish bracket: below goes with the horizontal form; use left with x(), y0() and y1()"
        exit 198
    }
    if `horiz' {
        _gpl_val y `"`y'"'
        _gpl_val x0 `"`x0'"'
        _gpl_val x1 `"`x1'"'
        if `x0v'==`x1v' {
            di as err "gpolish bracket: x0() and x1() are the same; a bracket needs two different ends"
            exit 198
        }
    }
    else {
        _gpl_val x `"`x'"'
        _gpl_val y0 `"`y0'"'
        _gpl_val y1 `"`y1'"'
        if `y0v'==`y1v' {
            di as err "gpolish bracket: y0() and y1() are the same; a bracket needs two different ends"
            exit 198
        }
    }
    _gpl_name `name'
    local name `r(name)'
    _gpl_axpos `name' "`xaxis'" "`yaxis'"
    if `horiz' {
        local b0x `x0v'
        local b1x `x1v'
        local b0y `yv'
        local b1y `yv'
    }
    else {
        local b0x `xv'
        local b1x `xv'
        local b0y `y0v'
        local b1y `y1v'
    }
    _gpl_toreg1 `name' "`_gpl_reg'" b0 `b0x' `b0y'
    _gpl_toreg1 `name' "`_gpl_reg'" b1 `b1x' `b1y'
    _gpl_geom, name(`name')
    * device units run left to right and bottom to top on screen whatever the axis direction
    local g0x = r(xa) + r(xb)*cond(r(xlog), ln(`b0x'), `b0x')
    local g1x = r(xa) + r(xb)*cond(r(xlog), ln(`b1x'), `b1x')
    local g0y = r(ya) + r(yb)*cond(r(ylog), ln(`b0y'), `b0y')
    local g1y = r(ya) + r(yb)*cond(r(ylog), ln(`b1y'), `b1y')
    if `horiz' {
        local s = cond("`below'"!="", 1, -1)
        local y2 = (`g0y' + `s'*`tick'/72*r(gpi) - r(ya))/r(yb)
        if r(ylog) local y2 = exp(`y2')
        local yt = (`g0y' - `s'*`gap'/72*r(gpi) - r(ya))/r(yb)
        if r(ylog) local yt = exp(`yt')
        local xm = ((`g0x' + `g1x')/2 - r(xa))/r(xb)
        if r(xlog) local xm = exp(`xm')
        local segs `" "`b0x' `b0y' `b1x' `b0y'" "`b0x' `b0y' `b0x' `y2'" "`b1x' `b0y' `b1x' `y2'" "'
    }
    else {
        local s = cond("`left'"!="", -1, 1)
        local x2 = (`g0x' + `s'*`tick'/72*r(gpi) - r(xa))/r(xb)
        if r(xlog) local x2 = exp(`x2')
        local xt = (`g0x' - `s'*`gap'/72*r(gpi) - r(xa))/r(xb)
        if r(xlog) local xt = exp(`xt')
        local ym = ((`g0y' + `g1y')/2 - r(ya))/r(yb)
        if r(ylog) local ym = exp(`ym')
        local segs `" "`b0x' `b0y' `b0x' `b1y'" "`b0x' `b0y' `x2' `b0y'" "`b0x' `b1y' `x2' `b1y'" "'
    }
    foreach sg of local segs {
        _gpl_addline, name(`name') seg(`sg') lcolor(`lcolor') lwidth(`lwidth')
    }
    if `"`txt'"'!="" {
        if `horiz' {
            local ba = cond(`s' > 0, "south", "north")
            _gpl_addtext, name(`name') x(`xm') y(`yt') lines(`txt') size(`size') color("`color'") hz(center) ba(`ba')
        }
        else {
            local hz = cond(`s' > 0, "right", "left")
            local ba = cond(`s' > 0, "west", "east")
            _gpl_addtext, name(`name') x(`xt') y(`ym') lines(`txt') size(`size') color("`color'") hz(`hz') ba(`ba')
        }
    }
end

* ================================================================ legend
program _gpl_legend
    syntax [, name(string) noBOLD PLOTs(numlist integer >0)]
    _gpl_name `name'
    local name `r(name)'
    _gpl_plots `name'
    local n = r(n)
    local regs `r(regs)'
    if "`.`name'.legend.draw_view.setting'"!="yes" {
        di as txt "note: graph {bf:`name'} shows no legend; nothing to colour"
        exit
    }
    * each legend slot is matched to the plot its key draws, so legend(order()) is followed;
    * plots() names plot numbers, not legend slots
    local nk `.`name'.legend.plotregion1.key.arrnels'
    if "`nk'"=="" local nk 0
    forvalues k = 1/`nk' {
        local okey `"`.`name'.legend.plotregion1.key[`k'].view.objkey'"'
        local i 0
        forvalues ii = 1/`n' {
            local rr : word `ii' of `regs'
            if `"`.`name'.plotregion`rr'.plot`ii'.objkey'"'==`"`okey'"' & `"`okey'"'!="" {
                local i `ii'
                continue, break
            }
        }
        if `i'==0 continue
        if "`plots'"!="" {
            local inl : list i in plots
            if !`inl' continue
        }
        local rg : word `i' of `regs'
        local p .`name'.plotregion`rg'.plot`i'
        local t ``p'.type.setting'
        if inlist("`t'","line","connected","rline","function") local c ``p'.style.line.color.rgb'
        else if inlist("`t'","bar","area","rarea","rbar") local c ``p'.style.area.shadestyle.color.rgb'
        else local c ``p'.style.marker.fillcolor.rgb'
        local c : list retokenize c
        capture _gpl_ge `name' .legend.plotregion1.label[`k'].style.editstyle color("`c'") editcopy
        if _rc continue
        if "`bold'"=="" {
            * every line of the label is kept; each is made bold unless it already is, or unless a
            * literal } in it would close the bold tag early
            local nl `.`name'.legend.plotregion1.label[`k'].text.arrnels'
            if "`nl'"=="" local nl 0
            local redo 0
            forvalues q = 1/`nl' {
                local s`q' `"`.`name'.legend.plotregion1.label[`k'].text[`q']'"'
                mata: st_local("s`q'", _gpl_esc(st_local("s`q'")))
                mata: st_local("ok`q'", strofreal(_gpl_bfok(st_local("s`q'"))))
                if substr(`"`s`q''"',1,4)!="{bf:" & `ok`q'' local redo 1
            }
            if `redo' {
                _gpl_ge `name' .legend.plotregion1.label[`k'].text = {}
                forvalues q = 1/`nl' {
                    if substr(`"`s`q''"',1,4)!="{bf:" & `ok`q'' _gpl_ge `name' .legend.plotregion1.label[`k'].text.Arrpush `"{bf:`s`q''}"'
                    else _gpl_ge `name' .legend.plotregion1.label[`k'].text.Arrpush `"`s`q''"'
                }
            }
        }
    }
end

* ================================================================ ptlabel
program _gpl_ptlabel
    syntax varname [if] [in], x(varname numeric) y(varname numeric) [name(string) SIZe(real 8.6) ///
        COLor(string) OFFset(real 3) MSize(real 6) HALO noLEADer LColor(string) LWidth(string) ///
        XAXis(string) YAXis(string) MAXLabels(integer 1000)]
    _gpl_name `name'
    local name `r(name)'
    if `maxlabels' < 1 {
        di as err "gpolish ptlabel: maxlabels() must be 1 or more"
        exit 198
    }
    marksample touse, novarlist strok
    * a numeric variable labels with its value label, else its display format, as mlabel() does
    capture confirm string variable `varlist'
    if _rc {
        tempvar lab
        local vl : value label `varlist'
        if "`vl'"!="" quietly decode `varlist', gen(`lab')
        else quietly gen strL `lab' = ""
        local fmt : format `varlist'
        quietly replace `lab' = string(`varlist', "`fmt'") if `lab'=="" & !missing(`varlist')
        local varlist `lab'
    }
    quietly count if `touse' & !missing(`x', `y') & `varlist'!=""
    if r(N)==0 {
        di as txt "note: gpolish ptlabel: no observations to label (check the if/in condition and x(), y())"
        exit
    }
    * x() and y() are read on the plot region that draws them (or on the axes named by xaxis() and
    * yaxis()); labels go into plot region 1
    _gpl_axnum "`xaxis'" "`yaxis'"
    _gpl_ptregion `name' `x' `y' "`xaxis'" "`yaxis'"
    local _gpl_reg = r(region)
    _gpl_obstacles `name'
    _gpl_geom, name(`name') region(`_gpl_reg')
    local ixa = r(xa)
    local ixb = r(xb)
    local iya = r(ya)
    local iyb = r(yb)
    local ixlog = r(xlog)
    local iylog = r(ylog)
    _gpl_geom, name(`name')
    local gpi = r(gpi)
    local xa = r(xa)
    local xb = r(xb)
    local ya = r(ya)
    local yb = r(yb)
    local xlog = r(xlog)
    local ylog = r(ylog)
    tempvar gx gy sel
    quietly {
        gen double `gx' = `ixa' + `ixb'*cond(`ixlog', ln(`x'), `x')
        gen double `gy' = `iya' + `iyb'*cond(`iylog', ln(`y'), `y')
        gen byte `sel' = `touse' & !missing(`gx', `gy') & `varlist'!=""
        count if `sel'
    }
    if r(N)==0 {
        di as txt "note: gpolish ptlabel: none of the selected points is drawn (zero or negative values on a log axis); nothing to label"
        exit
    }
    * points outside the axis range of the plot region are not drawn, so they are not labelled
    _gpl_geom, name(`name')
    local tol = 0.001*max(r(gx1)-r(gx0), r(gy1)-r(gy0))
    local bx0 = r(gx0) - `tol'
    local bx1 = r(gx1) + `tol'
    local by0 = r(gy0) - `tol'
    local by1 = r(gy1) + `tol'
    quietly count if `sel'
    local nin = r(N)
    quietly replace `sel' = 0 if `sel' & (`gx' < `bx0' | `gx' > `bx1' | `gy' < `by0' | `gy' > `by1')
    quietly count if `sel'
    local nsel = r(N)
    if `nsel' < `nin' {
        di as txt "note: gpolish ptlabel: `=`nin'-`nsel'' selected point(s) lie outside the plot region and were not labelled"
    }
    if `nsel'==0 {
        di as txt "note: gpolish ptlabel: none of the selected points is drawn inside the plot region; nothing to label"
        exit
    }
    if `nsel' > `maxlabels' {
        di as err "gpolish ptlabel: `nsel' points are selected, more than maxlabels(`maxlabels');"
        di as err "         use if/in to label fewer points, or raise maxlabels()"
        exit 198
    }
    if `nsel' > 300 {
        di as txt "note: gpolish ptlabel: placing `nsel' labels; run time grows quickly with the number of labels"
        di as txt "      (about 40 seconds for 600 labels); use if/in to label fewer points"
    }
    * a label wider than the plot region cannot be placed anywhere inside it
    _gpl_geom, name(`name')
    mata: st_local("nwide", strofreal(_gpl_skipwide("`varlist'", "`sel'", `size'/72*`gpi', `r(gx1)'-`r(gx0)')))
    if `nwide' > 0 {
        di as txt "note: gpolish ptlabel: `nwide' label(s) are wider than the plot region and were skipped; shorten them or use a smaller size()"
        quietly count if `sel'
        if r(N)==0 exit
    }
    _gpl_geom, name(`name')
    tempname R
    mata: _gpl_place("`gx'", "`gy'", "`varlist'", "`sel'", "`R'", `size'/72*`gpi', `msize'/72*`gpi'/2, ///
        `offset'/72*`gpi', `r(gx0)', `r(gx1)', `r(gy0)', `r(gy1)', "`leader'"=="")
    if "`lcolor'"=="" local lcolor "150 150 150"
    if "`lwidth'"=="" local lwidth vthin
    local nl = rowsof(`R')
    local nlead 0
    local bad 0
    forvalues i = 1/`nl' {
        local obs = `R'[`i',1]
        local px = (`R'[`i',2] - `xa')/`xb'
        local py = (`R'[`i',3] - `ya')/`yb'
        if `xlog' local px = exp(`px')
        if `ylog' local py = exp(`py')
        local h = `R'[`i',4]
        local hz = cond(`h'==-1, "left", cond(`h'==1, "right", "center"))
        local ba : word `=`R'[`i',5]' of east west north south center
        local t = `varlist'[`obs']
        mata: st_local("t", _gpl_esc(st_local("t")))
        local bad = `bad' + (`R'[`i',6] > 0)
        _gpl_addtext, name(`name') x(`px') y(`py') lines(`"`t'"') size(`size') color("`color'") hz(`hz') ba(`ba') `halo'
        if `R'[`i',7] == 1 {
            * leader line from the point to a label placed farther out
            local s
            forvalues c = 8/11 {
                local v = `R'[`i',`c']
                if inlist(`c', 8, 10) local v = cond(`xlog', exp((`v'-`xa')/`xb'), (`v'-`xa')/`xb')
                else local v = cond(`ylog', exp((`v'-`ya')/`yb'), (`v'-`ya')/`yb')
                local s `s' `v'
            }
            _gpl_addline, name(`name') seg(`s') lcolor(`lcolor') lwidth(`lwidth')
            local ++nlead
        }
    }
    if `bad' > 0 _gpl_note crowded `bad'
end

* ================================================================ render hand-off and limits
program _gpl_render
    syntax [, name(string) *]
    capture which gr2mpl
    if _rc {
        di as err "gpolish render needs gr2mpl (the matplotlib translator shipped with gpolish) on the adopath"
        exit 111
    }
    if "`name'"=="" {
        capture quietly graph describe
        local name `r(fn)'
        if _rc | "`name'"=="" {
            di as err "gpolish: no graph in memory"
            exit 111
        }
    }
    gr2mpl, name(`name') `options'
end

program _gpl_limits
    di as txt _n "{bf:What gpolish can and cannot draw inside Stata}" _n
    di as txt "  Works in Stata" _col(43) "Needs {bf:gpolish render} (matplotlib)"
    di as txt "  {hline 38}  {hline 44}"
    di as txt "  bold, left-aligned titles" _col(43) "text at angles other than 0/90/270 degrees"
    di as txt "  end-of-line labels with repel" _col(43) "soft white halo behind text (Stata: {bf:halo} = white box)"
    di as txt "  value columns, end dots" _col(43) "by(), bar, box, dot and combined graphs in the same style"
    di as txt "  auto-placed point labels and callouts" _col(43) "rounded corners on boxed text ({bf:gr2mpl, roundbox})"
    di as txt "  curved arrows (open heads), brackets"
    di as txt "  legend text coloured like its keys" _n
    di as txt "  Neither draws different colours inside one line of text (colour whole labels instead),"
    di as txt "  filled arrow heads, or pie charts." _n
    di as txt "  The output of gpolish is still a Stata graph (edit, combine, export to any format)."
    di as txt "  {bf:gpolish render} carries every gpolish edit into the matplotlib version and writes a PNG, PDF, SVG or JPG file."
end

mata:
// s with each $name and ${name} replaced by the global's contents, as macro expansion does
string scalar _gpl_gexp(string scalar s)
{
    real scalar i, j, n
    string scalar out, ch, nm

    out = ""
    n = strlen(s)
    i = 1
    while (i <= n) {
        ch = substr(s, i, 1)
        if (ch == char(36) & i < n) {
            if (substr(s, i+1, 1) == "{") {
                j = strpos(substr(s, i+2, .), "}")
                if (j > 0) {
                    out = out + st_global(substr(s, i+2, j-1))
                    i = i + j + 2
                    continue
                }
            }
            else if (regexm(substr(s, i+1, 1), "[A-Za-z_]")) {
                j = i + 1
                while (j <= n & regexm(substr(s, j, 1), "[A-Za-z0-9_]")) j++
                nm = substr(s, i+1, j-i-1)
                out = out + st_global(nm)
                i = j
                continue
            }
        }
        out = out + ch
        i++
    }
    return(out)
}
// ---------------------------------------------------------------- text escaping
// $ and a backtick that does not open a compound quote become SMCL character codes
string scalar _gpl_esc(string scalar s)
{
    real scalar i
    string scalar out
    string scalar ch

    out = ""
    for (i=1; i<=strlen(s); i++) {
        ch = substr(s, i, 1)
        if (ch == char(36)) out = out + "{c 36}"
        else if (ch == char(96) & substr(s, i+1, 1) != char(34)) out = out + "{c 96}"
        else out = out + ch
    }
    return(out)
}

// a label can be wrapped in {bf:...} only if its braces balance; a literal } would close the tag early
real scalar _gpl_bfok(string scalar s)
{
    real colvector c
    c = ascii(s)'
    if (rows(c) == 0) return(1)
    return(sum(c :== 123) == sum(c :== 125))
}

// ---------------------------------------------------------------- font metrics
real rowvector _gpl_fontw(string scalar font, real scalar bold)
{
    if (font == "open sans") {
        if (bold) return((0.26, 0.286, 0.472, 0.646, 0.571, 0.901, 0.75, 0.266, 0.339, 0.339, 0.545, 0.571, 0.29, 0.322, 0.285, 0.413, 
            0.571, 0.571, 0.571, 0.571, 0.571, 0.571, 0.571, 0.571, 0.571, 0.571, 0.285, 0.29, 0.571, 0.571, 0.571, 0.477, 
            0.897, 0.69, 0.672, 0.637, 0.74, 0.56, 0.549, 0.724, 0.765, 0.331, 0.331, 0.664, 0.565, 0.943, 0.813, 0.796, 
            0.628, 0.796, 0.66, 0.551, 0.579, 0.756, 0.65, 0.967, 0.667, 0.624, 0.579, 0.331, 0.413, 0.331, 0.532, 0.411, 
            0.607, 0.604, 0.633, 0.514, 0.633, 0.591, 0.387, 0.565, 0.657, 0.305, 0.305, 0.62, 0.305, 0.982, 0.657, 0.619, 
            0.633, 0.633, 0.454, 0.497, 0.434, 0.657, 0.569, 0.856, 0.578, 0.569, 0.488, 0.394, 0.551, 0.394, 0.571))
        return((0.26, 0.267, 0.401, 0.646, 0.572, 0.823, 0.73, 0.221, 0.296, 0.296, 0.552, 0.572, 0.245, 0.322, 0.266, 0.367, 
            0.572, 0.572, 0.572, 0.572, 0.572, 0.572, 0.572, 0.572, 0.572, 0.572, 0.266, 0.266, 0.572, 0.572, 0.572, 0.429, 
            0.899, 0.633, 0.648, 0.631, 0.729, 0.556, 0.516, 0.728, 0.738, 0.279, 0.267, 0.614, 0.519, 0.903, 0.754, 0.779, 
            0.602, 0.779, 0.618, 0.549, 0.553, 0.728, 0.595, 0.926, 0.577, 0.56, 0.571, 0.329, 0.367, 0.329, 0.542, 0.448, 
            0.577, 0.556, 0.613, 0.476, 0.613, 0.561, 0.339, 0.548, 0.614, 0.253, 0.253, 0.525, 0.253, 0.93, 0.614, 0.604, 
            0.613, 0.613, 0.408, 0.477, 0.353, 0.614, 0.501, 0.778, 0.524, 0.504, 0.468, 0.379, 0.551, 0.379, 0.572))
    }
    if (font == "helvetica") {
        if (bold) return((0.295, 0.295, 0.376, 0.589, 0.589, 0.942, 0.707, 0.202, 0.353, 0.353, 0.412, 0.619, 0.295, 0.353, 0.295, 0.295, 
            0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.295, 0.295, 0.619, 0.619, 0.619, 0.589, 
            1.076, 0.707, 0.707, 0.765, 0.765, 0.707, 0.648, 0.825, 0.765, 0.295, 0.53, 0.707, 0.589, 0.883, 0.765, 0.825, 
            0.707, 0.825, 0.765, 0.707, 0.648, 0.765, 0.707, 1.001, 0.707, 0.707, 0.648, 0.295, 0.295, 0.295, 0.497, 0.589, 
            0.353, 0.589, 0.589, 0.53, 0.589, 0.589, 0.295, 0.589, 0.589, 0.235, 0.235, 0.53, 0.235, 0.883, 0.589, 0.589, 
            0.589, 0.589, 0.353, 0.53, 0.295, 0.589, 0.53, 0.765, 0.53, 0.53, 0.53, 0.354, 0.276, 0.354, 0.619))
        return((0.278, 0.278, 0.355, 0.556, 0.556, 0.889, 0.667, 0.191, 0.333, 0.333, 0.389, 0.584, 0.278, 0.333, 0.278, 0.278, 
            0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.278, 0.278, 0.584, 0.584, 0.584, 0.556, 
            1.015, 0.667, 0.667, 0.722, 0.722, 0.667, 0.611, 0.778, 0.722, 0.278, 0.5, 0.667, 0.556, 0.833, 0.722, 0.778, 
            0.667, 0.778, 0.722, 0.667, 0.611, 0.722, 0.667, 0.944, 0.667, 0.667, 0.611, 0.278, 0.278, 0.278, 0.469, 0.556, 
            0.333, 0.556, 0.556, 0.5, 0.556, 0.556, 0.278, 0.556, 0.556, 0.222, 0.222, 0.5, 0.222, 0.833, 0.556, 0.556, 
            0.556, 0.556, 0.333, 0.5, 0.278, 0.556, 0.5, 0.722, 0.5, 0.5, 0.5, 0.334, 0.26, 0.334, 0.584))
    }
    if (font == "helvetica neue") {
        if (bold) return((0.295, 0.275, 0.452, 0.589, 0.589, 1.06, 0.668, 0.295, 0.275, 0.275, 0.373, 0.636, 0.295, 0.412, 0.295, 0.353, 
            0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.295, 0.295, 0.636, 0.636, 0.636, 0.589, 
            0.848, 0.687, 0.726, 0.765, 0.746, 0.648, 0.608, 0.805, 0.765, 0.275, 0.55, 0.707, 0.589, 0.923, 0.765, 0.806, 
            0.687, 0.806, 0.726, 0.687, 0.608, 0.765, 0.648, 0.982, 0.648, 0.687, 0.648, 0.275, 0.353, 0.275, 0.636, 0.53, 
            0.235, 0.569, 0.629, 0.569, 0.629, 0.569, 0.314, 0.608, 0.589, 0.235, 0.235, 0.55, 0.235, 0.904, 0.589, 0.608, 
            0.629, 0.629, 0.353, 0.53, 0.334, 0.589, 0.53, 0.803, 0.549, 0.53, 0.509, 0.353, 0.235, 0.353, 0.636))
        return((0.278, 0.259, 0.426, 0.556, 0.556, 1, 0.63, 0.278, 0.259, 0.259, 0.352, 0.6, 0.278, 0.389, 0.278, 0.333, 
            0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.278, 0.278, 0.6, 0.6, 0.6, 0.556, 
            0.8, 0.648, 0.685, 0.722, 0.704, 0.611, 0.574, 0.759, 0.722, 0.259, 0.519, 0.667, 0.556, 0.871, 0.722, 0.76, 
            0.648, 0.76, 0.685, 0.648, 0.574, 0.722, 0.611, 0.926, 0.611, 0.648, 0.611, 0.259, 0.333, 0.259, 0.6, 0.5, 
            0.222, 0.537, 0.593, 0.537, 0.593, 0.537, 0.296, 0.574, 0.556, 0.222, 0.222, 0.519, 0.222, 0.853, 0.556, 0.574, 
            0.593, 0.593, 0.333, 0.5, 0.315, 0.556, 0.5, 0.758, 0.518, 0.5, 0.48, 0.333, 0.222, 0.333, 0.6))
    }
    if (font == "arial") {
        if (bold) return((0.278, 0.333, 0.474, 0.556, 0.556, 0.889, 0.722, 0.238, 0.333, 0.333, 0.389, 0.584, 0.278, 0.333, 0.278, 0.278, 
            0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.333, 0.333, 0.584, 0.584, 0.584, 0.611, 
            0.975, 0.722, 0.722, 0.722, 0.722, 0.667, 0.611, 0.778, 0.722, 0.278, 0.556, 0.722, 0.611, 0.833, 0.722, 0.778, 
            0.667, 0.778, 0.722, 0.667, 0.611, 0.722, 0.667, 0.944, 0.667, 0.667, 0.611, 0.333, 0.278, 0.333, 0.584, 0.556, 
            0.333, 0.556, 0.611, 0.556, 0.611, 0.556, 0.333, 0.611, 0.611, 0.278, 0.278, 0.556, 0.278, 0.889, 0.611, 0.611, 
            0.611, 0.611, 0.389, 0.556, 0.333, 0.611, 0.556, 0.778, 0.556, 0.556, 0.5, 0.389, 0.28, 0.389, 0.584))
        return((0.278, 0.278, 0.355, 0.556, 0.556, 0.889, 0.667, 0.191, 0.333, 0.333, 0.389, 0.584, 0.278, 0.333, 0.278, 0.278, 
            0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.278, 0.278, 0.584, 0.584, 0.584, 0.556, 
            1.015, 0.667, 0.667, 0.722, 0.722, 0.667, 0.611, 0.778, 0.722, 0.278, 0.5, 0.667, 0.556, 0.833, 0.722, 0.778, 
            0.667, 0.778, 0.722, 0.667, 0.611, 0.722, 0.667, 0.944, 0.667, 0.667, 0.611, 0.278, 0.278, 0.278, 0.469, 0.556, 
            0.333, 0.556, 0.556, 0.5, 0.556, 0.556, 0.278, 0.556, 0.556, 0.222, 0.222, 0.5, 0.222, 0.833, 0.556, 0.556, 
            0.556, 0.556, 0.333, 0.5, 0.278, 0.556, 0.5, 0.722, 0.5, 0.5, 0.5, 0.334, 0.26, 0.334, 0.584))
    }
    if (font == "arial narrow") {
        if (bold) return((0.228, 0.273, 0.389, 0.456, 0.456, 0.729, 0.592, 0.195, 0.273, 0.273, 0.319, 0.479, 0.228, 0.273, 0.228, 0.228, 
            0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.273, 0.273, 0.479, 0.479, 0.479, 0.501, 
            0.8, 0.592, 0.592, 0.592, 0.592, 0.547, 0.501, 0.638, 0.592, 0.228, 0.456, 0.592, 0.501, 0.683, 0.592, 0.638, 
            0.547, 0.638, 0.592, 0.547, 0.501, 0.592, 0.547, 0.774, 0.547, 0.547, 0.501, 0.273, 0.228, 0.273, 0.479, 0.456, 
            0.273, 0.456, 0.501, 0.456, 0.501, 0.456, 0.273, 0.501, 0.501, 0.228, 0.228, 0.456, 0.228, 0.729, 0.501, 0.501, 
            0.501, 0.501, 0.319, 0.456, 0.273, 0.501, 0.456, 0.638, 0.456, 0.456, 0.41, 0.319, 0.23, 0.319, 0.479))
        return((0.228, 0.228, 0.291, 0.456, 0.456, 0.729, 0.547, 0.157, 0.273, 0.273, 0.319, 0.479, 0.228, 0.273, 0.228, 0.228, 
            0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.456, 0.228, 0.228, 0.479, 0.479, 0.479, 0.456, 
            0.832, 0.547, 0.547, 0.592, 0.592, 0.547, 0.501, 0.638, 0.592, 0.228, 0.41, 0.547, 0.456, 0.683, 0.592, 0.638, 
            0.547, 0.638, 0.592, 0.547, 0.501, 0.592, 0.547, 0.774, 0.547, 0.547, 0.501, 0.228, 0.228, 0.228, 0.385, 0.456, 
            0.273, 0.456, 0.456, 0.41, 0.456, 0.456, 0.228, 0.456, 0.456, 0.182, 0.182, 0.41, 0.182, 0.683, 0.456, 0.456, 
            0.456, 0.456, 0.273, 0.41, 0.228, 0.456, 0.41, 0.592, 0.41, 0.41, 0.41, 0.274, 0.213, 0.274, 0.479))
    }
    if (font == "verdana") {
        if (bold) return((0.342, 0.402, 0.587, 0.867, 0.711, 1.272, 0.862, 0.332, 0.543, 0.543, 0.711, 0.867, 0.361, 0.48, 0.361, 0.689, 
            0.711, 0.711, 0.711, 0.711, 0.711, 0.711, 0.711, 0.711, 0.711, 0.711, 0.402, 0.402, 0.867, 0.867, 0.867, 0.617, 
            0.964, 0.776, 0.762, 0.724, 0.83, 0.683, 0.65, 0.811, 0.837, 0.546, 0.555, 0.771, 0.637, 0.948, 0.847, 0.85, 
            0.733, 0.85, 0.782, 0.71, 0.682, 0.812, 0.764, 1.128, 0.764, 0.737, 0.692, 0.543, 0.689, 0.543, 0.867, 0.711, 
            0.711, 0.668, 0.699, 0.588, 0.699, 0.664, 0.422, 0.699, 0.712, 0.342, 0.403, 0.671, 0.342, 1.058, 0.712, 0.687, 
            0.699, 0.699, 0.497, 0.593, 0.456, 0.712, 0.65, 0.979, 0.669, 0.651, 0.597, 0.711, 0.543, 0.711, 0.867))
        return((0.352, 0.394, 0.459, 0.818, 0.636, 1.076, 0.727, 0.269, 0.454, 0.454, 0.636, 0.818, 0.364, 0.454, 0.364, 0.454, 
            0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.454, 0.454, 0.818, 0.818, 0.818, 0.545, 
            1, 0.684, 0.686, 0.698, 0.771, 0.632, 0.575, 0.775, 0.751, 0.421, 0.455, 0.693, 0.557, 0.843, 0.748, 0.787, 
            0.603, 0.787, 0.695, 0.684, 0.616, 0.732, 0.684, 0.989, 0.685, 0.615, 0.685, 0.454, 0.454, 0.454, 0.818, 0.636, 
            0.636, 0.601, 0.623, 0.521, 0.623, 0.596, 0.352, 0.623, 0.633, 0.274, 0.344, 0.592, 0.274, 0.973, 0.633, 0.607, 
            0.623, 0.623, 0.427, 0.521, 0.394, 0.633, 0.592, 0.818, 0.592, 0.592, 0.525, 0.635, 0.454, 0.635, 0.818))
    }
    if (font == "tahoma") {
        if (bold) return((0.293, 0.343, 0.489, 0.818, 0.637, 1.199, 0.781, 0.275, 0.454, 0.454, 0.637, 0.818, 0.312, 0.431, 0.312, 0.577, 
            0.637, 0.637, 0.637, 0.637, 0.637, 0.637, 0.637, 0.637, 0.637, 0.637, 0.363, 0.363, 0.818, 0.818, 0.818, 0.566, 
            0.92, 0.685, 0.686, 0.667, 0.757, 0.615, 0.581, 0.745, 0.764, 0.483, 0.5, 0.696, 0.572, 0.893, 0.771, 0.77, 
            0.657, 0.77, 0.726, 0.633, 0.612, 0.739, 0.675, 1.028, 0.685, 0.67, 0.623, 0.454, 0.577, 0.454, 0.818, 0.637, 
            0.546, 0.599, 0.632, 0.527, 0.629, 0.594, 0.382, 0.629, 0.64, 0.302, 0.363, 0.603, 0.302, 0.954, 0.64, 0.617, 
            0.629, 0.629, 0.434, 0.515, 0.416, 0.64, 0.579, 0.89, 0.604, 0.576, 0.526, 0.623, 0.637, 0.623, 0.818))
        return((0.312, 0.332, 0.401, 0.728, 0.546, 0.977, 0.674, 0.211, 0.383, 0.383, 0.546, 0.728, 0.303, 0.363, 0.303, 0.382, 
            0.546, 0.546, 0.546, 0.546, 0.546, 0.546, 0.546, 0.546, 0.546, 0.546, 0.354, 0.354, 0.728, 0.728, 0.728, 0.474, 
            0.909, 0.6, 0.589, 0.601, 0.678, 0.561, 0.521, 0.667, 0.675, 0.373, 0.417, 0.588, 0.498, 0.771, 0.667, 0.708, 
            0.551, 0.708, 0.621, 0.557, 0.584, 0.656, 0.597, 0.902, 0.581, 0.576, 0.559, 0.383, 0.382, 0.383, 0.728, 0.546, 
            0.546, 0.525, 0.553, 0.461, 0.553, 0.526, 0.318, 0.553, 0.558, 0.229, 0.282, 0.498, 0.229, 0.84, 0.558, 0.543, 
            0.553, 0.553, 0.36, 0.446, 0.334, 0.558, 0.498, 0.742, 0.495, 0.498, 0.444, 0.48, 0.382, 0.48, 0.728))
    }
    if (font == "trebuchet ms") {
        if (bold) return((0.301, 0.367, 0.367, 0.586, 0.586, 0.684, 0.706, 0.229, 0.367, 0.367, 0.432, 0.586, 0.367, 0.367, 0.367, 0.39, 
            0.586, 0.586, 0.586, 0.586, 0.586, 0.586, 0.586, 0.586, 0.586, 0.586, 0.367, 0.367, 0.586, 0.586, 0.586, 0.438, 
            0.771, 0.633, 0.595, 0.612, 0.643, 0.569, 0.583, 0.671, 0.684, 0.278, 0.533, 0.617, 0.553, 0.745, 0.667, 0.703, 
            0.587, 0.709, 0.611, 0.511, 0.612, 0.678, 0.622, 0.884, 0.601, 0.613, 0.56, 0.402, 0.355, 0.402, 0.586, 0.586, 
            0.586, 0.533, 0.582, 0.512, 0.581, 0.575, 0.37, 0.502, 0.593, 0.298, 0.367, 0.548, 0.295, 0.859, 0.59, 0.566, 
            0.583, 0.584, 0.427, 0.431, 0.396, 0.591, 0.527, 0.784, 0.552, 0.534, 0.528, 0.434, 0.586, 0.434, 0.586))
        return((0.301, 0.367, 0.325, 0.524, 0.524, 0.6, 0.706, 0.16, 0.367, 0.367, 0.367, 0.524, 0.367, 0.367, 0.367, 0.524, 
            0.524, 0.524, 0.524, 0.524, 0.524, 0.524, 0.524, 0.524, 0.524, 0.524, 0.367, 0.367, 0.524, 0.524, 0.524, 0.367, 
            0.771, 0.59, 0.566, 0.598, 0.613, 0.536, 0.525, 0.676, 0.654, 0.278, 0.477, 0.576, 0.506, 0.709, 0.638, 0.674, 
            0.558, 0.676, 0.582, 0.481, 0.581, 0.648, 0.587, 0.852, 0.557, 0.57, 0.55, 0.367, 0.355, 0.367, 0.524, 0.524, 
            0.524, 0.525, 0.557, 0.495, 0.557, 0.545, 0.37, 0.502, 0.546, 0.285, 0.367, 0.504, 0.295, 0.83, 0.546, 0.537, 
            0.557, 0.557, 0.389, 0.405, 0.396, 0.546, 0.49, 0.744, 0.501, 0.493, 0.475, 0.367, 0.524, 0.367, 0.524))
    }
    if (font == "avenir") {
        if (bold) return((0.295, 0.295, 0.55, 0.589, 0.589, 0.883, 0.746, 0.276, 0.276, 0.276, 0.471, 0.706, 0.295, 0.353, 0.295, 0.392, 
            0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.589, 0.295, 0.295, 0.706, 0.706, 0.706, 0.511, 
            0.848, 0.727, 0.668, 0.746, 0.785, 0.629, 0.589, 0.825, 0.765, 0.28, 0.511, 0.668, 0.53, 0.943, 0.825, 0.884, 
            0.608, 0.884, 0.629, 0.589, 0.608, 0.727, 0.648, 1.001, 0.668, 0.608, 0.589, 0.276, 0.392, 0.276, 0.706, 0.53, 
            0.254, 0.55, 0.648, 0.511, 0.648, 0.589, 0.314, 0.648, 0.589, 0.254, 0.254, 0.511, 0.254, 0.903, 0.589, 0.629, 
            0.648, 0.648, 0.352, 0.452, 0.352, 0.589, 0.511, 0.765, 0.511, 0.511, 0.452, 0.276, 0.235, 0.276, 0.706))
        return((0.278, 0.278, 0.519, 0.556, 0.556, 0.833, 0.704, 0.26, 0.26, 0.26, 0.444, 0.666, 0.278, 0.333, 0.278, 0.37, 
            0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.278, 0.278, 0.666, 0.666, 0.666, 0.482, 
            0.8, 0.686, 0.63, 0.704, 0.741, 0.593, 0.556, 0.778, 0.722, 0.264, 0.482, 0.63, 0.5, 0.89, 0.778, 0.834, 
            0.574, 0.834, 0.593, 0.556, 0.574, 0.686, 0.611, 0.944, 0.63, 0.574, 0.556, 0.26, 0.37, 0.26, 0.666, 0.5, 
            0.24, 0.519, 0.611, 0.482, 0.611, 0.556, 0.296, 0.611, 0.556, 0.24, 0.24, 0.482, 0.24, 0.852, 0.556, 0.593, 
            0.611, 0.611, 0.332, 0.426, 0.332, 0.556, 0.482, 0.722, 0.482, 0.482, 0.426, 0.26, 0.222, 0.26, 0.666))
    }
    if (font == "gill sans") {
        if (bold) return((0.295, 0.287, 0.375, 0.619, 0.575, 0.717, 0.663, 0.199, 0.342, 0.342, 0.442, 0.619, 0.232, 0.342, 0.232, 0.298, 
            0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.232, 0.243, 0.619, 0.619, 0.619, 0.353, 
            1.071, 0.707, 0.597, 0.75, 0.795, 0.53, 0.497, 0.784, 0.773, 0.265, 0.265, 0.695, 0.519, 0.828, 0.828, 0.872, 
            0.541, 0.872, 0.64, 0.485, 0.64, 0.75, 0.64, 1.105, 0.75, 0.64, 0.685, 0.353, 0.298, 0.353, 0.497, 0.585, 
            0.353, 0.453, 0.53, 0.464, 0.541, 0.508, 0.265, 0.453, 0.53, 0.232, 0.232, 0.508, 0.232, 0.817, 0.53, 0.585, 
            0.53, 0.53, 0.42, 0.408, 0.353, 0.53, 0.464, 0.762, 0.53, 0.464, 0.442, 0.353, 0.276, 0.353, 0.618))
        return((0.278, 0.271, 0.354, 0.584, 0.542, 0.676, 0.625, 0.188, 0.323, 0.323, 0.417, 0.584, 0.219, 0.323, 0.219, 0.281, 
            0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.219, 0.229, 0.584, 0.584, 0.584, 0.333, 
            1.01, 0.667, 0.563, 0.708, 0.75, 0.5, 0.469, 0.74, 0.729, 0.25, 0.25, 0.656, 0.49, 0.781, 0.781, 0.823, 
            0.51, 0.823, 0.604, 0.458, 0.604, 0.708, 0.604, 1.042, 0.708, 0.604, 0.646, 0.333, 0.281, 0.333, 0.469, 0.552, 
            0.333, 0.427, 0.5, 0.438, 0.51, 0.479, 0.25, 0.427, 0.5, 0.219, 0.219, 0.479, 0.219, 0.771, 0.5, 0.552, 
            0.5, 0.5, 0.396, 0.385, 0.333, 0.5, 0.438, 0.719, 0.5, 0.438, 0.417, 0.333, 0.26, 0.333, 0.583))
    }
    if (font == "times new roman") {
        if (bold) return((0.25, 0.333, 0.555, 0.5, 0.5, 1, 0.833, 0.278, 0.333, 0.333, 0.5, 0.57, 0.25, 0.333, 0.25, 0.278, 
            0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.333, 0.333, 0.57, 0.57, 0.57, 0.5, 
            0.93, 0.722, 0.667, 0.722, 0.722, 0.667, 0.611, 0.778, 0.778, 0.389, 0.5, 0.778, 0.667, 0.944, 0.722, 0.778, 
            0.611, 0.778, 0.722, 0.556, 0.667, 0.722, 0.722, 1, 0.722, 0.722, 0.667, 0.333, 0.278, 0.333, 0.581, 0.5, 
            0.333, 0.5, 0.556, 0.444, 0.556, 0.444, 0.333, 0.5, 0.556, 0.278, 0.333, 0.556, 0.278, 0.833, 0.556, 0.5, 
            0.556, 0.556, 0.444, 0.389, 0.333, 0.556, 0.5, 0.722, 0.5, 0.5, 0.444, 0.394, 0.22, 0.394, 0.52))
        return((0.25, 0.333, 0.408, 0.5, 0.5, 0.833, 0.778, 0.18, 0.333, 0.333, 0.5, 0.564, 0.25, 0.333, 0.25, 0.278, 
            0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.278, 0.278, 0.564, 0.564, 0.564, 0.444, 
            0.921, 0.722, 0.667, 0.667, 0.722, 0.611, 0.556, 0.722, 0.722, 0.333, 0.389, 0.722, 0.611, 0.889, 0.722, 0.722, 
            0.556, 0.722, 0.667, 0.556, 0.611, 0.722, 0.722, 0.944, 0.722, 0.722, 0.611, 0.333, 0.278, 0.333, 0.469, 0.5, 
            0.333, 0.444, 0.5, 0.444, 0.5, 0.444, 0.333, 0.5, 0.5, 0.278, 0.278, 0.5, 0.278, 0.778, 0.5, 0.5, 
            0.5, 0.5, 0.333, 0.389, 0.278, 0.5, 0.5, 0.722, 0.5, 0.5, 0.444, 0.48, 0.2, 0.48, 0.541))
    }
    if (font == "times") {
        if (bold) return((0.265, 0.353, 0.432, 0.53, 0.53, 0.883, 0.825, 0.191, 0.353, 0.353, 0.53, 0.598, 0.265, 0.353, 0.265, 0.295, 
            0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.295, 0.295, 0.598, 0.598, 0.598, 0.471, 
            0.976, 0.765, 0.707, 0.707, 0.765, 0.648, 0.589, 0.765, 0.765, 0.353, 0.412, 0.765, 0.648, 0.942, 0.765, 0.765, 
            0.589, 0.765, 0.707, 0.589, 0.648, 0.765, 0.765, 1.001, 0.765, 0.765, 0.648, 0.353, 0.295, 0.353, 0.497, 0.53, 
            0.353, 0.471, 0.53, 0.471, 0.53, 0.471, 0.353, 0.53, 0.53, 0.295, 0.295, 0.53, 0.295, 0.825, 0.53, 0.53, 
            0.53, 0.53, 0.353, 0.412, 0.295, 0.53, 0.53, 0.765, 0.53, 0.53, 0.471, 0.509, 0.212, 0.509, 0.573))
        return((0.25, 0.333, 0.408, 0.5, 0.5, 0.833, 0.778, 0.18, 0.333, 0.333, 0.5, 0.564, 0.25, 0.333, 0.25, 0.278, 
            0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.278, 0.278, 0.564, 0.564, 0.564, 0.444, 
            0.921, 0.722, 0.667, 0.667, 0.722, 0.611, 0.556, 0.722, 0.722, 0.333, 0.389, 0.722, 0.611, 0.889, 0.722, 0.722, 
            0.556, 0.722, 0.667, 0.556, 0.611, 0.722, 0.722, 0.944, 0.722, 0.722, 0.611, 0.333, 0.278, 0.333, 0.469, 0.5, 
            0.333, 0.444, 0.5, 0.444, 0.5, 0.444, 0.333, 0.5, 0.5, 0.278, 0.278, 0.5, 0.278, 0.778, 0.5, 0.5, 
            0.5, 0.5, 0.333, 0.389, 0.278, 0.5, 0.5, 0.722, 0.5, 0.5, 0.444, 0.48, 0.2, 0.48, 0.541))
    }
    if (font == "georgia") {
        if (bold) return((0.254, 0.376, 0.51, 0.703, 0.641, 0.879, 0.799, 0.269, 0.447, 0.447, 0.482, 0.703, 0.328, 0.379, 0.328, 0.472, 
            0.701, 0.49, 0.626, 0.625, 0.649, 0.599, 0.648, 0.554, 0.676, 0.648, 0.367, 0.367, 0.703, 0.703, 0.703, 0.548, 
            0.967, 0.758, 0.757, 0.715, 0.834, 0.721, 0.671, 0.807, 0.913, 0.446, 0.595, 0.817, 0.686, 1.023, 0.839, 0.82, 
            0.701, 0.82, 0.797, 0.649, 0.684, 0.833, 0.762, 1.126, 0.809, 0.732, 0.689, 0.447, 0.472, 0.447, 0.703, 0.703, 
            0.5, 0.596, 0.646, 0.531, 0.663, 0.572, 0.393, 0.577, 0.68, 0.354, 0.346, 0.632, 0.344, 1.016, 0.69, 0.636, 
            0.658, 0.648, 0.52, 0.513, 0.397, 0.677, 0.567, 0.863, 0.588, 0.562, 0.525, 0.5, 0.388, 0.5, 0.703))
        return((0.241, 0.331, 0.412, 0.643, 0.61, 0.817, 0.71, 0.215, 0.375, 0.375, 0.472, 0.643, 0.27, 0.374, 0.27, 0.469, 
            0.614, 0.43, 0.559, 0.552, 0.565, 0.528, 0.566, 0.502, 0.596, 0.566, 0.312, 0.312, 0.643, 0.643, 0.643, 0.479, 
            0.929, 0.671, 0.654, 0.642, 0.749, 0.653, 0.599, 0.725, 0.815, 0.39, 0.518, 0.694, 0.604, 0.927, 0.767, 0.744, 
            0.61, 0.744, 0.702, 0.561, 0.619, 0.756, 0.667, 0.976, 0.71, 0.615, 0.602, 0.375, 0.469, 0.375, 0.643, 0.643, 
            0.5, 0.504, 0.56, 0.454, 0.574, 0.483, 0.325, 0.509, 0.582, 0.293, 0.292, 0.536, 0.286, 0.881, 0.591, 0.539, 
            0.571, 0.56, 0.41, 0.432, 0.345, 0.575, 0.497, 0.737, 0.505, 0.492, 0.444, 0.43, 0.375, 0.43, 0.643))
    }
    if (font == "palatino") {
        if (bold) return((0.265, 0.295, 0.393, 0.642, 0.53, 0.89, 0.825, 0.22, 0.353, 0.353, 0.412, 0.642, 0.265, 0.353, 0.265, 0.642, 
            0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.53, 0.265, 0.265, 0.642, 0.642, 0.642, 0.471, 
            0.792, 0.825, 0.648, 0.752, 0.82, 0.648, 0.589, 0.809, 0.882, 0.357, 0.353, 0.77, 0.648, 1.003, 0.881, 0.833, 
            0.64, 0.833, 0.708, 0.557, 0.65, 0.825, 0.765, 1.06, 0.707, 0.707, 0.707, 0.353, 0.642, 0.353, 0.642, 0.53, 
            0.353, 0.53, 0.586, 0.471, 0.648, 0.508, 0.353, 0.589, 0.617, 0.308, 0.248, 0.589, 0.308, 0.936, 0.617, 0.579, 
            0.637, 0.594, 0.419, 0.449, 0.346, 0.639, 0.599, 0.884, 0.547, 0.589, 0.53, 0.353, 0.642, 0.353, 0.642))
        return((0.25, 0.278, 0.371, 0.606, 0.5, 0.84, 0.778, 0.208, 0.333, 0.333, 0.389, 0.606, 0.25, 0.333, 0.25, 0.606, 
            0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.25, 0.25, 0.606, 0.606, 0.606, 0.444, 
            0.747, 0.778, 0.611, 0.709, 0.774, 0.611, 0.556, 0.763, 0.832, 0.337, 0.333, 0.726, 0.611, 0.946, 0.831, 0.786, 
            0.604, 0.786, 0.668, 0.525, 0.613, 0.778, 0.722, 1, 0.667, 0.667, 0.667, 0.333, 0.606, 0.333, 0.606, 0.5, 
            0.333, 0.5, 0.553, 0.444, 0.611, 0.479, 0.333, 0.556, 0.582, 0.291, 0.234, 0.556, 0.291, 0.883, 0.582, 0.546, 
            0.601, 0.56, 0.395, 0.424, 0.326, 0.603, 0.565, 0.834, 0.516, 0.556, 0.5, 0.333, 0.606, 0.333, 0.606))
    }
    if (font == "courier new") {
        if (bold) return((0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 
            0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 
            0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 
            0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 
            0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 
            0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636, 0.636))
        return((0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 
            0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 
            0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 
            0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 
            0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 
            0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6))
    }
    if (font == "menlo") {
        if (bold) return((0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 
            0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 
            0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 
            0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 
            0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 
            0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638, 0.638))
        return((0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 
            0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 
            0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 
            0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 
            0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 
            0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602, 0.602))
    }
    if (bold) return((0.278, 0.333, 0.474, 0.556, 0.556, 0.889, 0.722, 0.238, 0.333, 0.333, 0.389, 0.584, 0.278, 0.333, 0.278, 0.278, 
            0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.333, 0.333, 0.584, 0.584, 0.584, 0.611, 
            0.975, 0.722, 0.722, 0.722, 0.722, 0.667, 0.611, 0.778, 0.722, 0.278, 0.556, 0.722, 0.611, 0.833, 0.722, 0.778, 
            0.667, 0.778, 0.722, 0.667, 0.611, 0.722, 0.667, 0.944, 0.667, 0.667, 0.611, 0.333, 0.278, 0.333, 0.584, 0.556, 
            0.333, 0.556, 0.611, 0.556, 0.611, 0.556, 0.333, 0.611, 0.611, 0.278, 0.278, 0.556, 0.278, 0.889, 0.611, 0.611, 
            0.611, 0.611, 0.389, 0.556, 0.333, 0.611, 0.556, 0.778, 0.556, 0.556, 0.5, 0.389, 0.28, 0.389, 0.584))
    return((0.278, 0.278, 0.355, 0.556, 0.556, 0.889, 0.667, 0.191, 0.333, 0.333, 0.389, 0.584, 0.278, 0.333, 0.278, 0.278, 
            0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.278, 0.278, 0.584, 0.584, 0.584, 0.556, 
            1.015, 0.667, 0.667, 0.722, 0.722, 0.667, 0.611, 0.778, 0.722, 0.278, 0.5, 0.667, 0.556, 0.833, 0.722, 0.778, 
            0.667, 0.778, 0.722, 0.667, 0.611, 0.722, 0.667, 0.944, 0.667, 0.667, 0.611, 0.278, 0.278, 0.278, 0.469, 0.556, 
            0.333, 0.556, 0.556, 0.5, 0.556, 0.556, 0.278, 0.556, 0.556, 0.222, 0.222, 0.5, 0.222, 0.833, 0.556, 0.556, 
            0.556, 0.556, 0.333, 0.5, 0.278, 0.556, 0.5, 0.722, 0.5, 0.5, 0.5, 0.334, 0.26, 0.334, 0.584))
}
real scalar _gpl_fontknown(string scalar font)
{
    return(font == "open sans" | font == "helvetica" | font == "helvetica neue" | font == "arial" | font == "arial narrow" | font == "verdana" | font == "tahoma" | font == "trebuchet ms" | font == "avenir" | font == "gill sans" | font == "times new roman" | font == "times" | font == "georgia" | font == "palatino" | font == "courier new" | font == "menlo")
}
// width of a string in ems (ASCII 32-126 from the table; other characters use an average)
real scalar _gpl_textw(string scalar font, string scalar s, real scalar bold)
{
    real rowvector W
    real rowvector c
    real scalar i
    real scalar w
    real scalar p
    real scalar q

    s = subinstr(subinstr(s, "{c 36}", char(36)), "{c 96}", char(96))
    // remove each {bf: tag and the } that closes it; other braces are text and are counted
    p = strpos(s, "{bf:")
    while (p > 0) {
        bold = 1
        q = strpos(substr(s, p + 4, .), "}")
        if (q == 0) s = substr(s, 1, p - 1) + substr(s, p + 4, .)
        else s = substr(s, 1, p - 1) + substr(s, p + 4, q - 1) + substr(s, p + 4 + q, .)
        p = strpos(s, "{bf:")
    }
    W = _gpl_fontw(font, bold)
    c = ascii(s)
    w = 0
    // UTF-8 lead bytes: 2-byte sequences (Latin, Greek, Cyrillic) average 0.57 em; 3-byte
    // sequences from E3 to ED and EF (CJK, kana, Hangul, full-width forms) and 4-byte sequences
    // are about 1 em; other 3-byte sequences (punctuation, symbols) average 0.6 em
    for (i=1; i<=cols(c); i++) {
        if (c[i] >= 32 & c[i] <= 126) w = w + W[c[i]-31]
        else if (c[i] >= 240 & c[i] <= 247) w = w + 1
        else if ((c[i] >= 227 & c[i] <= 237) | c[i] == 239) w = w + 1
        else if (c[i] >= 224 & c[i] <= 239) w = w + 0.6
        else if (c[i] >= 192 & c[i] <= 223) w = w + 0.57
    }
    return(w)
}
// greedy word wrap by rendered width; wrap = max ems per line (0 = no wrap)
void _gpl_wrap(string scalar labmac, string scalar nlmac, string scalar wmac, real scalar wrap, real scalar bold)
{
    string scalar s
    string scalar cur
    string rowvector tok
    string colvector out
    real scalar i
    real scalar w
    real scalar mw
    string scalar font

    font = st_global("GPL_FONT")
    s = st_local(labmac)
    out = J(0, 1, "")
    if (wrap <= 0) out = s
    else {
        tok = tokens(s)
        cur = ""
        for (i=1; i<=cols(tok); i++) {
            if (cur == "") cur = tok[i]
            else if (_gpl_textw(font, cur + " " + tok[i], bold) > wrap) {
                out = out \ cur
                cur = tok[i]
            }
            else cur = cur + " " + tok[i]
        }
        if (cur != "") out = out \ cur
    }
    mw = 0
    for (i=1; i<=rows(out); i++) {
        w = _gpl_textw(font, out[i], bold)
        if (w > mw) mw = w
        st_local(labmac + "_" + strofreal(i), out[i])
    }
    st_local(nlmac, strofreal(rows(out)))
    st_local(wmac, strofreal(mw))
}

// ---------------------------------------------------------------- 1-D repel
// column 2 = anchors, column 3 = result, column 5 = number of text lines.
// sep = wanted distance between the centres of two one-line labels (gap() times the text size);
// em = the text size and lg = the gap between the lines of one label, both in device units.
// Returns in the caller's locals novl (pairs whose text overlaps) and nclose (pairs closer than sep).
void _gpl_repel(string scalar nm, real scalar sep, real scalar lo, real scalar hi,
                real scalar em, real scalar lg)
{
    real matrix Y
    real colvector g
    real colvector o
    real colvector nl
    real colvector h
    real scalar n
    real scalar k
    real scalar i
    real scalar d
    real scalar moved
    real scalar need
    real scalar t

    Y = st_matrix(nm)
    n = rows(Y)
    o = order(Y[,2], 1)
    g = Y[o,2]
    nl = Y[o,5]
    if (lo > hi) {
        t = lo
        lo = hi
        hi = t
    }
    // the height the labels need: half a label at each edge plus every wanted distance
    need = sep*(nl[1] + nl[n])/2
    for (i=1; i<n; i++) need = need + sep*(nl[i]+nl[i+1])/2
    if (need > hi - lo) {
        // not enough height: the first and last labels keep their full room at the edges, and
        // every distance between neighbours shrinks by the same factor, in the order of the line ends
        t = need - sep*(nl[1] + nl[n])/2
        if (t > 0) t = max((0, (hi - lo - sep*(nl[1] + nl[n])/2)/t))
        g[1] = lo + sep*nl[1]/2
        for (i=2; i<=n; i++) g[i] = g[i-1] + t*sep*(nl[i-1]+nl[i])/2
    }
    else {
        for (k=1; k<=1000; k++) {
            moved = 0
            for (i=1; i<n; i++) {
                d = sep*(nl[i]+nl[i+1])/2 - (g[i+1]-g[i])
                if (d > 0.000001) {
                    g[i] = g[i] - d/2
                    g[i+1] = g[i+1] + d/2
                    moved = 1
                }
            }
            // keep the outer edges of the first and last labels inside the plot height
            if (g[1] - sep*nl[1]/2 < lo) g[1] = lo + sep*nl[1]/2
            if (g[n] + sep*nl[n]/2 > hi) g[n] = hi - sep*nl[n]/2
            if (moved==0) break
        }
    }
    // The text of a label spans from the cap height of its first line to the descenders of its
    // last line: about 0.95 of the text size for one line. A pair overlaps only when these spans meet.
    // Only pairs pushed closer than sep count: a gap() below about 1 asks for touching labels.
    h = (nl :- 1)*(em + lg) :+ 0.95*em
    k = 0
    t = 0
    for (i=1; i<n; i++) {
        if (sep*(nl[i]+nl[i+1])/2 - (g[i+1]-g[i]) > 0.01*sep) {
            t++
            if ((h[i]+h[i+1])/2 - (g[i+1]-g[i]) > 0.01*em) k++
        }
    }
    st_local("novl", strofreal(k))
    st_local("nclose", strofreal(t))
    Y[o,3] = g
    st_matrix(nm, Y)
}

// ---------------------------------------------------------------- obstacles (externals)
pointer(real matrix) scalar _gpl_ext(string scalar nm)
{
    pointer(real matrix) scalar p
    p = findexternal(nm)
    if (p == NULL) {
        p = crexternal(nm)
        *p = J(0, 4, .)
    }
    return(p)
}
void _gpl_obs_reset()
{
    pointer(real matrix) scalar p
    p = _gpl_ext("_gpl_OBS")
    *p = J(0, 4, .)
}
void _gpl_obs_add(real matrix B)
{
    pointer(real matrix) scalar p
    p = _gpl_ext("_gpl_OBS")
    *p = *p \ B
}
void _gpl_obs_points(string scalar xv, string scalar yv, real scalar xlog, real scalar ylog,
                     real scalar xa, real scalar xb, real scalar ya, real scalar yb, real scalar rad)
{
    real matrix D
    real colvector gx
    real colvector gy
    D = st_data(., (xv, yv))
    D = select(D, rowmissing(D) :== 0)
    if (rows(D) == 0) return
    gx = xa :+ xb*(xlog ? ln(D[,1]) : D[,1])
    gy = ya :+ yb*(ylog ? ln(D[,2]) : D[,2])
    _gpl_obs_add((gx :- rad, gy :- rad, gx :+ rad, gy :+ rad))
}
void _gpl_obs_path(string scalar xv, string scalar yv, real scalar xlog, real scalar ylog,
                   real scalar xa, real scalar xb, real scalar ya, real scalar yb, real scalar step)
{
    real matrix D
    real colvector gx
    real colvector gy
    real colvector len
    real colvector m
    real matrix R
    real scalar n
    real scalar h

    D = st_data(., (xv, yv))
    D = select(D, rowmissing(D) :== 0)
    n = rows(D)
    if (n < 2) return
    gx = xa :+ xb*(xlog ? ln(D[,1]) : D[,1])
    gy = ya :+ yb*(ylog ? ln(D[,2]) : D[,2])
    h = step/2
    // one box, step wide, every step along each segment (at most 400 per segment)
    len = sqrt((gx[|2 \ n|] - gx[|1 \ n-1|]):^2 + (gy[|2 \ n|] - gy[|1 \ n-1|]):^2)
    m = rowmin((rowmax((J(n-1, 1, 1), ceil(len/step))), J(n-1, 1, 400)))
    R = _gpl_pieces((gx, gy), m, 0, 20000)
    _gpl_obs_add((R[,1] :- h, R[,2] :- h, R[,3] :+ h, R[,4] :+ h))
}
// The pieces of a polyline whose n vertices have the values A (one column per coordinate), with m[i]
// pieces on the interval from vertex i to vertex i+1. ends 0: piece j is the point at u = j/m[i];
// ends 1: piece j is the span from u = j/m[i] to u = (j+1)/m[i]. Returns one row per piece: the
// minimum of each column, then the maximum. When there are more than cap pieces, neighbouring pieces
// are merged in equal groups (the last group may be smaller) and each row covers its whole group, so
// the rows still cover the whole polyline.
real matrix _gpl_pieces(real matrix A, real colvector m, real scalar ends, real scalar cap)
{
    real colvector cm
    real matrix R
    real matrix Q
    real rowvector a
    real rowvector b
    real scalar T
    real scalar G
    real scalar K
    real scalar k
    real scalar t0
    real scalar t1
    real scalar i0
    real scalar i1
    real scalar j0
    real scalar j1

    T = sum(m)
    G = max((1, ceil(T/cap)))
    K = ceil(T/G)
    cm = runningsum(m)
    R = J(K, 2*cols(A), .)
    i0 = 1
    for (k=1; k<=K; k++) {
        t0 = (k-1)*G + 1
        t1 = min((k*G, T))
        while (cm[i0] < t0) i0++
        i1 = i0
        while (cm[i1] < t1) i1++
        j0 = t0 - (cm[i0] - m[i0]) - 1
        j1 = t1 - (cm[i1] - m[i1]) - 1
        a = A[i0,] + (j0/m[i0])*(A[i0+1,] - A[i0,])
        b = A[i1,] + ((j1+ends)/m[i1])*(A[i1+1,] - A[i1,])
        Q = a \ b
        if (i1 > i0) Q = Q \ A[|i0+1, 1 \ i1, .|]
        R[k,] = (colmin(Q), colmax(Q))
    }
    return(R)
}
// bars, shaded bands and range spikes as boxes. pos = position variable, val = value variable,
// lov = second value variable ("" uses the constant base). horiz: values run along x.
// kind 1: one box per bar, bw wide in data units; kind 2: strips between neighbouring positions,
// at most `step' device units wide; kind 3: one spike per position, `step' device units wide.
void _gpl_obs_range(string scalar posv, string scalar valv, string scalar lov, real scalar base,
                    real scalar horiz, real scalar kind, real scalar bw,
                    real scalar xlog, real scalar ylog, real scalar xa, real scalar xb,
                    real scalar ya, real scalar yb, real scalar step)
{
    real matrix D
    real colvector p
    real colvector p0
    real colvector p1
    real colvector v1
    real colvector v2
    real colvector o
    real scalar plog
    real scalar vlog
    real scalar pa
    real scalar pb
    real scalar va
    real scalar vb
    real colvector m
    real scalar n
    real matrix S

    if (lov != "") D = st_data(., (posv, valv, lov))
    else D = (st_data(., (posv, valv)), J(st_nobs(), 1, base))
    D = select(D, rowmissing(D) :== 0)
    if (rows(D) == 0) return
    // map positions and values to device units on their own axes
    plog = (horiz ? ylog : xlog)
    vlog = (horiz ? xlog : ylog)
    pa = (horiz ? ya : xa)
    pb = (horiz ? yb : xb)
    va = (horiz ? xa : ya)
    vb = (horiz ? xb : yb)
    v1 = va :+ vb*(vlog ? ln(D[,2]) : D[,2])
    v2 = va :+ vb*(vlog ? ln(D[,3]) : D[,3])
    if (kind == 1 & bw > 0) {
        p0 = pa :+ pb*(plog ? ln(D[,1] :- bw/2) : D[,1] :- bw/2)
        p1 = pa :+ pb*(plog ? ln(D[,1] :+ bw/2) : D[,1] :+ bw/2)
    }
    else {
        p = pa :+ pb*(plog ? ln(D[,1]) : D[,1])
        p0 = p :- step/2
        p1 = p :+ step/2
    }
    if (kind == 2 & rows(D) > 1) {
        p = pa :+ pb*(plog ? ln(D[,1]) : D[,1])
        o = order(p, 1)
        p = p[o]
        v1 = v1[o]
        v2 = v2[o]
        // strips at most step wide between neighbouring positions (at most 200 per interval)
        n = rows(p)
        m = rowmin((rowmax((J(n-1, 1, 1), ceil(abs(p[|2 \ n|] - p[|1 \ n-1|])/step))), J(n-1, 1, 200)))
        S = _gpl_pieces((p, v1, v2), m, 1, 20000)
        S = (S[,1], rowmin((S[,2], S[,3])), S[,4], rowmax((S[,5], S[,6])))
    }
    else S = (p0, rowmin((v1, v2)), p1, rowmax((v1, v2)))
    S = select(S, rowmissing(S) :== 0)
    if (rows(S) == 0) return
    // boxes are (x0, y0, x1, y1) in device units, smaller corner first
    if (horiz) S = (S[,2], S[,1], S[,4], S[,3])
    S = (rowmin((S[,1], S[,3])), rowmin((S[,2], S[,4])), rowmax((S[,1], S[,3])), rowmax((S[,2], S[,4])))
    _gpl_obs_add(S)
}
// a thin box around a line segment (x0, y0, x1, y1), w device units wide
real rowvector _gpl_thin(real rowvector s, real scalar w)
{
    return((min((s[1], s[3])) - w/2, min((s[2], s[4])) - w/2, max((s[1], s[3])) + w/2, max((s[2], s[4])) + w/2))
}
// read an endlabel record into the caller's locals txt, mk, side, m, leg, pm and lens
void _gpl_recparse(string scalar s)
{
    string rowvector f
    string rowvector nm
    real scalar p
    real scalar i

    f = J(1, 0, "")
    p = strpos(s, "|")
    while (p > 0) {
        f = f, substr(s, 1, p-1)
        s = substr(s, p+1, .)
        p = strpos(s, "|")
    }
    f = f, s
    nm = ("", "txt", "mk", "side", "m", "leg", "pm", "lens")
    for (i=2; i<=8; i++) st_local(nm[i], (i <= cols(f) ? f[i] : ""))
}
// End labels added by gpolish 0.6.1 or earlier, read from a graph's edit log L (see _gpl_legundo).
// Sets the caller's locals n (runs whose margin was not given back), txt and mk (their text boxes and
// markers), marg (the side and size of each run's margin) and leg (1 if one of them switched the legend off).
void _gpl_legscan(string colvector L)
{
    real scalar e
    real scalar nb
    real scalar open
    real scalar nt
    real scalar nm
    real scalar curk
    real scalar prevlab
    real scalar expleg
    real scalar b
    real scalar k
    real scalar n
    real scalar lg
    string scalar s
    string scalar cury
    string scalar lasty
    string scalar pend
    string scalar ot
    string scalar om
    string scalar oc
    string colvector side
    string colvector mv
    string colvector txt
    string colvector mk
    real colvector leg
    real colvector nlab
    real colvector done

    nb = 0
    side = J(0, 1, "")
    mv = J(0, 1, "")
    txt = J(0, 1, "")
    mk = J(0, 1, "")
    leg = J(0, 1, .)
    nlab = J(0, 1, .)
    done = J(0, 1, .)
    open = 0
    nt = 0
    nm = 0
    curk = 0
    cury = ""
    lasty = ""
    prevlab = 0
    expleg = 0
    pend = ""
    // A graph that has held an endlabel record was handled by this release, whose first endlabel or
    // clear on the graph already undid any earlier runs: then there is nothing to scan for.
    for (e=1; e<=rows(L); e++) {
        if (regexm(L[e], "^\.plotregion1\.added_text\[[0-9]+\]\.text\.Arrpush ") & strpos(L[e], "gpolish-endlabel")) {
            st_local("n", "0")
            st_local("txt", "")
            st_local("mk", "")
            st_local("marg", "")
            st_local("leg", "0")
            return
        }
    }
    for (e=1; e<=rows(L); e++) {
        s = L[e]
        if (regexm(s, "^\.style\.editstyle margin\(([rl])([+-])([0-9.eE+-]+)\) editcopy$")) {
            if (regexs(2) == "+") {
                // a run starts with the margin it makes
                nb++
                side = side \ regexs(1)
                mv = mv \ regexs(3)
                txt = txt \ ""
                mk = mk \ ""
                leg = leg \ 0
                nlab = nlab \ 0
                done = done \ 0
                open = nb
                expleg = 1
                prevlab = 0
                pend = ""
            }
            else {
                // a margin given back ends the latest run with the same side and size
                for (b=nb; b>=1; b--) {
                    if (!done[b] & side[b]==regexs(1) & mv[b]==regexs(3)) {
                        done[b] = 1
                        break
                    }
                }
                open = 0
            }
            continue
        }
        if (s == ".legend.draw_view.setstyle, style(no)") {
            if (open & expleg) leg[open] = 1
            expleg = 0
            continue
        }
        expleg = 0
        if (regexm(s, "^\.plotregion1\.AddTextBox added_text editor ([^ ]+) ")) {
            nt++
            curk = nt
            cury = regexs(1)
            continue
        }
        if (regexm(s, "^\.plotregion1\.added_text\[([0-9]+)\]\.style\.editstyle ")) {
            // the first style edit of a new box tells a label (line gap 1pt) from a value (same height)
            k = strtoreal(regexs(1))
            if (k != curk) continue
            curk = 0
            if (!open) continue
            if (strpos(s, "linegap(1pt)")) {
                txt[open] = txt[open] + " " + strofreal(k)
                mk[open] = mk[open] + pend
                pend = ""
                nlab[open] = nlab[open] + 1
                lasty = cury
                prevlab = 1
            }
            else if (prevlab & cury == lasty) {
                txt[open] = txt[open] + " " + strofreal(k)
                prevlab = 0
            }
            else open = 0
            continue
        }
        if (regexm(s, "^\.plotregion1\.AddMarker added_markers ")) {
            nm++
            if (open) pend = pend + " " + strofreal(nm)
            continue
        }
        if (s == ".plotregion1.added_text = {}") {
            nt = 0
            curk = 0
            if (nb) txt = J(nb, 1, "")
            open = 0
            continue
        }
        if (s == ".plotregion1.added_markers = {}") {
            nm = 0
            if (nb) mk = J(nb, 1, "")
            pend = ""
            open = 0
            continue
        }
        if (regexm(s, "^\.plotregion1\.AddLine ")) open = 0
    }
    n = 0
    lg = 0
    ot = ""
    om = ""
    oc = ""
    for (b=1; b<=nb; b++) {
        if (done[b] | nlab[b]==0) continue
        n++
        ot = ot + txt[b]
        om = om + mk[b]
        oc = oc + " " + side[b] + " " + mv[b]
        if (leg[b]) lg = 1
    }
    st_local("n", strofreal(n))
    st_local("txt", strtrim(ot))
    st_local("mk", strtrim(om))
    st_local("marg", strtrim(oc))
    st_local("leg", strofreal(lg))
}
void _gpl_obs_text(real scalar gx, real scalar gy, real scalar w, real scalar h, string scalar ba)
{
    real scalar x0
    real scalar y0
    x0 = gx
    y0 = gy - h/2
    if (ba == "west") x0 = gx - w
    else if (ba == "center" | ba == "north" | ba == "south") x0 = gx - w/2
    if (ba == "north") y0 = gy
    else if (ba == "south") y0 = gy - h
    _gpl_obs_add((x0, y0, x0 + w, y0 + h))
}
real scalar _gpl_ov(real rowvector a, real rowvector b)
{
    real scalar ox
    real scalar oy
    ox = min((a[3], b[3])) - max((a[1], b[1]))
    oy = min((a[4], b[4])) - max((a[2], b[2]))
    if (ox <= 0 | oy <= 0) return(0)
    return(ox*oy)
}
// total overlap of box b with all stored obstacles
real scalar _gpl_obscost(real rowvector b, real matrix O)
{
    real colvector ox
    real colvector oy
    if (rows(O) == 0) return(0)
    ox = rowmin((J(rows(O), 1, b[3]), O[,3])) - rowmax((J(rows(O), 1, b[1]), O[,1]))
    oy = rowmin((J(rows(O), 1, b[4]), O[,4])) - rowmax((J(rows(O), 1, b[2]), O[,2]))
    return(sum((ox :* oy) :* ((ox :> 0) :& (oy :> 0))))
}

// drop labels wider than the plot region from the selection; returns how many were dropped
real scalar _gpl_skipwide(string scalar labv, string scalar selv, real scalar fs, real scalar pw)
{
    real colvector sel, idx
    string colvector L
    real scalar i, n

    st_view(sel, ., selv)
    idx = selectindex(sel :!= 0)
    n = 0
    for (i=1; i<=length(idx); i++) {
        L = st_sdata(idx[i], labv)
        if (_gpl_textw(st_global("GPL_FONT"), _gpl_esc(L[1]), 0)*fs > pw) {
            sel[idx[i]] = 0
            n++
        }
    }
    return(n)
}

// ---------------------------------------------------------------- 2-D point labels
// Each label first tries eight spots next to its point. If the best of them still has an overlap
// cost above 2% of its box area and leaders are allowed, it also tries spots on rings farther out,
// joined to the point by a leader line.
// result rows: obs, anchor x, anchor y, halign (-1 left, 0 centre, 1 right), box alignment
// (1 E, 2 W, 3 N, 4 S, 5 centre), overlap flag, leader flag, leader x0 y0 x1 y1 (device units)
void _gpl_place(string scalar gxv, string scalar gyv, string scalar labv, string scalar selv, string scalar out,
                real scalar fs, real scalar rad, real scalar off,
                real scalar x0, real scalar x1, real scalar y0, real scalar y1, real scalar leader)
{
    real colvector gx
    real colvector gy
    real colvector idx
    string colvector lab
    real matrix B
    real matrix C
    real matrix R
    real matrix O
    real matrix L
    real colvector w
    real colvector choice
    real colvector resid
    real colvector far
    real matrix FB
    real scalar m
    real scalar i
    real scalar j
    real scalar k
    real scalar q
    real scalar pass
    real scalar c
    real scalar hardc
    real scalar bc
    real scalar h
    real scalar d
    real scalar px
    real scalar py
    real scalar a
    real scalar rr
    real scalar base
    real rowvector b
    real rowvector best
    real rowvector own
    real rowvector seg
    real rowvector bestseg
    real rowvector P
    string scalar font

    P = _gpl_placeparms()
    font = st_global("GPL_FONT")
    gx = st_data(., gxv)
    gy = st_data(., gyv)
    idx = selectindex(st_data(., selv))
    m = rows(idx)
    lab = st_sdata(idx, labv)
    O = *_gpl_ext("_gpl_OBS")
    w = J(m, 1, 0)
    // boxes carry a small pad so labels that merely touch count as colliding
    for (i=1; i<=m; i++) w[i] = _gpl_textw(font, lab[i], 0)*fs + 2*P[6]*fs/8.6
    h = fs*P[5] + 2*P[6]*fs/8.6
    d = rad + off
    // columns: side, dx, dy of box centre, halign, penalty, dy of anchor, box alignment (1 E, 2 W, 3 N, 4 S)
    C = (  1,  d,  0, -1, 0,    0, 1 \
          -1, -d,  0,  1, 0.15, 0, 2 \
           0,  0,  d + h/2, 0, 0.25,  d, 3 \
           0,  0, -d - h/2, 0, 0.3,  -d, 4 \
           1,  d*0.7,  d*0.7 + h/3, -1, 0.4,  d*0.7 + h/3, 1 \
           1,  d*0.7, -d*0.7 - h/3, -1, 0.4, -d*0.7 - h/3, 1 \
          -1, -d*0.7,  d*0.7 + h/3,  1, 0.5,  d*0.7 + h/3, 2 \
          -1, -d*0.7, -d*0.7 - h/3,  1, 0.5, -d*0.7 - h/3, 2 )
    choice = J(m, 1, 1)
    resid = J(m, 1, 0)
    far = J(m, 1, 0)
    FB = J(m, 4, .)
    L = J(m, 4, .)
    B = J(m, 4, .)
    for (i=1; i<=m; i++) B[i,] = _gpl_box(gx[idx[i]], gy[idx[i]], w[i], h, C[1,])
    for (pass=1; pass<=4; pass++) {
        for (i=1; i<=m; i++) {
            px = gx[idx[i]]
            py = gy[idx[i]]
            // the point's own marker is not an obstacle for its own label
            own = (px-rad*1.01, py-rad*1.01, px+rad*1.01, py+rad*1.01)
            bc = .
            for (k=1; k<=rows(C); k++) {
                b = _gpl_box(px, py, w[i], h, C[k,])
                hardc = _gpl_hard(b, O, own, B, i, pass, w[i], h, x0, x1, y0, y1)
                c = hardc + C[k,5]*h*h
                if (c < bc) {
                    bc = c
                    choice[i] = k
                    best = b
                    resid[i] = hardc
                    far[i] = 0
                }
            }
            // leader fallback: only when the best adjacent spot's overlap cost exceeds 2% of its box area
            if (leader & resid[i] > 0.02*w[i]*h) {
                for (q=1; q<=P[1]; q++) {
                    rr = d + q*P[2]*h
                    for (a=0; a<360; a=a+22.5) {
                        b = (px + cos(a*pi()/180)*(rr + w[i]/2) - w[i]/2, py + sin(a*pi()/180)*(rr + h/2) - h/2,
                             px + cos(a*pi()/180)*(rr + w[i]/2) + w[i]/2, py + sin(a*pi()/180)*(rr + h/2) + h/2)
                        base = (P[3] + P[4]*rr/h)*h*h
                        if (base >= bc) continue
                        hardc = _gpl_hard(b, O, own, B, i, pass, w[i], h, x0, x1, y0, y1)
                        if (hardc + base >= bc) continue
                        seg = _gpl_leader(px, py, b, rad*1.3, 0.12*h)
                        c = hardc + base + _gpl_leadcost(seg, O, own, B, L, i, h)
                        if (c < bc) {
                            bc = c
                            best = b
                            resid[i] = hardc
                            far[i] = 1
                            bestseg = seg
                        }
                    }
                }
            }
            B[i,] = best
            if (far[i]) L[i,] = bestseg
            else L[i,] = J(1, 4, .)
        }
    }
    R = J(m, 11, .)
    for (i=1; i<=m; i++) {
        k = choice[i]
        R[i,1] = idx[i]
        R[i,6] = (resid[i] > 0.35*w[i]*h)
        R[i,7] = far[i]
        if (far[i]) {
            R[i,2] = (B[i,1] + B[i,3])/2
            R[i,3] = (B[i,2] + B[i,4])/2
            R[i,4] = 0
            R[i,5] = 5
            R[i,8..11] = L[i,]
        }
        else {
            R[i,2] = gx[idx[i]] + C[k,2]
            R[i,3] = gy[idx[i]] + C[k,6]
            R[i,4] = C[k,4]
            R[i,5] = C[k,7]
        }
    }
    st_matrix(out, R)
    _gpl_obs_add(B)
}
// placement settings: number of rings, ring step (label heights), base cost of a far spot,
// extra cost per label height of distance, box height (font sizes), box pad (points at 8.6 pt).
// Chosen on held-out tuning scenarios; see benchmark/tune.py.
real rowvector _gpl_placeparms()
{
    return((9, 0.4, 0.05, 0.005, 0.4, 3))
}
// overlap cost of a candidate box: obstacles, other labels, plot edges
real scalar _gpl_hard(real rowvector b, real matrix O, real rowvector own, real matrix B, real scalar i,
                      real scalar pass, real scalar w, real scalar h,
                      real scalar x0, real scalar x1, real scalar y0, real scalar y1)
{
    real scalar hardc
    real colvector ox
    real colvector oy
    real colvector use
    hardc = 2*(_gpl_obscost(b, O) - _gpl_ov(b, own))
    if (hardc < 0) hardc = 0
    ox = rowmin((J(rows(B), 1, b[3]), B[,3])) - rowmax((J(rows(B), 1, b[1]), B[,1]))
    oy = rowmin((J(rows(B), 1, b[4]), B[,4])) - rowmax((J(rows(B), 1, b[2]), B[,2]))
    use = J(rows(B), 1, 1)
    use[i] = 0
    if (pass==1 & i < rows(B)) use[(i+1)::rows(B)] = J(rows(B)-i, 1, 0)
    hardc = hardc + 4*sum((ox :* oy) :* ((ox :> 0) :& (oy :> 0)) :* use)
    if (b[1] < x0) hardc = hardc + 1000*(x0-b[1])*h
    if (b[3] > x1) hardc = hardc + 1000*(b[3]-x1)*h
    if (b[2] < y0) hardc = hardc + 1000*(y0-b[2])*w
    if (b[4] > y1) hardc = hardc + 1000*(b[4]-y1)*w
    return(hardc)
}
// leader from just outside the marker to just short of the nearest point of the box
real rowvector _gpl_leader(real scalar px, real scalar py, real rowvector b, real scalar r0, real scalar gap)
{
    real scalar qx
    real scalar qy
    real scalar dx
    real scalar dy
    real scalar len
    qx = max((b[1], min((px, b[3]))))
    qy = max((b[2], min((py, b[4]))))
    dx = qx - px
    dy = qy - py
    len = sqrt(dx^2 + dy^2)
    if (len < r0 + gap + 1) return((px, py, qx, qy))
    return((px + dx/len*r0, py + dy/len*r0, qx - dx/len*gap, qy - dy/len*gap))
}
// penalty for a leader that crosses other labels, markers, line pieces or other leaders
real scalar _gpl_leadcost(real rowvector s, real matrix O, real rowvector own, real matrix B, real matrix L,
                          real scalar i, real scalar h)
{
    real scalar c
    real scalar j
    real matrix Bo
    real matrix Lo
    real colvector keep
    c = 0
    keep = (1::rows(B)) :!= i
    Bo = select(B, keep)
    c = c + 2*h*h*_gpl_seghitn(s, Bo)
    Lo = select(L, keep :& (L[,1] :< .))
    for (j=1; j<=rows(Lo); j++) {
        if (_gpl_segx(s, Lo[j,])) c = c + 1.5*h*h
    }
    c = c + 0.15*h*h*_gpl_seghitn(s, O)
    return(c)
}
// how many boxes in O does segment s touch? (bounding-box prefilter, then exact test)
real scalar _gpl_seghitn(real rowvector s, real matrix O)
{
    real colvector sel
    real scalar n
    real scalar k
    if (rows(O) == 0) return(0)
    sel = selectindex((O[,3] :>= min((s[1], s[3]))) :& (O[,1] :<= max((s[1], s[3]))) :&
                      (O[,4] :>= min((s[2], s[4]))) :& (O[,2] :<= max((s[2], s[4]))))
    // selectindex() returns a 1 x 0 result when nothing matches, so count with length()
    n = 0
    for (k=1; k<=length(sel); k++) n = n + _gpl_seghit(s, O[sel[k],])
    return(n)
}
// does segment s = (x0, y0, x1, y1) touch box b? (Liang-Barsky)
real scalar _gpl_seghit(real rowvector s, real rowvector b)
{
    real scalar t0
    real scalar t1
    real scalar dx
    real scalar dy
    real scalar k
    real scalar p
    real scalar q
    real scalar t
    real matrix PQ
    dx = s[3] - s[1]
    dy = s[4] - s[2]
    if (max((s[1], s[3])) < b[1] | min((s[1], s[3])) > b[3] | max((s[2], s[4])) < b[2] | min((s[2], s[4])) > b[4]) return(0)
    PQ = (-dx, s[1] - b[1] \ dx, b[3] - s[1] \ -dy, s[2] - b[2] \ dy, b[4] - s[2])
    t0 = 0
    t1 = 1
    for (k=1; k<=4; k++) {
        p = PQ[k,1]
        q = PQ[k,2]
        if (p == 0) {
            if (q < 0) return(0)
        }
        else {
            t = q/p
            if (p < 0) {
                if (t > t0) t0 = t
            }
            else {
                if (t < t1) t1 = t
            }
            if (t0 > t1) return(0)
        }
    }
    return(1)
}
// do two segments cross?
real scalar _gpl_segx(real rowvector a, real rowvector b)
{
    real scalar d1
    real scalar d2
    real scalar d3
    real scalar d4
    d1 = (b[3]-b[1])*(a[2]-b[2]) - (b[4]-b[2])*(a[1]-b[1])
    d2 = (b[3]-b[1])*(a[4]-b[2]) - (b[4]-b[2])*(a[3]-b[1])
    d3 = (a[3]-a[1])*(b[2]-a[2]) - (a[4]-a[2])*(b[1]-a[1])
    d4 = (a[3]-a[1])*(b[4]-a[2]) - (a[4]-a[2])*(b[3]-a[1])
    return(d1*d2 < 0 & d3*d4 < 0)
}
real rowvector _gpl_box(real scalar x, real scalar y, real scalar w, real scalar h, real rowvector c)
{
    real scalar cx
    real scalar cy
    cx = x + c[2] + c[1]*w/2
    cy = y + c[3]
    return((cx - w/2, cy - h/2, cx + w/2, cy + h/2))
}

// ---------------------------------------------------------------- automatic callout box
// searches rings around the target for the free-est spot; returns (x0, y0, x1, y1, overlap flag)
void _gpl_autobox(string scalar out, real scalar tx, real scalar ty, real scalar w, real scalar h, real scalar fs,
                  real scalar x0, real scalar x1, real scalar y0, real scalar y1)
{
    real matrix O
    real rowvector b
    real rowvector best
    real scalar a
    real scalar r
    real scalar k
    real scalar c
    real scalar bc
    real scalar hard
    real scalar bh
    real scalar cx
    real scalar cy
    real scalar pad

    O = *_gpl_ext("_gpl_OBS")
    pad = 0.4*fs
    bc = .
    bh = 0
    for (k=1; k<=6; k++) {
        r = (1.5 + 1.5*k)*fs
        for (a=0; a<360; a=a+15) {
            // box centre pushed out so its near edge sits r from the target
            cx = tx + cos(a*pi()/180)*(r + w/2)
            cy = ty + sin(a*pi()/180)*(r + h/2)
            b = (cx - w/2 - pad, cy - h/2 - pad, cx + w/2 + pad, cy + h/2 + pad)
            hard = _gpl_obscost(b, O)
            if (b[1] < x0) hard = hard + 1000*(x0-b[1])*h
            if (b[3] > x1) hard = hard + 1000*(b[3]-x1)*h
            if (b[2] < y0) hard = hard + 1000*(y0-b[2])*w
            if (b[4] > y1) hard = hard + 1000*(b[4]-y1)*w
            c = hard + 0.02*r*h + 0.004*h*h*abs(sin(a*pi()/180))
            if (c < bc) {
                bc = c
                best = (cx - w/2, cy - h/2, cx + w/2, cy + h/2)
                bh = hard
            }
        }
    }
    st_matrix(out, (best, (bh > 0.15*w*h)))
    _gpl_obs_add(best)
}

// ---------------------------------------------------------------- curved arrow
// quadratic Bezier in device space, returned as data-space segments; stops `shrink` short of the target
void _gpl_bezier(string scalar nm, real rowvector p0, real rowvector p2, real scalar curve,
                 real scalar nseg, real scalar head, real scalar xa, real scalar xb,
                 real scalar ya, real scalar yb, real scalar xlog, real scalar ylog, real scalar shrink)
{
    real rowvector p1
    real rowvector d
    real rowvector perp
    real rowvector tn
    real matrix pts
    real matrix S
    real scalar i
    real scalar u
    real scalar len
    real scalar a
    real rowvector h1
    real rowvector h2

    d = p2 - p0
    len = sqrt(d*d')
    if (len < 1) {
        st_matrix(nm, J(0, 4, .))
        return
    }
    p2 = p2 - shrink*d/len
    d = p2 - p0
    len = sqrt(d*d')
    perp = (-d[2], d[1])/len
    p1 = (p0 + p2)/2 + curve*len*perp
    pts = J(nseg+1, 2, .)
    for (i=0; i<=nseg; i++) {
        u = i/nseg
        pts[i+1,] = (1-u)^2*p0 + 2*u*(1-u)*p1 + u^2*p2
    }
    S = (pts[1::nseg,], pts[2::(nseg+1),])
    tn = p2 - p1
    tn = tn/sqrt(tn*tn')
    a = 25*pi()/180
    h1 = p2 - head*(tn[1]*cos(a) - tn[2]*sin(a), tn[1]*sin(a) + tn[2]*cos(a))
    h2 = p2 - head*(tn[1]*cos(a) + tn[2]*sin(a), -tn[1]*sin(a) + tn[2]*cos(a))
    S = S \ (p2, h1) \ (p2, h2)
    S[,1] = (S[,1] :- xa)/xb
    S[,3] = (S[,3] :- xa)/xb
    S[,2] = (S[,2] :- ya)/yb
    S[,4] = (S[,4] :- ya)/yb
    if (xlog) {
        S[,1] = exp(S[,1])
        S[,3] = exp(S[,3])
    }
    if (ylog) {
        S[,2] = exp(S[,2])
        S[,4] = exp(S[,4])
    }
    st_matrix(nm, S)
}

// ---------------------------------------------------------------- curly brace
// path from a to b (device units) with the tip w to the left of the direction of travel
// (right if flip); returns data-space segments and the label anchor (x, y, normal x, normal y)
void _gpl_bracepath(string scalar nm, string scalar tnm, real rowvector a, real rowvector b, real scalar w,
                    real scalar flip, real scalar gap, real scalar xa, real scalar xb, real scalar ya,
                    real scalar yb, real scalar xlog, real scalar ylog)
{
    real rowvector d
    real rowvector n
    real rowvector tip
    real matrix pts
    real matrix S
    real matrix Q
    real scalar L
    real scalar q
    real scalar i
    real scalar u
    real scalar k
    real scalar s0
    real scalar s1
    real scalar o0
    real scalar o1
    real scalar sc
    real scalar oc

    d = b - a
    L = sqrt(d*d')
    d = d/L
    n = (-d[2], d[1])
    if (flip) n = -n
    q = min((w/2, L/4))
    // four quarter-curves in (along, offset) coordinates: start, control, end
    Q = (0, 0,            0, w/2,        q, w/2 \
         L/2 - q, w/2,    L/2, w/2,      L/2, w \
         L/2, w,          L/2, w/2,      L/2 + q, w/2 \
         L - q, w/2,      L, w/2,        L, 0)
    pts = J(0, 2, .)
    for (k=1; k<=4; k++) {
        s0 = Q[k,1]
        o0 = Q[k,2]
        sc = Q[k,3]
        oc = Q[k,4]
        s1 = Q[k,5]
        o1 = Q[k,6]
        for (i=0; i<=10; i++) {
            u = i/10
            pts = pts \ ( ((1-u)^2*s0 + 2*u*(1-u)*sc + u^2*s1), ((1-u)^2*o0 + 2*u*(1-u)*oc + u^2*o1) )
        }
    }
    pts = J(rows(pts), 1, a) + pts[,1]*d + pts[,2]*n
    S = (pts[1::(rows(pts)-1),], pts[2::rows(pts),])
    tip = (a + b)/2 + (w + gap)*n
    S[,1] = (S[,1] :- xa)/xb
    S[,3] = (S[,3] :- xa)/xb
    S[,2] = (S[,2] :- ya)/yb
    S[,4] = (S[,4] :- ya)/yb
    tip[1] = (tip[1] - xa)/xb
    tip[2] = (tip[2] - ya)/yb
    if (xlog) {
        S[,1] = exp(S[,1])
        S[,3] = exp(S[,3])
        tip[1] = exp(tip[1])
    }
    if (ylog) {
        S[,2] = exp(S[,2])
        S[,4] = exp(S[,4])
        tip[2] = exp(tip[2])
    }
    st_matrix(nm, S)
    st_matrix(tnm, (tip, n))
}
end
