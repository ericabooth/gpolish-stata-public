*! gr2mpl 0.5.0  redraw a Stata graph held in memory with matplotlib
*! Walks the graph object (not the syntax), writes a JSON spec + serset CSVs,
*! then runs gr2mpl_render.py (embedded Python if it has matplotlib, else a shell
*! call). Returns a PNG. Families: twoway, graph bar/hbar/dot/box, graph matrix, by(), combine.
program gr2mpl, rclass
    version 16
    syntax [anything(name=sub)] [, name(string) SAVing(string) Width(integer 0) ///
        DPI(integer 200) ENDLabels noLEGend FONT(string) PYthon(string) KEEPspec ///
        PALette(string) SPECdir(string) noGRID REPLACE DOCtor noHALO noTICKs ROUNDbox ///
        LWScale(real 1) MSScale(real 1)]

    if "`sub'" == "doctor" | "`doctor'" != "" {
        _g2m_doctor, python(`"`python'"') font(`"`font'"')
        return add
        exit
    }
    if "`sub'" != "" {
        di as err "gr2mpl: unknown subcommand `sub'"
        exit 198
    }

    if "`name'" == "" {
        * default to the current graph, whatever it is named
        capture quietly graph describe
        if _rc {
            di as err "gr2mpl: no graph in memory"
            exit 111
        }
        local name `r(fn)'
    }
    local g .`name'
    capture local fam `"``g'.graphfamily'"'
    if _rc | `"`fam'"' == "" {
        di as err "graph `name' not found in memory"
        exit 111
    }
    if "``g'.classname'" == "piegraph_g" local fam pie
    if !inlist("`fam'", "twoway", "bar", "by", "combine", "matrix") {
        di as err "gr2mpl: graph family `fam' is not supported"
        di as err "        (supported: twoway, graph bar/hbar/dot/box, graph matrix, by(), graph combine)"
        exit 198
    }

    * ---- python + renderer -------------------------------------------------
    capture findfile gr2mpl_render.py
    if _rc {
        di as err "gr2mpl_render.py not found on the adopath"
        exit 601
    }
    local render `"`r(fn)'"'
    _g2m_python, python(`"`python'"')
    local pymode `s(mode)'
    local pyexe `"`s(python)'"'

    * ---- output locations --------------------------------------------------
    if `"`saving'"' == "" local saving "`name'_mpl.png"
    mata: st_local("sfx", strlower(pathsuffix(st_local("saving"))))
    if `"`sfx'"' == "" {
        local sfx ".png"
        local saving `"`saving'.png"'
    }
    if !inlist(`"`sfx'"', ".png", ".pdf", ".svg", ".jpg", ".jpeg") {
        di as err `"gr2mpl: saving() must end in .png, .pdf, .svg or .jpg (got `sfx')"'
        exit 198
    }
    local sdir = ustrregexra(`"`saving'"', "[^/\\\\]*$", "")
    if `"`sdir'"' != "" {
        mata: st_local("dok", strofreal(direxists(st_local("sdir"))))
        if "`dok'" != "1" {
            di as err `"gr2mpl: folder `sdir' does not exist"'
            exit 603
        }
    }
    if "`replace'" == "" {
        capture confirm new file `"`saving'"'
        if _rc {
            di as err `"gr2mpl: file `saving' already exists; add the replace option"'
            exit 602
        }
    }
    if "`specdir'" == "" {
        tempfile tf
        local specdir "`tf'_g2m"
    }
    capture mkdir "`specdir'"
    local spec "`specdir'/spec.json"
    local outtmp "`specdir'/render_out`sfx'"
    capture erase "`specdir'/skipped.txt"
    capture erase "`specdir'/notes.txt"
    capture erase "`outtmp'"
    capture erase "`spec'"

    tempname fh
    file open `fh' using "`spec'", write text
    file write `fh' "{" _n

    * ---- graph-level -------------------------------------------------------
    _g2m_kv `fh' "family" `"`fam'"'
    _g2m_kv `fh' "name" `"`name'"'
    _g2m_kv `fh' "command" `"``g'.command'"'
    capture local xs = ``g'.style.declared_xsize.val'
    if _rc local xs = 5.5
    capture local ys = ``g'.style.declared_ysize.val'
    if _rc local ys = 4
    file write `fh' `"  "xsize": `xs', "ysize": `ys', "dpi": `dpi', "width": `width',"' _n
    _g2m_kv `fh' "saving" `"`outtmp'"'
    _g2m_kv `fh' "font" `"`font'"'
    _g2m_kv `fh' "palette" `"`palette'"'
    _g2m_kv `fh' "specdir" `"`specdir'"'
    file write `fh' `"  "lwscale": `lwscale', "msscale": `msscale',"' _n
    file write `fh' `"  "endlabels": `=("`endlabels'"!="")', "nolegend": `=("`legend'"!="")', "' ///
        `""nogrid": `=("`grid'"!="")', "nohalo": `=("`halo'"!="")', "noticks": `=("`ticks'"!="")', "' ///
        `""roundbox": `=("`roundbox'"!="")',"' _n

    foreach t in title subtitle note caption {
        _g2m_textarr `fh' "`t'" "`g'.`t'"
    }

    global G2M_DONE
    if "`fam'" == "matrix" {
        _g2m_matrix `fh' "`g'" "`specdir'"
    }
    else if inlist("`fam'", "by", "combine") {
        local np = ``g'.graphs.arrnels'
        capture local rows = ``g'.rows'
        capture local cols = ``g'.cols'
        file write `fh' `"  "rows": "`rows'", "cols": "`cols'","' _n
        foreach t in b1title b2title l1title l2title {
            _g2m_textarr `fh' "`t'" "`g'.`t'"
        }
        _g2m_pairs `fh' "`g'.style" "indiv_yrescale indiv_yrescale.setting" ///
            "indiv_xrescale indiv_xrescale.setting"
        file write `fh' _n
        _g2m_legend `fh' "`g'"
        file write `fh' `"  "panels": ["' _n
        forvalues k = 1/`np' {
            _g2m_panel `fh' "`g'.graphs[`k']" "`specdir'" "`fam'"
            if `k' < `np' file write `fh' ","
            file write `fh' _n
        }
        file write `fh' "  ]," _n
    }
    else {
        file write `fh' `"  "rows": "1", "cols": "1","' _n
        file write `fh' `"  "panels": ["' _n
        _g2m_panel `fh' "`g'" "`specdir'" "single"
        file write `fh' _n "  ]," _n
    }

    file write `fh' `"  "end": 1"' _n "}" _n
    file close `fh'

    * ---- render (to a temporary file, so a failure leaves an existing file alone)
    if "`pymode'" == "embedded" {
        capture noisily python script `"`render'"', args(`""`spec'""')
    }
    else {
        shell "`pyexe'" "`render'" "`spec'" > "`specdir'/render.log" 2>&1
    }
    capture confirm file `"`outtmp'"'
    if !_rc {
        capture copy `"`outtmp'"' `"`saving'"', replace
        if _rc {
            di as err `"gr2mpl: could not write `saving'"'
            exit 603
        }
    }
    capture confirm file `"`outtmp'"'
    if _rc {
        di as err "gr2mpl: rendering failed"
        if "`pymode'" != "embedded" {
            di as err "        see `specdir'/render.log"
            capture noisily type "`specdir'/render.log"
        }
        exit 698
    }
    * layers the renderer could not draw
    local unsupported
    capture confirm file "`specdir'/skipped.txt"
    if !_rc {
        tempname sk
        file open `sk' using "`specdir'/skipped.txt", read text
        file read `sk' line
        while r(eof) == 0 {
            if `"`line'"' != "" {
                di as txt "note: gr2mpl skipped " as res `"`line'"'
                local unsupported `"`unsupported'`=cond(`"`unsupported'"'=="", "", "; ")'`line'"'
            }
            file read `sk' line
        }
        file close `sk'
    }
    capture confirm file "`specdir'/notes.txt"
    if !_rc {
        tempname nt
        file open `nt' using "`specdir'/notes.txt", read text
        file read `nt' line
        while r(eof) == 0 {
            if `"`line'"' != "" di as txt `"note: `line'"'
            file read `nt' line
        }
        file close `nt'
    }
    di as txt "(matplotlib version of graph `name' written to " as res `"`saving'"' as txt ")"
    if "`keepspec'" != "" di as txt "(spec kept in `specdir')"
    return local unsupported `"`unsupported'"'
    return local pymode "`pymode'"
    return local python `"`pyexe'"'
    return local specdir `"`specdir'"'
    return local filename `"`saving'"'
end

* ---------------------------------------------------------------------------
* Python discovery
*   1 python() option  2 $GR2MPL_PYTHON  3 Stata's embedded Python
*   4 python3 on PATH.  The working choice is cached in $GR2MPL_PYRESOLVED.
* ---------------------------------------------------------------------------
program _g2m_python, sclass
    syntax [, python(string) REPORT]
    sreturn clear
    local tried
    * explicit choices are always re-checked; the cache serves the default path
    if `"`python'"' == "" & `"$GR2MPL_PYTHON"' == "" & `"$GR2MPL_PYRESOLVED"' != "" {
        sreturn local mode "$GR2MPL_PYMODE"
        sreturn local python `"$GR2MPL_PYRESOLVED"'
        sreturn local mplversion "$GR2MPL_MPLVERSION"
        exit
    }
    if `"`python'"' != "" local cands `"`"`python'"'"'
    else if `"$GR2MPL_PYTHON"' != "" local cands `"`"$GR2MPL_PYTHON"'"'
    foreach c of local cands {
        if strpos(`"`c'"', "/") | strpos(`"`c'"', "\") {
            capture confirm file `"`c'"'
            if _rc {
                di as err `"gr2mpl: Python interpreter `c' not found"'
                di as err "        check the python() option or the global GR2MPL_PYTHON"
                exit 601
            }
        }
        if `"`c'"' == `"$GR2MPL_PYRESOLVED"' & "$GR2MPL_PYMODE" == "shell" {
            sreturn local mode "shell"
            sreturn local python `"`c'"'
            sreturn local mplversion "$GR2MPL_MPLVERSION"
            exit
        }
        _g2m_trypy `"`c'"'
        local tried `"`tried' `"`c'"'"'
        if "`s(ok)'" == "1" {
            local v `s(v)'
            global GR2MPL_PYMODE "shell"
            global GR2MPL_PYRESOLVED `"`c'"'
            global GR2MPL_MPLVERSION "`v'"
            sreturn local mode "shell"
            sreturn local python `"`c'"'
            sreturn local mplversion "`v'"
            exit
        }
        di as err `"gr2mpl: `c' cannot import matplotlib"'
        di as err `"        fix: "`c'" -m pip install matplotlib"'
        exit 601
    }
    * Stata's own Python
    capture python: import matplotlib, numpy
    if !_rc {
        capture python: import matplotlib, sfi; sfi.Macro.setLocal("v", matplotlib.__version__)
        global GR2MPL_PYMODE "embedded"
        global GR2MPL_PYRESOLVED "embedded"
        global GR2MPL_MPLVERSION "`v'"
        sreturn local mode "embedded"
        sreturn local python "embedded"
        sreturn local mplversion "`v'"
        exit
    }
    local embexe
    capture python: import sys, sfi; sfi.Macro.setLocal("embexe", sys.executable)
    foreach c in python3 python {
        _g2m_trypy `"`c'"'
        if "`s(ok)'" == "1" {
            local v `s(v)'
            global GR2MPL_PYMODE "shell"
            global GR2MPL_PYRESOLVED "`c'"
            global GR2MPL_MPLVERSION "`v'"
            sreturn local mode "shell"
            sreturn local python "`c'"
            sreturn local mplversion "`v'"
            exit
        }
    }
    di as err "gr2mpl: no Python with matplotlib was found."
    di as err "  tried, in order:"
    if `"`embexe'"' != "" di as err `"    Stata's Python (`embexe')"'
    else di as err "    Stata's Python (none configured; see {help python})"
    di as err "    python3 and python on the system PATH"
    di as err "  fix one of these ways:"
    if `"`embexe'"' != "" di as err `"    "`embexe'" -m pip install matplotlib"'
    di as err "    python3 -m pip install matplotlib"
    di as err "    set python_exec /path/to/python   (one that has matplotlib)"
    di as err `"    global GR2MPL_PYTHON "/path/to/python"   or the python() option"'
    exit 601
end

program _g2m_trypy, sclass
    args cand
    sreturn local ok 0
    tempfile out
    capture shell "`cand'" -c "import matplotlib, numpy; print('MPLOK', matplotlib.__version__)" > "`out'" 2>&1
    capture confirm file "`out'"
    if _rc exit
    tempname fh
    capture file open `fh' using "`out'", read text
    if _rc exit
    file read `fh' line
    file close `fh'
    if strpos(`"`line'"', "MPLOK") == 1 {
        sreturn local ok 1
        sreturn local v = strtrim(subinstr(`"`line'"', "MPLOK", "", 1))
    }
