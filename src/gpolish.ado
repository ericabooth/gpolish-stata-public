*! gpolish 0.5.0  post-hoc polish + layout layer for Stata graphs
*! gpolish [style] | endlabel | callout | note | arrow | brace | bracket | ptlabel | legend | clear | render | limits | geom
*! Requires Stata 16+. Uses undocumented graph-object members and gr_edit.
program gpolish
    version 16
    * $ and literal backticks in label text would be expanded again by gr_edit;
    * store them as SMCL character codes, which graph text renders literally
    mata: st_local("0", _gpl_esc(st_local("0")))
    gettoken sub rest : 0, parse(" ,")
    if "`sub'"=="endlabel"      _gpl_endlabel `rest'
    else if "`sub'"=="callout"  _gpl_callout `rest'
    else if "`sub'"=="note"     _gpl_callout `rest' isnote
    else if "`sub'"=="arrow"    _gpl_arrow `rest'
    else if "`sub'"=="brace"    _gpl_brace `rest'
    else if "`sub'"=="bracket"  _gpl_bracket `rest'
    else if "`sub'"=="ptlabel"  _gpl_ptlabel `rest'
    else if "`sub'"=="legend"   _gpl_legend `rest'
    else if "`sub'"=="clear"    _gpl_clear `rest'
    else if "`sub'"=="render"   _gpl_render `rest'
    else if "`sub'"=="limits"   _gpl_limits `rest'
    else if "`sub'"=="geom"     _gpl_geom `rest'
    else if "`sub'"=="style"    _gpl_style `rest'
    else                        _gpl_style `0'
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
    if "`fam'"!="twoway" {
        di as err "gpolish: graph `name' is a `fam' graph; the layout commands support twoway graphs only."
        di as err "         {bf:gpolish render} (gr2mpl) can redraw bar graphs in the same style."
        exit 198
    }
    quietly graph display `name'
    * font used for PNG export decides the width table
    capture quietly graph set window
    if !_rc & "`r(fontface)'"!="" global GPL_FONT = lower("`r(fontface)'")
    else global GPL_FONT "helvetica"
    mata: st_local("known", strofreal(_gpl_fontknown("$GPL_FONT")))
    if !`known' & "$GPL_FONTWARNED"!="$GPL_FONT" {
        di as txt "note: gpolish has no width table for font {bf:$GPL_FONT}; using Arial metrics, so label spacing is approximate."
        global GPL_FONTWARNED "$GPL_FONT"
    }
    return local name `name'
end

program _gpl_geom, rclass
    syntax [, name(string)]
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
    local pr .`name'.plotregion1
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

* evaluate an x y pair; each may be a number or an expression without spaces, e.g. td(01sep2001)
program _gpl_xy, rclass
    args opt val
    tokenize `"`val'"'
    if `"`2'"'=="" | `"`3'"'!="" {
        di as err "gpolish: `opt'() needs two values, x and y, for example `opt'(1990 45) or `opt'(td(01sep2001) 1000);"
        di as err "         write each value without spaces"
        exit 198
    }
    forvalues i = 1/2 {
        capture local v`i' = ``i''
        if _rc | missing(real("`v`i''")) {
            di as err `"gpolish: `opt'(): cannot read {bf:``i''} as a number or expression"'
            exit 198
        }
    }
    return scalar x = `v1'
    return scalar y = `v2'
end