end

program _g2m_doctor, rclass
    syntax [, python(string) font(string)]
    di as txt _n "gr2mpl doctor"
    di as txt "{hline 60}"
    capture findfile gr2mpl_render.py
    if _rc {
        di as err "  renderer    : gr2mpl_render.py NOT found on the adopath"
        exit 601
    }
    local render `"`r(fn)'"'
    di as txt "  renderer    : " as res `"`render'"'
    di as txt "  option      : " as res cond(`"`python'"' == "", "(none)", `"`python'"')
    di as txt "  \$GR2MPL_PYTHON: " as res cond(`"$GR2MPL_PYTHON"' == "", "(not set)", `"$GR2MPL_PYTHON"')
    capture noisily _g2m_python, python(`"`python'"')
    if _rc {
        di as txt "{hline 60}"
        exit _rc
    }
    local mode `s(mode)'
    local exe `"`s(python)'"'
    di as txt "  will use    : " as res cond("`mode'" == "embedded", "Stata's embedded Python (no shell)", `"`exe' (shell call)"')
    di as txt "  matplotlib  : " as res "`s(mplversion)'"
    if "`mode'" == "embedded" {
        capture noisily python script `"`render'"', args(--doctor `"`font'"')
    }
    else {
        tempfile out
        shell "`exe'" "`render'" --doctor "`font'" > "`out'" 2>&1
        capture noisily type "`out'"
    }
    di as txt "{hline 60}"
    return local pymode "`mode'"
    return local python `"`exe'"'
    return local mplversion "`s(mplversion)'"
end

* ---------------------------------------------------------------------------
* one panel = one twoway or bar-family graph object (a whole graph, a by()
* sub-graph, or a member of graph combine)
* ---------------------------------------------------------------------------
program _g2m_panel
    args fh g specdir role
    local fam `"``g'.graphfamily'"'
    if "``g'.classname'" == "piegraph_g" local fam pie
    file write `fh' "    {" _n
    _g2m_kv `fh' "family" `"`fam'"' 6
    _g2m_kv `fh' "role" "`role'" 6
    if "`role'" == "by" {
        _g2m_textarr `fh' "ptitle" "`g'.subtitle" 6
    }
    else if "`role'" == "combine" {
        _g2m_textarr `fh' "ptitle" "`g'.title" 6
        _g2m_textarr `fh' "psubtitle" "`g'.subtitle" 6
    }
    if "`fam'" == "twoway" {
        _g2m_twoway `fh' "`g'" "`specdir'"
    }
    else if "`fam'" == "bar" {
        _g2m_bar `fh' "`g'" "`specdir'"
    }
    file write `fh' `"      "end": 1"' _n "    }"
end

* ---------------------------------------------------------------------------
* twoway graphs
* ---------------------------------------------------------------------------
program _g2m_twoway
    args fh g specdir
    local pr `g'.plotregion1
    capture local npr = ``g'.n_plotregions'
    if _rc | "`npr'" == "" local npr 1

    * which plot region carries the second y axis, if any
    local ysc ``g'.y_scales'
    local ysc : subinstr local ysc `"""' "", all
    local pr2
    local np = ``g'.n_views'
    forvalues i = 1/`np' {
        local yax`i' : word `i' of `ysc'
        if "`yax`i''" == "" local yax`i' 1
        local preg`i' `pr'
        forvalues j = 1/`npr' {
            if "``g'.plotregion`j'.plot`i'.type.setting'" != "" local preg`i' `g'.plotregion`j'
        }
        if "`yax`i''" == "2" & "`pr2'" == "" local pr2 `preg`i''
    }

    foreach a in x y y2 {
        if "`a'" == "y2" {
            if "`pr2'" == "" continue
            local ax `g'.yaxis2
            local sc `pr2'.yscale
        }
        else {
            local ax `g'.`a'axis1
            local sc `pr'.`a'scale
        }
        file write `fh' `"  "`a'axis": {"' _n
        _g2m_textarr `fh' "title" "`ax'.title" 4
        _g2m_ticks `fh' "ticks" "`ax'"
        _g2m_pairs `fh' "`ax'" "format major.label_format" "grid style.draw_major_grid.setting" ///
            "draw draw_view.setting" "linecolor style.linestyle.color.setting"
        _g2m_pairs `fh' "`sc'" "reverse reverse.setting" "transform transform.setting" ///
            "min curmin" "max curmax" "datamin min" "datamax max"
        * xscale(noline) leaves the line style members unchanged; it is recorded
        * only as an edit in the graph's construction log
        local noline 0
        if "`a'" != "y2" {
            local nlog ``g'.__LOG.arrnels'
            if "`nlog'" == "" local nlog 0
            forvalues q = 1/`nlog' {
                local ll `"``g'.__LOG[`q']'"'
                if strpos(`"`ll'"', ".`a'axis1.style.editstyle") & strpos(`"`ll'"', "linestyle(none)") local noline 1
            }
        }
        file write `fh' `""noline": `noline', "'
        file write `fh' `""e": 1"' _n "  }," _n
    }

    * reference lines
    local nl ``pr'._xylines.arrnels'
    if "`nl'" == "" local nl 0
    file write `fh' `"  "reflines": ["' _n
    forvalues k = 1/`nl' {
        local o `pr'._xylines[`k']
        file write `fh' "    {"
        _g2m_pairs `fh' "`o'" "z z" "ord ord.setting" "color style.linestyle.color.setting" ///
            "lw style.linestyle.width.gmval" "pattern style.linestyle.pattern.setting"
        file write `fh' `""e": 1}`=cond(`k' < `nl', ",", "")'"' _n
    }
    file write `fh' "  ]," _n

    * text boxes placed with text()
    local nt ``g'.n_text'
    if "`nt'" == "" local nt 0
    file write `fh' `"  "textboxes": ["' _n
    local first 1
    forvalues k = 1/`nt' {
        local o `pr'.textbox`k'
        if "``o'.xpos.val'" == "" continue
        if !`first' file write `fh' "," _n
        local first 0
        file write `fh' "    {"
        _g2m_pairs `fh' "`o'" "x xpos.val" "y ypos.val" "color style.color.setting" ///
            "size style.size.gmval" "place style.box_alignment.setting" ///
            "horizontal style.horizontal.setting" "angle style.angle.setting" ///
            "orientation orientation.setting" "draw draw_view.setting" ///
            "drawbox style.drawbox.setting" "boxfill style.fillcolor.setting" ///
            "boxline style.linestyle.color.setting" "boxlw style.linestyle.width.gmval" ///
            "bml style.boxmargin.gleft.gmval" "bmr style.boxmargin.gright.gmval" ///
            "bmb style.boxmargin.gbottom.gmval" "bmt style.boxmargin.gtop.gmval" ///
            "ml style.margin.gleft.gmval" "mr style.margin.gright.gmval" ///
            "mb style.margin.gbottom.gmval" "mt style.margin.gtop.gmval"
        _g2m_textarr `fh' "text" "`o'" 0 nocomma
        file write `fh' "}"
    }
    file write `fh' _n "  ]," _n

    * objects added with gr_edit or the Graph Editor
    local nat ``pr'.added_text.arrnels'
    if "`nat'" == "" local nat 0
    file write `fh' `"  "added_text": ["' _n
    local first 1
    forvalues k = 1/`nat' {
        local o `pr'.added_text[`k']
        if "``o'.xpos.val'" == "" continue
        if !`first' file write `fh' "," _n
        local first 0
        file write `fh' "    {"
        _g2m_pairs `fh' "`o'" "x xpos.val" "y ypos.val" "color style.color.setting" ///
            "size style.size.gmval" "place style.box_alignment.setting" ///
            "horizontal style.horizontal.setting" "angle style.angle.setting" ///
            "orientation orientation.setting" "draw draw_view.setting" ///
            "drawbox style.drawbox.setting" "boxfill style.fillcolor.setting" ///
            "boxline style.linestyle.color.setting" "boxlw style.linestyle.width.gmval" ///
            "bml style.boxmargin.gleft.gmval" "bmr style.boxmargin.gright.gmval" ///
            "bmb style.boxmargin.gbottom.gmval" "bmt style.boxmargin.gtop.gmval" ///
            "ml style.margin.gleft.gmval" "mr style.margin.gright.gmval" ///
            "mb style.margin.gbottom.gmval" "mt style.margin.gtop.gmval"
        _g2m_textarr `fh' "text" "`o'" 0 nocomma
        file write `fh' "}"
    }
    file write `fh' _n "  ]," _n

    local nal ``pr'.added_lines.arrnels'
    if "`nal'" == "" local nal 0
    file write `fh' `"  "added_lines": ["' _n
    local first 1
    forvalues k = 1/`nal' {
        local o `pr'.added_lines[`k']
        if "``o'.x0'" == "" continue
        if !`first' file write `fh' "," _n
        local first 0
        file write `fh' "    {"
        _g2m_pairs `fh' "`o'" "x0 x0" "y0 y0" "x1 x1" "y1 y1" "color style.linestyle.color.setting" ///
            "lw style.linestyle.width.gmval" "pattern style.linestyle.pattern.setting" ///
            "head style.headpos.setting" "headsize style.headstyle.size.gmval" "draw draw_view.setting"
        file write `fh' `""e": 1}"'
    }
    file write `fh' _n "  ]," _n

    local nam ``pr'.added_markers.arrnels'
    if "`nam'" == "" local nam 0
    file write `fh' `"  "added_markers": ["' _n
    local first 1
    forvalues k = 1/`nam' {
        local o `pr'.added_markers[`k']
        if "``o'.x'" == "" continue
        if !`first' file write `fh' "," _n
        local first 0
        file write `fh' "    {"
        _g2m_pairs `fh' "`o'" "x x" "y y" "fill style.marker.fillcolor.setting" ///
            "line style.marker.linestyle.color.setting" "size style.marker.size.gmval" ///
            "symbol style.marker.symbol.setting" "mlwidth style.marker.linestyle.width.gmval" ///
            "draw draw_view.setting"
        file write `fh' `""e": 1}"'
    }
    file write `fh' _n "  ]," _n

    _g2m_legend `fh' "`g'"

    * plots
    file write `fh' `"  "plots": ["' _n
    forvalues i = 1/`np' {
        _g2m_plot `fh' "`preg`i''.plot`i'" `i' "`yax`i''" "`specdir'"
        if `i' < `np' file write `fh' ","
        file write `fh' _n
    }
    file write `fh' "  ]," _n
end

* graph matrix: an nvars x nvars grid of panels. Cell (i,j) is the plot region
* .plotregion1.plotregion<i>_<j>; the diagonal holds the variable titles.
program _g2m_matrix
    args fh g specdir
    local nv = ``g'.nvars'
    local m `g'.plotregion1
    file write `fh' `"  "rows": "`nv'", "cols": "`nv'","' _n
    file write `fh' `"  "panels": ["' _n
    forvalues i = 1/`nv' {
        forvalues j = 1/`nv' {
            file write `fh' "    {" _n
            local pr `m'.plotregion`i'_`j'
            if `i' == `j' {
                _g2m_kv `fh' "family" "diag" 6
                _g2m_textarr `fh' "ptitle" "`m'.titlegrid`i'.variable_title`i'" 6
            }
            else if "``pr'.plot1.type.setting'" == "" {
                _g2m_kv `fh' "family" "blank" 6
            }
            else {
                _g2m_kv `fh' "family" "twoway" 6
                _g2m_kv `fh' "role" "matrix" 6
                foreach a in x y {
                    local v = cond("`a'" == "x", `j', `i')
                    * ticks of variable v sit on whichever matrix axis was created for it
                    local ax `m'.xaxis`v'
                    if "``ax'.major.dlg_tickpos.arrnels'" == "" local ax `m'.yaxis`v'
                    local edge = cond("`a'" == "x", `i' == `nv', `j' == 1)
                    file write `fh' `"  "`a'axis": {"title": [],"' _n
                    _g2m_ticks `fh' "ticks" "`ax'"
                    _g2m_pairs `fh' "`pr'.`a'scale" "min curmin" "max curmax" "transform transform.setting"
                    file write `fh' `""grid": "no", "draw": "`=cond(`edge', "yes", "no")'"},"' _n
                }
                file write `fh' `"  "legend": {"draw": "no", "entries": []},"' _n
                file write `fh' `"  "plots": ["' _n
                _g2m_plot `fh' "`pr'.plot1" 1 "1" "`specdir'"
                file write `fh' _n "  ]," _n
            }
            file write `fh' `"      "end": 1"' _n "    }"
            if !(`i' == `nv' & `j' == `nv') file write `fh' ","
            file write `fh' _n
        }
    }
    file write `fh' "  ]," _n
end

* one plot record; the serset behind it is exported once per gr2mpl call
program _g2m_plot
    args fh p i yax specdir
        local type ``p'.type.setting'
        if "`type'" == "" local type unknown
        local sid ``p'.serset.id'
        if "`sid'" == "" local sid -1
        foreach v in xvar yvar y2var x2var lvar wvar {
            local `v'i 0
            local `v'lab ""
            local `v'fmt ""
            local idx ``p'.`v''
            if "`idx'" != "" & "`idx'" != "." {
                local `v'i `idx'
                local `v'lab `"``p'.serset.sers[`idx'].label'"'
                local `v'fmt ``p'.serset.sers[`idx'].format'
            }
        }
        file write `fh' `"    {"index": `i', "type": "`type'", "serset": `sid', "yaxis": "`yax'", "' _n
        file write `fh' `"     "xi": `xvari', "yi": `yvari', "y2i": `y2vari', "x2i": `x2vari', "labeli": `lvari', "weighti": `wvari',"' _n
        _g2m_esc `"`yvarlab'"'
        file write `fh' `"     "ylabel": "`s(esc)'", "xformat": "`xvarfmt'", "yformat": "`yvarfmt'", "' _n
        * value labels of the marker-label variable live in the class, not the serset
        file write `fh' `"     "labelmap": {"'
        if `lvari' > 0 {
            local lo ``p'.serset.sers[`lvari'].min'
            local hi ``p'.serset.sers[`lvari'].max'
            capture confirm integer number `lo'
            if !_rc capture confirm integer number `hi'
            if !_rc & (`hi' - `lo') <= 500 {
                local first 1
                forvalues v = `lo'/`hi' {
                    if `v' < 0 continue
                    local vl `"``p'.serset.sers[`lvari'].vlabs.__D_`v''"'
                    if `"`vl'"' == "" continue
                    _g2m_esc `"`vl'"'
                    if !`first' file write `fh' ", "
                    local first 0
                    file write `fh' `""`v'": "`s(esc)'""'
                }
            }
        }
        file write `fh' "}," _n
        file write `fh' "     "
        _g2m_pairs `fh' "`p'" "lcolor style.line.color.setting" "lwidth style.line.width.gmval" ///
            "lpattern style.line.pattern.setting" "msymbol style.marker.symbol.setting" ///
            "mfill style.marker.fillcolor.setting" "mline style.marker.linestyle.color.setting" ///
            "msize style.marker.size.gmval" "mlwidth style.marker.linestyle.width.gmval" ///
            "afill style.area.shadestyle.color.setting" "aline style.area.linestyle.color.setting" ///
            "alwidth style.area.linestyle.width.gmval" "connect style.connect.setting" ///
            "labpos style.label.position.setting" "labcolor style.label.textstyle.color.setting" ///
            "labsize style.label.textstyle.size.gmval" "draw draw_view.setting" ///
            "barsize bar_size" "base base" "drawnbase drawn_base" "dropto bar_drop_to.setting" ///
            "dropbase drop_base.setting"
        file write `fh' `""csv": "serset`sid'.csv"}"'
        if `sid' >= 0 & !`: list sid in global(G2M_DONE)' {
            global G2M_DONE $G2M_DONE `sid'
            preserve
            capture quietly {
                serset set `sid'
                serset use, clear
                _g2m_rawfmt
                export delimited using "`specdir'/serset`sid'.csv", replace nolabel
            }
            restore
        }