* session record of what endlabel added to a graph, so a re-run or gpolish clear can undo it
program _gpl_regget, rclass
    args name
    local sig `"`.`name'.date' `.`name'.time' `.`name'.plotregion1.dynamicmv.arrnels'"'
    mata: st_local("rsig", _gpl_reg_get("`name'|sig"))
    return local ok 0
    if `"`rsig'"'!=`"`sig'"' exit
    mata: st_local("txt", _gpl_reg_get("`name'|txt"))
    mata: st_local("mk", _gpl_reg_get("`name'|mk"))
    _gpl_count `name' added_text
    local nt = r(k)
    _gpl_count `name' added_markers
    local nm = r(k)
    local stale 0
    foreach k of local txt {
        if `k' > `nt' local stale 1
    }
    foreach k of local mk {
        if `k' > `nm' local stale 1
    }
    if `stale' exit
    return local ok 1
    return local txt `txt'
    return local mk `mk'
    mata: st_local("v", _gpl_reg_get("`name'|side"))
    return local side `v'
    mata: st_local("v", _gpl_reg_get("`name'|m"))
    return local m `v'
    mata: st_local("v", _gpl_reg_get("`name'|leg"))
    return local leg `v'
end

* undo a recorded endlabel: hide its objects, give back its margin, restore the legend
program _gpl_regundo
    args name
    _gpl_regget `name'
    if "`r(ok)'"!="1" exit
    * copy the record first: gr_edit clears r()
    local txt `r(txt)'
    local mk `r(mk)'
    local m `r(m)'
    local side `r(side)'
    local leg `r(leg)'
    foreach k of local txt {
        gr_edit .plotregion1.added_text[`k'].draw_view.setstyle, style(no)
    }
    foreach k of local mk {
        gr_edit .plotregion1.added_markers[`k'].draw_view.setstyle, style(no)
    }
    if "`m'"!="" {
        local s = cond("`side'"=="left", "l", "r")
        gr_edit .style.editstyle margin(`s'-`m') editcopy
    }
    if "`leg'"=="1" gr_edit .legend.draw_view.setstyle, style(yes)
    mata: _gpl_reg_drop("`name'")
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
    gr_edit .plotregion1.AddTextBox added_text editor `y' `x'
    gr_edit .plotregion1.added_text_new = `k'
    gr_edit .plotregion1.added_text_rec = `k'
    local box
    if "`fill'"!="" {
        if "`border'"=="" local border "`fill'"
        _gpl_geom, name(`name')
        local ph = `pad'*r(relperpt)
        local pv = 0.7*`pad'*r(relperpt)
        local box drawbox(yes) fillcolor("`fill'") linestyle(color("`border'") width(thin)) margin(`ph' `ph' `pv' `pv')
    }
    else if "`halo'"!="" local box drawbox(yes) fillcolor(white%80) linestyle(color(white%0) width(none)) boxmargin(0.5 0.5 0.2 0.2)
    gr_edit .plotregion1.added_text[`k'].style.editstyle size(`size'pt) color("`color'") horizontal(`hz') vertical(middle) box_alignment(`ba') linegap(`linegap') `box' editcopy
    gr_edit .plotregion1.added_text[`k'].text = {}
    foreach l of local lines {
        gr_edit .plotregion1.added_text[`k'].text.Arrpush `"`l'"'
    }
    if `angle'!=0 {
        * store the request; Stata itself only draws quarter turns
        capture gr_edit .plotregion1.added_text[`k'].style.editstyle angle(`angle') editcopy
        if inlist(`angle', 90, -270) capture gr_edit .plotregion1.added_text[`k'].orientation.setstyle, style(vertical)
        else if inlist(`angle', -90, 270) capture gr_edit .plotregion1.added_text[`k'].orientation.setstyle, style(rvertical)
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
    gr_edit .plotregion1.AddLine added_lines editor `seg'
    gr_edit .plotregion1.added_lines_new = `k'
    gr_edit .plotregion1.added_lines_rec = `k'
    gr_edit .plotregion1.added_lines[`k'].style.editstyle linestyle(width(`lwidth') color("`lcolor'")) headstyle(symbol(none)) editcopy
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
        di as txt "      ({bf:gpolish legend}, {bf:gpolish endlabel}), or finish in matplotlib with {bf:gpolish render}."
    }
end

* collect what is already drawn: marker points, line paths, text boxes (device units, Mata externals)
program _gpl_obstacles
    args name
    _gpl_geom, name(`name')
    local xa = r(xa)
    local xb = r(xb)
    local ya = r(ya)
    local yb = r(yb)
    local xlog = r(xlog)
    local ylog = r(ylog)
    local gprel = r(gpi)/72/r(relperpt)
    local gpi = r(gpi)
    local pr .`name'.plotregion1
    mata: _gpl_obs_reset()
    local n = ``pr'.dynamicmv.arrnels'
    forvalues i = 1/`n' {
        local t ``pr'.plot`i'.type.setting'
        if !inlist("`t'","scatter","connected","line","rline","dot","function","spike","dropline") continue
        capture {
            local yv = ``pr'.plot`i'.yvar'
            local xv = ``pr'.plot`i'.xvar'
            local sid = ``pr'.plot`i'.serset.id'
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
        preserve
        capture {
            serset set `sid'
            serset use, clear
            unab all : *
            local yname : word `yv' of `all'
            local xname : word `xv' of `all'
            if `rad' > 0 mata: _gpl_obs_points("`xname'", "`yname'", `xlog', `ylog', `xa', `xb', `ya', `yb', `rad')
            if inlist("`t'","connected","line","rline","function") ///
                mata: _gpl_obs_path("`xname'", "`yname'", `xlog', `ylog', `xa', `xb', `ya', `yb', 4/72*`gpi')
        }
        restore
    }
    * text boxes already on the graph
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
        if "`keepyline'"==""  gr_edit .yaxis1.style.editstyle linestyle(color(none)) editcopy
        if "`keepyticks'"=="" gr_edit .yaxis1.style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
    }
    local nt `.`name'.title.text.arrnels'
    if "`nt'"=="" local nt 0
    forvalues i = 1/`nt' {
        local t`i' `"`.`name'.title.text[`i']'"'
        mata: st_local("t`i'", _gpl_esc(st_local("t`i'")))
        if strpos(`"`t`i''"', "{color") | strpos(`"`t`i''"', "{c #") _gpl_note inlinecolor
    }
    if "`bold'"=="" & `nt' > 0 {
        gr_edit .title.text = {}
        forvalues i = 1/`nt' {
            if substr(`"`t`i''"',1,4)=="{bf:" gr_edit .title.text.Arrpush `"`t`i''"'
            else gr_edit .title.text.Arrpush `"{bf:`t`i''}"'
        }
    }
end

* ================================================================ endlabel
program _gpl_endlabel
    syntax [, name(string) SIZe(real 9.5) GAP(real 1.3) VALues FORmat(string) noBOLD ///
              DOTs DOTSize(real 5.5) PLOTs(numlist integer >0) XGap(real 8) LABels(string asis) noREPEL ///
              WRAP(integer 0) SIDe(string) COLor(string) KEEPLegend]
    _gpl_name `name'
    local name `r(name)'
    if "`format'"=="" local format %4.1f
    if "`side'"=="" local side right
    if !inlist("`side'", "right", "left") {
        di as err "gpolish endlabel: side() must be right or left"
        exit 198
    }
    local pr .`name'.plotregion1
    local n = ``pr'.dynamicmv.arrnels'
    if "`plots'"=="" {
        forvalues i = 1/`n' {
            if inlist("``pr'.plot`i'.type.setting'","line","connected","rline") local plots `plots' `i'
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
    * a second endlabel replaces the first instead of stacking on it
    _gpl_regundo `name'
    * which end of each line sits on the chosen side of the plot, whatever the axis direction
    _gpl_geom, name(`name')
    local dir = cond("`side'"=="right", 1, -1)*sign(r(xb))
    local s = cond("`side'"=="right", 1, -1)
    local np : word count `plots'
    tempname Y
    matrix `Y' = J(`np', 5, 1)
    local j 0
    local maxn 0
    local maxv 0
    local q 0
    foreach i of local plots {
        local ++q
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
            local xl = cond(`dir' > 0, r(max), r(min))
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
        local lab`j'
        capture confirm variable `sname', exact
        if !_rc local lab`j' : variable label `sname'
        if `"`lab`j''"'=="" local lab`j' `"`slab'"'
        if `"`lab`j''"'=="" local lab`j' `sname'
        mata: st_local("lab`j'", _gpl_esc(st_local("lab`j'")))
        if `"`labels'"'!="" {
            * labels() follow the order of plots(), one per plot
            local ll : word `q' of `labels'
            if `"`ll'"'!="" local lab`j' `"`ll'"'
        }
        local col`j' ``pr'.plot`i'.style.line.color.rgb'
        if "``pr'.plot`i'.type.setting'"=="scatter" local col`j' ``pr'.plot`i'.style.marker.fillcolor.rgb'
        local col`j' : list retokenize col`j'
        local tcol`j' `"`col`j''"'
        if `"`color'"'!="" local tcol`j' `"`color'"'
        local val`j' : display `format' `yl'
        local val`j' = strtrim("`val`j''")
        matrix `Y'[`j',1] = `yl'
        matrix `Y'[`j',4] = `xl'
        * wrap long labels on word boundaries; wrap() is in characters, measured by rendered width
        mata: _gpl_wrap("lab`j'", "nl`j'", "w", 0.5*`wrap', "`bold'"=="")
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
    local mside = cond("`side'"=="right", "r", "l")
    gr_edit .style.editstyle margin(`mside'+`m') editcopy
    local leg 0
    if "`keeplegend'"=="" & "`.`name'.legend.draw_view.setting'"=="yes" {
        gr_edit .legend.draw_view.setstyle, style(no)
        local leg 1
    }
    _gpl_geom, name(`name')
    local ya = r(ya)
    local yb = r(yb)
    local xa = r(xa)
    local xb = r(xb)
    local gpi = r(gpi)
    local xlog = r(xlog)
    local ylog = r(ylog)
    forvalues j = 1/`np' {
        matrix `Y'[`j',2] = `ya' + `yb'*cond(`ylog', ln(`Y'[`j',1]), `Y'[`j',1])
        matrix `Y'[`j',3] = `Y'[`j',2]
    }
    local sep = `gap'*`size'/72*`gpi'
    if "`repel'"=="" mata: _gpl_repel("`Y'", `sep', `r(gy0)', `r(gy1)')
    _gpl_count `name' added_markers
    local km = r(k)
    local regtxt
    local regmk
    * labels sit next to the line end; the value column sits beyond them
    local hzl = cond(`s' > 0, "left", "right")
    local bal = cond(`s' > 0, "east", "west")
    local hzv = cond(`s' > 0, "right", "left")
    local bav = cond(`s' > 0, "west", "east")
    forvalues j = 1/`np' {
        local ynew = (`Y'[`j',3] - `ya')/`yb'
        if `ylog' local ynew = exp(`ynew')
        local xl = `Y'[`j',4]
        local yl = `Y'[`j',1]
        local gxl = `xa' + `xb'*cond(`xlog', ln(`xl'), `xl')
        local xpos = (`gxl' + `s'*`xgap'/72*`gpi' - `xa')/`xb'
        local xval = (`gxl' + `s'*(`xgap' + `maxw'*`size')/72*`gpi' - `xa')/`xb'
        if `xlog' {
            local xpos = exp(`xpos')
            local xval = exp(`xval')
        }
        if "`dots'"!="" {
            local ++km
            gr_edit .plotregion1.AddMarker added_markers editor `xl' `yl'
            gr_edit .plotregion1.added_markers_new = `km'
            gr_edit .plotregion1.added_markers_rec = `km'
            gr_edit .plotregion1.added_markers[`km'].style.editstyle marker(symbol(circle) size(`dotsize'pt) fillcolor("`col`j''") linestyle(color(white) width(vthin))) editcopy
            local regmk `regmk' `km'
        }
        local lines
        forvalues q = 1/`nl`j'' {
            if "`bold'"=="" local lines `"`lines' `"{bf:`lab`j'_`q''}"'"'
            else local lines `"`lines' `"`lab`j'_`q''"'"'
        }
        _gpl_addtext, name(`name') x(`xpos') y(`ynew') lines(`lines') size(`size') color(`"`tcol`j''"') hz(`hzl') ba(`bal') linegap(1pt)
        local regtxt `regtxt' `r(k)'
        if "`values'"!="" {
            _gpl_addtext, name(`name') x(`xval') y(`ynew') lines(`"`val`j''"') size(`size') color(`"`tcol`j''"') hz(`hzv') ba(`bav')
            local regtxt `regtxt' `r(k)'
        }
    }
    * record what was added, so a re-run or gpolish clear can undo it this session
    local sig `"`.`name'.date' `.`name'.time' `.`name'.plotregion1.dynamicmv.arrnels'"'
    mata: _gpl_reg_set("`name'|sig", st_local("sig"))
    mata: _gpl_reg_set("`name'|txt", "`regtxt'")
    mata: _gpl_reg_set("`name'|mk", "`regmk'")
    mata: _gpl_reg_set("`name'|side", "`side'")
    mata: _gpl_reg_set("`name'|m", "`m'")
    mata: _gpl_reg_set("`name'|leg", "`leg'")
end

* ================================================================ clear
* remove every added text box, line and marker, and undo endlabel's margin and legend changes
program _gpl_clear
    syntax [, name(string)]
    _gpl_name `name'
    local name `r(name)'
    _gpl_regundo `name'
    local msg
    foreach a in added_text added_lines added_markers {
        _gpl_count `name' `a'
        local k`a' = r(k)
        if r(k) > 0 {
            gr_edit .plotregion1.`a' = {}
            gr_edit .plotregion1.`a'_new = 0
            gr_edit .plotregion1.`a'_rec = 0
        }
    }
    di as txt "gpolish clear: removed `kadded_text' text box(es), `kadded_lines' line segment(s) and `kadded_markers' marker(s)"
    di as txt "  (this includes anything added in the Graph Editor; the title and axis edits of {bf:gpolish} stay)"
end

* ================================================================ callout
program _gpl_callout
    syntax anything(name=txt id="text" everything), [at(string) to(string) ///
        FRom(string) name(string) CURve(real 0.25) SIZe(real 8.8) COLor(string) ///
        LColor(string) ALign(string) HEADsize(real 4.5) SEGments(integer 24) LWidth(string) ANGle(real 0) HALO noARROW ///
        FILL(string) BORder(string) PAD(real 5) ISNOTE]
    _gpl_name `name'
    local name `r(name)'
    if `"`at'"'=="" & `"`to'"'=="" {
        di as err "gpolish callout: give at(x y) for the text, to(x y) for the arrow target, or both"
        exit 198
    }
    foreach o in at to from {
        if `"``o''"'!="" {
            _gpl_xy `o' `"``o''"'
            local `o'x = r(x)
            local `o'y = r(y)
        }
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
    * anchor of the text box in data units (left-middle, centre or right-middle)
    local gx = cond("`align'"=="right", `B'[1,3], cond("`align'"=="center", (`B'[1,1]+`B'[1,3])/2, `B'[1,1]))
    local gy = (`B'[1,2] + `B'[1,4])/2
    local px = (`gx' - `xa')/`xb'
    local py = (`gy' - `ya')/`yb'
    if `xlog' local px = exp(`px')
    if `ylog' local py = exp(`py')
    local ba = cond("`align'"=="right", "west", cond("`align'"=="center", "center", "east"))
    if "`fill'"!="" {
        * Stata pads a boxed text outward from its anchor, so anchor the text inside the padding
        local shift = cond("`align'"=="right", -1, cond("`align'"=="center", 0, 1))*`pad'/72*`gpi'
        local px = (`gx' + `shift' - `xa')/`xb'
        if `xlog' local px = exp(`px')
    }
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
    tempname P
    mata: _gpl_bezier("`P'", (`gfx', `gfy'), (`gtx', `gty'), `curve', `segments', `headsize'/72*`gpi', ///
        `xa', `xb', `ya', `yb', `xlog', `ylog', 0.3*`fs')
    local rows = rowsof(`P')
    forvalues i = 1/`rows' {
        _gpl_addline, name(`name') seg(`=`P'[`i',1]' `=`P'[`i',2]' `=`P'[`i',3]' `=`P'[`i',4]') lcolor(`lcolor') lwidth(`lwidth')
    }
end

* ================================================================ arrow
program _gpl_arrow
    syntax , FRom(string) to(string) [name(string) CURve(real 0) HEADsize(real 4.5) ///
        SEGments(integer 24) LColor(string) LWidth(string) SHRink(real 0)]
    _gpl_name `name'
    local name `r(name)'
    _gpl_xy from `"`from'"'
    local fx = r(x)
    local fy = r(y)
    _gpl_xy to `"`to'"'
    local tx = r(x)
    local ty = r(y)
    _gpl_geom, name(`name')
    local gfx = r(xa) + r(xb)*cond(r(xlog), ln(`fx'), `fx')
    local gfy = r(ya) + r(yb)*cond(r(ylog), ln(`fy'), `fy')
    local gtx = r(xa) + r(xb)*cond(r(xlog), ln(`tx'), `tx')
    local gty = r(ya) + r(yb)*cond(r(ylog), ln(`ty'), `ty')
    tempname P
    mata: _gpl_bezier("`P'", (`gfx', `gfy'), (`gtx', `gty'), `curve', `segments', `headsize'/72*`r(gpi)', ///
        `r(xa)', `r(xb)', `r(ya)', `r(yb)', `r(xlog)', `r(ylog)', `shrink'/72*`r(gpi)')
    local rows = rowsof(`P')
    forvalues i = 1/`rows' {
        _gpl_addline, name(`name') seg(`=`P'[`i',1]' `=`P'[`i',2]' `=`P'[`i',3]' `=`P'[`i',4]') lcolor(`lcolor') lwidth(`lwidth')
    }
end

* ================================================================ brace
* a curly brace between two points, with an optional label at its tip
program _gpl_brace
    syntax [anything(name=txt everything)], FRom(string) to(string) [name(string) ///
        Width(real 7) FLIP SIZe(real 8.8) COLor(string) LColor(string) LWidth(string) GAP(real 4)]
    _gpl_name `name'
    local name `r(name)'
    _gpl_xy from `"`from'"'
    local fx = r(x)
    local fy = r(y)
    _gpl_xy to `"`to'"'
    local tx = r(x)
    local ty = r(y)
    _gpl_geom, name(`name')
    local gpi = r(gpi)
    local xa = r(xa)
    local xb = r(xb)
    local ya = r(ya)
    local yb = r(yb)
    local xlog = r(xlog)
    local ylog = r(ylog)
    local gfx = `xa' + `xb'*cond(`xlog', ln(`fx'), `fx')
    local gfy = `ya' + `yb'*cond(`ylog', ln(`fy'), `fy')
    local gtx = `xa' + `xb'*cond(`xlog', ln(`tx'), `tx')
    local gty = `ya' + `yb'*cond(`ylog', ln(`ty'), `ty')
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
program _gpl_bracket
    syntax , x(real) y0(real) y1(real) [name(string) TICK(real 4) LColor(string) LWidth(string) LEFT]
    _gpl_name `name'
    local name `r(name)'
    _gpl_geom, name(`name')
    local dg = cond("`left'"!="", -1, 1)*sign(r(xb))*`tick'/72*r(gpi)
    local gx = r(xa) + r(xb)*cond(r(xlog), ln(`x'), `x')
    local x2 = (`gx' + `dg' - r(xa))/r(xb)
    if r(xlog) local x2 = exp(`x2')
    local segs `" "`x' `y0' `x' `y1'" "`x' `y0' `x2' `y0'" "`x' `y1' `x2' `y1'" "'
    foreach s of local segs {
        _gpl_addline, name(`name') seg(`s') lcolor(`lcolor') lwidth(`lwidth')
    }
end

* ================================================================ legend
program _gpl_legend
    syntax [, name(string) noBOLD PLOTs(numlist integer >0)]
    _gpl_name `name'
    local name `r(name)'
    local n = `.`name'.plotregion1.dynamicmv.arrnels'
    if "`.`name'.legend.draw_view.setting'"!="yes" {
        di as txt "note: graph {bf:`name'} shows no legend; nothing to colour"
        exit
    }
    if "`plots'"=="" {
        forvalues i = 1/`n' {
            local plots `plots' `i'
        }
    }
    local k 0
    foreach i of local plots {
        local ++k
        local t `.`name'.plotregion1.plot`i'.type.setting'
        if inlist("`t'","line","connected","rline","function") local c `.`name'.plotregion1.plot`i'.style.line.color.rgb'
        else if inlist("`t'","bar","area","rarea","rbar") local c `.`name'.plotregion1.plot`i'.style.area.shadestyle.color.rgb'
        else local c `.`name'.plotregion1.plot`i'.style.marker.fillcolor.rgb'
        local c : list retokenize c
        capture gr_edit .legend.plotregion1.label[`k'].style.editstyle color("`c'") editcopy
        if _rc continue
        if "`bold'"=="" {
            local s `"`.`name'.legend.plotregion1.label[`k'].text[1]'"'
            mata: st_local("s", _gpl_esc(st_local("s")))
            if substr(`"`s'"',1,4)!="{bf:" {
                gr_edit .legend.plotregion1.label[`k'].text = {}
                gr_edit .legend.plotregion1.label[`k'].text.Arrpush `"{bf:`s'}"'
            }
        }
    }
end

* ================================================================ ptlabel
program _gpl_ptlabel
    syntax varname(string) [if] [in], x(varname numeric) y(varname numeric) [name(string) SIZe(real 8.6) ///
        COLor(string) OFFset(real 3) MSize(real 6) HALO]
    _gpl_name `name'
    local name `r(name)'
    marksample touse, novarlist strok
    quietly count if `touse' & !missing(`x', `y') & `varlist'!=""
    if r(N)==0 {
        di as txt "note: gpolish ptlabel: no observations to label (check the if/in condition and x(), y())"
        exit
    }
    _gpl_obstacles `name'
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
        gen double `gx' = `xa' + `xb'*cond(`xlog', ln(`x'), `x')
        gen double `gy' = `ya' + `yb'*cond(`ylog', ln(`y'), `y')
        gen byte `sel' = `touse' & !missing(`gx', `gy') & `varlist'!=""
    }
    tempname R
    mata: _gpl_place("`gx'", "`gy'", "`varlist'", "`sel'", "`R'", `size'/72*`gpi', `msize'/72*`gpi'/2, ///
        `offset'/72*`gpi', `r(gx0)', `r(gx1)', `r(gy0)', `r(gy1)')
    local nl = rowsof(`R')
    local bad 0
    forvalues i = 1/`nl' {
        local obs = `R'[`i',1]
        local px = (`R'[`i',2] - `xa')/`xb'
        local py = (`R'[`i',3] - `ya')/`yb'
        if `xlog' local px = exp(`px')
        if `ylog' local py = exp(`py')
        local h = `R'[`i',4]
        local hz = cond(`h'==-1, "left", cond(`h'==1, "right", "center"))
        local ba : word `=`R'[`i',5]' of east west north south
        local t = `varlist'[`obs']
        mata: st_local("t", _gpl_esc(st_local("t")))
        local bad = `bad' + (`R'[`i',6] > 0)
        _gpl_addtext, name(`name') x(`px') y(`py') lines(`"`t'"') size(`size') color("`color'") hz(`hz') ba(`ba') `halo'
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
        quietly graph describe
        local name `r(fn)'
    }
    gr2mpl, name(`name') `options'
end

program _gpl_limits
    di as txt _n "{bf:What gpolish can and cannot draw inside Stata}" _n
    di as txt "  Works in Stata                          Needs {bf:gpolish render} (matplotlib PNG)"
    di as txt "  {hline 38}  {hline 44}"
    di as txt "  bold, left-aligned titles               words in different colours inside one line"
    di as txt "  end-of-line labels with repel            text at angles other than 0/90/270 degrees"
    di as txt "  value columns, end dots                 soft white halo behind text (Stata: {bf:halo} = white box)"
    di as txt "  auto-placed point labels and callouts   by(), box, dot graphs in the same house style"
    di as txt "  curved arrows (open heads), brackets    filled arrow heads, gradients, rounded bars"
    di as txt "  legend text coloured like its keys      " _n
    di as txt "  The output of gpolish is still a Stata graph (edit, combine, export to any format)."
    di as txt "  {bf:gpolish render} carries every gpolish edit into the matplotlib version; its output is a PNG only."
end

mata:
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

// ---------------------------------------------------------------- session registry
void _gpl_reg_set(string scalar key, string scalar val)
{
    pointer() scalar p
    p = findexternal("_gpl_REG")
    if (p == NULL) {
        p = crexternal("_gpl_REG")
        *p = asarray_create()
    }
    asarray(*p, key, val)
}
string scalar _gpl_reg_get(string scalar key)
{
    pointer() scalar p
    p = findexternal("_gpl_REG")
    if (p == NULL) return("")
    if (!asarray_contains(*p, key)) return("")
    return(asarray(*p, key))
}
void _gpl_reg_drop(string scalar name)
{
    pointer() scalar p
    string colvector k
    real scalar i
    p = findexternal("_gpl_REG")
    if (p == NULL) return
    k = asarray_keys(*p)
    for (i=1; i<=rows(k); i++) {
        if (substr(k[i], 1, strlen(name)+1) == name + "|") asarray_remove(*p, k[i])
    }
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

    s = subinstr(subinstr(s, "{c 36}", char(36)), "{c 96}", char(96))
    if (strpos(s, "{bf:")) {
        bold = 1
        s = subinstr(subinstr(s, "{bf:", ""), "}", "")
    }
    W = _gpl_fontw(font, bold)
    c = ascii(s)
    w = 0
    for (i=1; i<=cols(c); i++) {
        if (c[i] >= 32 & c[i] <= 126) w = w + W[c[i]-31]
        else if (c[i] >= 192) w = w + 0.57
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
// column 2 = anchors, column 3 = result, column 5 = number of text lines
void _gpl_repel(string scalar nm, real scalar sep, real scalar lo, real scalar hi)
{
    real matrix Y
    real colvector g
    real colvector o
    real colvector nl
    real scalar n
    real scalar k
    real scalar i
    real scalar d
    real scalar moved

    Y = st_matrix(nm)
    n = rows(Y)
    o = order(Y[,2], 1)
    g = Y[o,2]
    nl = Y[o,5]
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
        if (g[1] < lo) g[1] = lo
        if (g[n] > hi) g[n] = hi
        if (moved==0) break
    }
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
    real matrix S
    real scalar i
    real scalar len
    real scalar m
    real scalar j
    real scalar u
    real scalar h

    D = st_data(., (xv, yv))
    D = select(D, rowmissing(D) :== 0)
    if (rows(D) < 2) return
    gx = xa :+ xb*(xlog ? ln(D[,1]) : D[,1])
    gy = ya :+ yb*(ylog ? ln(D[,2]) : D[,2])
    h = step/2
    S = J(0, 4, .)
    for (i=1; i<rows(D); i++) {
        len = sqrt((gx[i+1]-gx[i])^2 + (gy[i+1]-gy[i])^2)
        m = max((1, ceil(len/step)))
        if (m > 400) m = 400
        for (j=0; j<m; j++) {
            u = j/m
            S = S \ (gx[i] + u*(gx[i+1]-gx[i]) - h, gy[i] + u*(gy[i+1]-gy[i]) - h,
                     gx[i] + u*(gx[i+1]-gx[i]) + h, gy[i] + u*(gy[i+1]-gy[i]) + h)
        }
        if (rows(S) > 20000) break
    }
    _gpl_obs_add(S)
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

// ---------------------------------------------------------------- 2-D point labels
// result rows: obs, anchor x, anchor y, halign (-1 left, 0 centre, 1 right), box alignment, overlap flag
void _gpl_place(string scalar gxv, string scalar gyv, string scalar labv, string scalar selv, string scalar out,
                real scalar fs, real scalar rad, real scalar off,
                real scalar x0, real scalar x1, real scalar y0, real scalar y1)
{
    real colvector gx
    real colvector gy
    real colvector idx
    string colvector lab
    real matrix B
    real matrix C
    real matrix R
    real matrix O
    real matrix Oi
    real colvector w
    real colvector choice
    real colvector resid
    real scalar m
    real scalar i
    real scalar j
    real scalar k
    real scalar pass
    real scalar c
    real scalar hardc
    real scalar bc
    real scalar h
    real scalar d
    real rowvector b
    real rowvector best
    real rowvector own
    string scalar font

    font = st_global("GPL_FONT")
    gx = st_data(., gxv)
    gy = st_data(., gyv)
    idx = selectindex(st_data(., selv))
    m = rows(idx)
    lab = st_sdata(idx, labv)
    O = *_gpl_ext("_gpl_OBS")
    w = J(m, 1, 0)
    for (i=1; i<=m; i++) w[i] = _gpl_textw(font, lab[i], 0)*fs
    h = fs*1.15
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
    B = J(m, 4, .)
    for (i=1; i<=m; i++) B[i,] = _gpl_box(gx[idx[i]], gy[idx[i]], w[i], h, C[1,])
    for (pass=1; pass<=4; pass++) {
        for (i=1; i<=m; i++) {
            // the point's own marker is not an obstacle for its own label
            own = (gx[idx[i]]-rad*1.01, gy[idx[i]]-rad*1.01, gx[idx[i]]+rad*1.01, gy[idx[i]]+rad*1.01)
            Oi = O
            bc = .
            for (k=1; k<=rows(C); k++) {
                b = _gpl_box(gx[idx[i]], gy[idx[i]], w[i], h, C[k,])
                hardc = 2*(_gpl_obscost(b, Oi) - _gpl_ov(b, own))
                if (hardc < 0) hardc = 0
                for (j=1; j<=m; j++) {
                    if (j==i) continue
                    if (pass==1 & j>i) continue
                    hardc = hardc + 4*_gpl_ov(b, B[j,])
                }
                if (b[1] < x0) hardc = hardc + 1000*(x0-b[1])*h
                if (b[3] > x1) hardc = hardc + 1000*(b[3]-x1)*h
                if (b[2] < y0) hardc = hardc + 1000*(y0-b[2])*w[i]
                if (b[4] > y1) hardc = hardc + 1000*(b[4]-y1)*w[i]
                c = hardc + C[k,5]*h*h
                if (c < bc) {
                    bc = c
                    choice[i] = k
                    best = b
                    resid[i] = hardc
                }
            }
            B[i,] = best
        }
    }
    R = J(m, 6, .)
    for (i=1; i<=m; i++) {
        k = choice[i]
        R[i,1] = idx[i]
        R[i,2] = gx[idx[i]] + C[k,2]
        R[i,3] = gy[idx[i]] + C[k,6]
        R[i,4] = C[k,4]
        R[i,5] = C[k,7]
        R[i,6] = (resid[i] > 0.35*w[i]*h)
    }
    st_matrix(out, R)
    _gpl_obs_add(B)
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