end

* ---------------------------------------------------------------------------
* graph bar / hbar / dot / box: the drawn objects are read directly
* ---------------------------------------------------------------------------
program _g2m_bar
    args fh g specdir
    local pr `g'.plotregion1
    file write `fh' "  "
    _g2m_pairs `fh' "`g'" "horizontal horizontal.setting" "dotplot dotplot.setting" ///
        "boxplot boxplot.setting" "stack stack.setting" "percentages percentages.setting"
    file write `fh' _n
    _g2m_textarr `fh' "scaletitle" "`g'.scaleaxis.title"
    _g2m_ticks `fh' "scaleaxis" "`g'.scaleaxis"
    _g2m_ticks `fh' "grpaxis" "`g'.grpaxis"
    _g2m_ticks `fh' "supaxis" "`g'.supaxis"
    file write `fh' "  "
    _g2m_pairs `fh' "`pr'" "smin yscale.curmin" "smax yscale.curmax" "xmin xscale.curmin" "xmax xscale.curmax"
    file write `fh' _n

    local nb ``pr'.bars.arrnels'
    if "`nb'" == "" local nb 0
    file write `fh' `"  "bars": ["' _n
    forvalues k = 1/`nb' {
        local b `pr'.bars[`k']
        file write `fh' "    {"
        _g2m_pairs `fh' "`b'" "x0 x0" "y0 y0" "x1 x1" "y1 y1" "color style.shadestyle.color.setting" ///
            "draw draw_view.setting"
        file write `fh' `""e": 1}`=cond(`k' < `nb', ",", "")'"' _n
    }
    file write `fh' "  ]," _n

    local nx ``pr'.boxes.arrnels'
    if "`nx'" == "" local nx 0
    file write `fh' `"  "boxes": ["' _n
    forvalues k = 1/`nx' {
        local b `pr'.boxes[`k']
        file write `fh' "    {"
        _g2m_pairs `fh' "`b'" "z z" "p25 p25" "p50 p50" "p75 p75" "adjl adjl" "adjh adjh" ///
            "width2 width2" "horizontal horizontal" "color rect.style.shadestyle.color.setting" ///
            "draw draw_view.setting"
        file write `fh' `""e": 1}`=cond(`k' < `nx', ",", "")'"' _n
    }
    file write `fh' "  ]," _n

    foreach arr in outsides points {
        local n ``pr'.`arr'.arrnels'
        if "`n'" == "" local n 0
        file write `fh' `"  "`arr'": ["' _n
        forvalues k = 1/`n' {
            local b `pr'.`arr'[`k']
            file write `fh' "    {"
            _g2m_pairs `fh' "`b'" "x x" "y y" "color style.marker.fillcolor.setting" ///
                "symbol style.marker.symbol.setting" "size style.marker.size.gmval" "draw draw_view.setting"
            file write `fh' `""e": 1}`=cond(`k' < `n', ",", "")'"' _n
        }
        file write `fh' "  ]," _n
    }

    local n ``pr'.barlabels.arrnels'
    if "`n'" == "" local n 0
    file write `fh' `"  "barlabels": ["' _n
    local first 1
    forvalues k = 1/`n' {
        local b `pr'.barlabels[`k']
        if "``b'.xpos.val'" == "" continue
        if !`first' file write `fh' "," _n
        local first 0
        file write `fh' "    {"
        _g2m_pairs `fh' "`b'" "x xpos.val" "y ypos.val" "place style.box_alignment.setting" ///
            "size style.size.gmval" "color style.color.setting" "draw draw_view.setting"
        _g2m_textarr `fh' "text" "`b'" 0 nocomma
        file write `fh' "}"
    }
    file write `fh' _n "  ]," _n

    * legend labels, with the colour of the matching bar style
    local ldraw ``g'.legend.draw_view.setting'
    local nk ``g'.legend.map.arrnels'
    if "`nk'" == "" local nk 0
    file write `fh' `"  "legend": {"draw": "`ldraw'", "entries": ["'
    forvalues k = 1/`nk' {
        local lab `"``g'.legend.plotregion1.label[`k'].text[1]'"'
        local c ``g'.barstyles[`k'].area.shadestyle.color.setting'
        local c : list retokenize c
        _g2m_esc `"`lab'"'
        if `k' > 1 file write `fh' ", "
        file write `fh' `"["`c'", "`s(esc)'"]"'
    }
    file write `fh' "]}," _n
end

* ---------------------------------------------------------------------------
* helpers
* ---------------------------------------------------------------------------
* legend: [plot index, label, label colour] per entry
program _g2m_legend
    args fh g
    local ldraw ``g'.legend.draw_view.setting'
    local nk ``g'.legend.map.arrnels'
    if "`nk'" == "" local nk 0
    local ltitle `"``g'.legend.subtitle.text[1]'"'
    if `"`ltitle'"' == "" local ltitle `"``g'.legend.title.text[1]'"'
    _g2m_esc `"`ltitle'"'
    file write `fh' `"  "legend": {"draw": "`ldraw'", "title": "`s(esc)'", "rows": "``g'.legend.style.rows.val'", "' ///
        `""cols": "``g'.legend.style.cols.val'", "position": "``g'.style.legend_position.setting'", "entries": ["'
    forvalues k = 1/`nk' {
        local m ``g'.legend.map[`k']'
        local lab `"``g'.legend.plotregion1.label[`k'].text[1]'"'
        local lcol ``g'.legend.plotregion1.label[`k'].style.color.setting'
        local lcol : list retokenize lcol
        _g2m_esc `"`lab'"'
        if `k' > 1 file write `fh' ", "
        file write `fh' `"["`m'", "`s(esc)'", "`lcol'"]"'
    }
    file write `fh' "]}," _n
end

* drawn tick positions and labels of an axis object
program _g2m_ticks
    args fh key ax
    local n ``ax'.major.dlg_tickpos.arrnels'
    if "`n'" == "" local n 0
    file write `fh' `"    "`key'": ["'
    local first 1
    forvalues k = 1/`n' {
        local pos ``ax'.major.dlg_tickpos[`k']'
        local lab `"``ax'.major.dlg_ticklabel[`k']'"'
        if "`pos'" == "" | "`pos'" == "." continue
        _g2m_esc `"`lab'"'
        if !`first' file write `fh' ", "
        local first 0
        file write `fh' `"["`pos'", "`s(esc)'"]"'
    }
    file write `fh' "]," _n
end

* write `"key": "value", ' for each "key member.path" pair of an object;
* a member that does not exist expands to nothing and is written as ""
program _g2m_pairs
    gettoken fh 0 : 0
    gettoken obj 0 : 0
    while `"`0'"' != "" {
        gettoken pair 0 : 0
        gettoken key path : pair
        local path = strtrim("`path'")
        capture local val ``obj'.`path''
        if _rc local val ""
        local val : list retokenize val
        _g2m_esc `"`val'"'
        file write `fh' `""`key'": "`s(esc)'", "'
    }
end

program _g2m_rawfmt
    capture ds, has(type numeric)
    if _rc exit
    foreach v in `r(varlist)' {
        format `v' %18.0g
    }
end

program _g2m_esc, sclass
    args txt
    mata: st_local("out", _g2m_escape(st_local("txt")))
    sreturn local esc `"`out'"'
end

program _g2m_kv
    args fh key val indent
    if "`indent'" == "" local indent 2
    _g2m_esc `"`val'"'
    file write `fh' _col(`=`indent'+1') `""`key'": "`s(esc)'","' _n
end

* write a class text array as a JSON list of lines
program _g2m_textarr
    args fh key obj indent nocomma
    if "`indent'" == "" local indent 2
    local n ``obj'.text.arrnels'
    if "`n'" == "" local n 0
    file write `fh' _col(`=`indent'+1') `""`key'": ["'
    forvalues k = 1/`n' {
        capture local t `"``obj'.text[`k']'"'
        if _rc local t ""
        _g2m_esc `"`t'"'
        if `k' > 1 file write `fh' ", "
        file write `fh' `""`s(esc)'""'
    }
    if "`nocomma'" == "" file write `fh' "]," _n
    else file write `fh' "]"
end

mata:
string scalar _g2m_escape(string scalar s)
{
    string scalar t

    t = s
    /* strip compound quotes that class arrays sometimes keep */
    if (substr(t, 1, 2) == "`" + char(34) & substr(t, -2, 2) == char(34) + "'") {
        t = substr(t, 3, strlen(t) - 4)
    }
    t = subinstr(t, "\", "\\")
    t = subinstr(t, char(34), "\" + char(34))
    t = subinstr(t, char(9), " ")
    t = subinstr(t, char(10), "\n")
    t = subinstr(t, char(13), "")
    return(t)
}
end
