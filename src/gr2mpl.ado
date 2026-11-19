*! gr2mpl 0.6.0  18nov2026  redraw a Stata graph held in memory with matplotlib
*! Walks the graph object (not the syntax), writes a JSON spec + serset CSVs,
*! then runs gr2mpl_render.py (embedded Python if it has matplotlib, else a shell
*! call). Writes a PNG, PDF, SVG or JPG image. Needs matplotlib 3.6 or later.
*! Families: twoway, graph bar/hbar/dot/box, graph matrix, by(), combine.
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
    if `width' < 0 {
        di as err "gr2mpl: width() must be a positive integer (0 = default)"
        exit 198
    }
    if `dpi' <= 0 {
        di as err "gr2mpl: dpi() must be greater than 0"
        exit 198
    }
    foreach o in lwscale msscale {
        if ``o'' <= 0 | ``o'' >= . {
            di as err "gr2mpl: `o'() must be a number greater than 0"
            exit 198
        }
        * JSON needs a leading zero (.5 is not a valid number)
        local `o' = strtrim(strofreal(``o'', "%12.0g"))
        if substr("``o''", 1, 1) == "." local `o' "0``o''"
    }
    local palette = strlower(strtrim(`"`palette'"'))
    if !inlist(`"`palette'"', "", "house") {
        di as err `"gr2mpl: palette() must be house (got `palette')"'
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
    _g2m_family `g'
    local fam `s(fam)'
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
    local mplv `s(mplversion)'
    _g2m_mplok "`mplv'"
    if "`s(ok)'" == "0" {
        local who = cond("`pymode'" == "embedded", "Stata's Python", `"`pyexe'"')
        di as err `"gr2mpl: needs matplotlib 3.6 or later; `who' has matplotlib `mplv'"'
        if "`pymode'" == "embedded" di as err "        fix: python -m pip install --upgrade matplotlib (for Stata's Python)"
        else di as err `"        fix: "`pyexe'" -m pip install --upgrade matplotlib"'
        exit 601
    }

    * ---- output locations --------------------------------------------------
    * saving(filename [, replace]), as in graph's own saving()
    if `"`saving'"' != "" {
        local keeprep `replace'
        local 0 `"`saving'"'
        capture syntax anything(name=saving equalok) [, REPLACE]
        if _rc {
            di as err `"gr2mpl: saving() takes a file name, optionally followed by , replace"'
            exit 198
        }
        local saving `saving'
        if "`replace'" == "" local replace `keeprep'
    }
    if `"`saving'"' == "" local saving "`name'_mpl.png"
    * saving() that names a folder ("out/") gets the default file name in it
    local sbase = ustrregexra(`"`saving'"', "^.*[/\\\\]", "")
    if `"`sbase'"' == "" local saving `"`saving'`name'_mpl.png"'
    else if usubstr(`"`sbase'"', 1, 1) == "." {
        di as err `"gr2mpl: saving() needs a file name (got `saving')"'
        exit 198
    }
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
    mata: st_local("predir", strofreal(direxists(st_local("specdir"))))
    capture mkdir "`specdir'"
    mata: st_local("dok", strofreal(direxists(st_local("specdir"))))
    if "`dok'" != "1" {
        di as err `"gr2mpl: could not create the spec folder `specdir'"'
        exit 603
    }
    local spec "`specdir'/spec.json"
    local outtmp "`specdir'/render_out`sfx'"
    foreach f in skipped.txt notes.txt render_info.txt render.log {
        capture erase "`specdir'/`f'"
    }
    capture erase "`outtmp'"
    capture erase "`spec'"

    tempname fh
    global G2M_DONE
    capture noisily {
        file open `fh' using "`spec'", write text
        file write `fh' "{" _n

        * ---- graph-level ---------------------------------------------------
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
        * aspectratio(): plot-region height over width (0 when not set)
        capture local asp = ``g'.style.aspect_ratio.val'
        if _rc | "`asp'" == "" | "`asp'" == "." local asp 0
        local asp = strtrim(strofreal(`asp', "%12.0g"))
        if substr("`asp'", 1, 1) == "." local asp "0`asp'"
        file write `fh' `"  "aspect": `asp',"' _n
        _g2m_kv `fh' "specdir" `"`specdir'"'
        file write `fh' `"  "lwscale": `lwscale', "msscale": `msscale',"' _n
        file write `fh' `"  "endlabels": `=("`endlabels'"!="")', "nolegend": `=("`legend'"!="")', "' ///
            `""nogrid": `=("`grid'"!="")', "nohalo": `=("`halo'"!="")', "noticks": `=("`ticks'"!="")', "' ///
            `""roundbox": `=("`roundbox'"!="")',"' _n

        foreach t in title subtitle note caption {
            _g2m_textarr `fh' "`t'" "`g'.`t'"
        }
        _g2m_colors `fh' "`g'" "`fam'"
        * text sizes, in Stata's relative units (percent of the shorter graph side)
        file write `fh' "  "
        _g2m_pairs `fh' "`g'" "title_size title.style.size.gmval" ///
            "subtitle_size subtitle.style.size.gmval" "note_size note.style.size.gmval" ///
            "caption_size caption.style.size.gmval"
        file write `fh' _n

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
            * a by() legend numbers its keys by the plot regions of the panels
            local lrg
            if "`fam'" == "by" local lrg `g'.graphs[1]
            _g2m_legend `fh' "`g'" "`lrg'"
            * by() and graph combine shrink the text and markers of their panels
            * (iscale()); the multiplier is stored on the grid that holds them
            local gm ``g'.plotregion1.gmetric_mult'
            if "`gm'" == "" | "`gm'" == "." local gm 1
            file write `fh' `"  "panels": ["' _n
            forvalues k = 1/`np' {
                _g2m_panel `fh' "`g'.graphs[`k']" "`specdir'" "`fam'" "`gm'"
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
        if _rc {
            di as err "gr2mpl: rendering failed"
            if "`pymode'" != "embedded" capture noisily type "`specdir'/render.log"
            exit 698
        }
        capture copy `"`outtmp'"' `"`saving'"', replace
        if _rc {
            di as err `"gr2mpl: could not write `saving'"'
            exit 603
        }
    }
    local rc = _rc
    capture file close `fh'
    global G2M_DONE
    if `rc' {
        if "`keepspec'" != "" di as txt "(spec kept in `specdir')"
        else {
            _g2m_cleanup "`specdir'" "`predir'"
            if `rc' == 698 di as txt "        (add the keepspec option to keep the spec folder for checking)"
        }
        exit `rc'
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
    if "`keepspec'" != "" {
        di as txt "(spec kept in " as res `"`specdir'"' as txt ")"
        return local specdir `"`specdir'"'
    }
    else _g2m_cleanup "`specdir'" "`predir'"
    return local unsupported `"`unsupported'"'
    return local pymode "`pymode'"
    return local python `"`pyexe'"'
    return local filename `"`saving'"'
end

* remove the files gr2mpl wrote into the spec folder, and the folder itself when
* gr2mpl created it (a folder that already existed is left in place)
program _g2m_cleanup
    args specdir predir
    foreach f in spec.json render.log skipped.txt notes.txt render_info.txt ///
        render_out.png render_out.pdf render_out.svg render_out.jpg render_out.jpeg {
        capture erase "`specdir'/`f'"
    }
    local fl : dir "`specdir'" files "serset*.csv"
    foreach f of local fl {
        capture erase "`specdir'/`f'"
    }
    if "`predir'" != "1" capture rmdir "`specdir'"
end

* ---------------------------------------------------------------------------
* graph family, read from .classname. .graphfamily is not reliable: once a by()
* graph has been put in a graph combine, Stata reports "combine" as the
* .graphfamily of every later by() graph in the session (.classname stays
* bygraph_g). .graphfamily is used only for a class this list does not name.
* ---------------------------------------------------------------------------
program _g2m_family, sclass
    args g
    local cls `"``g'.classname'"'
    local fam
    if "`cls'" == "twowaygraph_g" local fam twoway
    else if "`cls'" == "bygraph_g" local fam by
    else if "`cls'" == "combinegraph_g" local fam combine
    else if "`cls'" == "matrixgraph_g" local fam matrix
    else if "`cls'" == "piegraph_g" local fam pie
    else if inlist("`cls'", "bargraph_g", "hbargraph_g", "dotchartgraph_g", "boxgraph_g") local fam bar
    else local fam `"``g'.graphfamily'"'
    sreturn local fam `"`fam'"'
end

* ---------------------------------------------------------------------------
* Python discovery
*   1 python() option  2 $GR2MPL_PYTHON  3 Stata's embedded Python
*   4 python3, then python, on PATH.  In 3 and 4 a Python whose matplotlib is
*   older than 3.6 is passed over for the next one. The working choice is
*   cached in $GR2MPL_PYRESOLVED.
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
    * an explicit choice is checked on its own, with no loop (a bare exit
    * inside a loop does not leave the program)
    local c `"`python'"'
    if `"`c'"' == "" local c `"$GR2MPL_PYTHON"'
    * python("/path with spaces/python") keeps its quotes; drop them
    if usubstr(`"`c'"', 1, 1) == char(34) & usubstr(`"`c'"', -1, 1) == char(34) ///
        & ustrlen(`"`c'"') > 1 {
        local c = usubstr(`"`c'"', 2, ustrlen(`"`c'"') - 2)
    }
    if `"`c'"' != "" {
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
        if "`s(ok)'" == "1" {
            local v `s(v)'
            * a Python whose matplotlib is too old is reported, not remembered
            _g2m_mplok "`v'"
            if "`s(ok)'" != "0" {
                global GR2MPL_PYMODE "shell"
                global GR2MPL_PYRESOLVED `"`c'"'
                global GR2MPL_MPLVERSION "`v'"
            }
            sreturn local mode "shell"
            sreturn local python `"`c'"'
            sreturn local mplversion "`v'"
            exit
        }
        di as err `"gr2mpl: `c' cannot import matplotlib"'
        di as err `"        fix: "`c'" -m pip install matplotlib"'
        exit 601
    }
    * the default search: Stata's own Python, then python3 and python on the
    * PATH ($GR2MPL_SEARCH can replace this list; "embedded" names Stata's
    * Python). A candidate whose matplotlib is older than 3.6 is passed over;
    * gr2mpl reports it (error 601) only when no candidate is new enough.
    local search `"$GR2MPL_SEARCH"'
    if `"`search'"' == "" local search embedded python3 python
    local embexe
    capture python: import sys, sfi; sfi.Macro.setLocal("embexe", sys.executable)
    local oldmode
    foreach c of local search {
        local v
        local found 0
        if `"`c'"' == "embedded" {
            capture python: import matplotlib, numpy
            if !_rc {
                capture python: import matplotlib, sfi; sfi.Macro.setLocal("v", matplotlib.__version__)
                local found 1
            }
            local mode embedded
        }
        else {
            _g2m_trypy `"`c'"'
            if "`s(ok)'" == "1" {
                local v `s(v)'
                local found 1
            }
            local mode shell
        }
        if !`found' continue
        local who = cond("`mode'" == "embedded", "Stata's Python", `"`c'"')
        _g2m_mplok "`v'"
        if "`s(ok)'" == "0" {
            di as txt `"(gr2mpl: `who' has matplotlib `v'; 3.6 or later is needed, so it is passed over)"'
            if "`oldmode'" == "" {
                local oldmode `mode'
                local oldpy `"`c'"'
                local oldv `v'
            }
            continue
        }
        * the first candidate that is new enough is used; the search stops
        * here (a bare exit inside the loop would not leave the program)
        local usemode `mode'
        local usepy `"`c'"'
        local usev `v'
        continue, break
    }
    if "`usemode'" != "" {
        global GR2MPL_PYMODE "`usemode'"
        global GR2MPL_PYRESOLVED `"`usepy'"'
        global GR2MPL_MPLVERSION "`usev'"
        sreturn local mode "`usemode'"
        sreturn local python `"`usepy'"'
        sreturn local mplversion "`usev'"
        exit
    }
    * none is new enough: report the first one found, which the caller stops on
    if "`oldmode'" != "" {
        sreturn local mode "`oldmode'"
        sreturn local python `"`oldpy'"'
        sreturn local mplversion "`oldv'"
        exit
    }
    di as err "gr2mpl: no Python with matplotlib was found."
    di as err "  tried, in order:"
    if `"$GR2MPL_SEARCH"' != "" di as err `"    $GR2MPL_SEARCH   (from {c 36}GR2MPL_SEARCH)"'
    else {
        if `"`embexe'"' != "" di as err `"    Stata's Python (`embexe')"'
        else di as err "    Stata's Python (none configured; see {help python})"
        di as err "    python3 and python on the system PATH"
    }
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

* matplotlib 3.6 or later (Axes.legend(alignment=) arrived in 3.6). s(ok) is 1 when
* the version is new enough, 0 when it is older, and empty when it cannot be read.
program _g2m_mplok, sclass
    args v
    sreturn local ok ""
    if !ustrregexm(`"`v'"', "^([0-9]+)\.([0-9]+)") exit
    local maj = real(ustrregexs(1))
    local min = real(ustrregexs(2))
    sreturn local ok = cond(`maj' > 3 | (`maj' == 3 & `min' >= 6), "1", "0")
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
    local mplv `s(mplversion)'
    _g2m_mplok "`mplv'"
    local mplok `s(ok)'
    local need = cond("`mplok'" == "1", "(3.6 or later needed: OK)", ///
        cond("`mplok'" == "0", "(TOO OLD: gr2mpl needs 3.6 or later)", "(3.6 or later needed)"))
    di as txt "  matplotlib  : " as res "`mplv' " as txt "`need'"
    if "`mplok'" == "0" {
        if "`mode'" == "embedded" di as err "  fix         : python -m pip install --upgrade matplotlib (for Stata's Python)"
        else di as err `"  fix         : "`exe'" -m pip install --upgrade matplotlib"'
    }
    if "`mode'" == "embedded" {
        * --doctor-ado: the renderer leaves out the matplotlib line printed above
        capture noisily python script `"`render'"', args(--doctor-ado `"`font'"')
    }
    else {
        tempfile out
        shell "`exe'" "`render'" --doctor-ado "`font'" > "`out'" 2>&1
        capture noisily type "`out'"
    }
    di as txt "{hline 60}"
    return local pymode "`mode'"
    return local python `"`exe'"'
    return local mplversion "`mplv'"
    if inlist("`mplok'", "0", "1") return scalar mplok = `mplok'
    else return scalar mplok = .
end

* ---------------------------------------------------------------------------
* one panel = one twoway or bar-family graph object (a whole graph, a by()
* sub-graph, or a member of graph combine)
* ---------------------------------------------------------------------------
program _g2m_panel
    args fh g specdir role gm
    if "`gm'" == "" local gm 1
    _g2m_family `g'
    local fam `s(fam)'
    file write `fh' "    {" _n
    _g2m_kv `fh' "family" `"`fam'"' 6
    _g2m_kv `fh' "role" "`role'" 6
    _g2m_kv `fh' "classname" "``g'.classname'" 6
    _g2m_kv `fh' "gmult" "`gm'" 6
    if "`role'" == "by" {
        _g2m_textarr `fh' "ptitle" "`g'.subtitle" 6
        file write `fh' "      "
        _g2m_pairs `fh' "`g'" "ptitle_size subtitle.style.size.gmval"
        file write `fh' _n
    }
    else if "`role'" == "combine" {
        _g2m_textarr `fh' "ptitle" "`g'.title" 6
        _g2m_textarr `fh' "psubtitle" "`g'.subtitle" 6
        _g2m_textarr `fh' "pnote" "`g'.note" 6
        _g2m_textarr `fh' "pcaption" "`g'.caption" 6
        file write `fh' "      "
        _g2m_pairs `fh' "`g'" "ptitle_size title.style.size.gmval" ///
            "psubtitle_size subtitle.style.size.gmval" "pnote_size note.style.size.gmval"
        file write `fh' _n
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

    * .y_scales and .x_scales hold one quoted entry per plot region (not per
    * plot). An entry lists every axis that shares the region's scale: yaxis(1 2)
    * gives the single entry "2 1". A plot's axes are those of the region that
    * holds it; a region that lists axis 1 is drawn on axis 1.
    local ysc `"``g'.y_scales'"'
    local xsc `"``g'.x_scales'"'
    local j 0
    foreach e of local ysc {
        local ++j
        local yl`j' `e'
    }
    local j 0
    foreach e of local xsc {
        local ++j
        local xl`j' `e'
    }
    forvalues j = 1/`npr' {
        if "`yl`j''" == "" local yl`j' 1
        if "`xl`j''" == "" local xl`j' 1
        local ry`j' : word 1 of `yl`j''
        local rx`j' : word 1 of `xl`j''
        local in1 : list posof "1" in yl`j'
        if `in1' local ry`j' 1
        local in1 : list posof "1" in xl`j'
        if `in1' local rx`j' 1
        local h2`j' : list posof "2" in yl`j'
    }
    * the main axes are those of the first region on y axis 1 and x axis 1. A
    * graph whose only y axis is axis 2 (all plots on yaxis(2)) uses that axis as
    * its main y axis. Plot 1 may sit on yaxis(2), so .plotregion1 is not always
    * the main region.
    local mainj 0
    forvalues j = 1/`npr' {
        if "`ry`j''" == "1" & "`rx`j''" == "1" & `mainj' == 0 local mainj `j'
    }
    local ymain 1
    if `mainj' == 0 {
        forvalues j = 1/`npr' {
            if "`rx`j''" == "1" & `mainj' == 0 {
                local mainj `j'
                local ymain `ry`j''
            }
        }
    }
    if `mainj' == 0 local mainj 1
    local prm `g'.plotregion`mainj'
    * the second y axis takes its scale from a region of its own; when it only
    * shares a region with axis 1 (yaxis(1 2)), from that region
    local pr2
    local y2shared 0
    if "`ymain'" == "1" {
        forvalues j = 1/`npr' {
            if `h2`j'' & "`ry`j''" == "2" & "`rx`j''" == "1" & "`pr2'" == "" local pr2 `g'.plotregion`j'
        }
        forvalues j = 1/`npr' {
            if `h2`j'' & "`rx`j''" == "1" & "`pr2'" == "" {
                local pr2 `g'.plotregion`j'
                local y2shared 1
            }
        }
    }
    local np = ``g'.n_views'
    forvalues i = 1/`np' {
        local preg`i' `pr'
        local rj 1
        forvalues j = 1/`npr' {
            if "``g'.plotregion`j'.plot`i'.type.setting'" != "" {
                local preg`i' `g'.plotregion`j'
                local rj `j'
                continue, break
            }
        }
        local yax`i' `ry`rj''
        local xax`i' `rx`rj''
    }
    * objects added with gr_edit (gpolish) live in .plotregion1, in its coordinates
    file write `fh' `"  "added_yaxis": "`ry1'", "added_xaxis": "`rx1'","' _n

    foreach a in x y y2 {
        if "`a'" == "y2" {
            if "`pr2'" == "" continue
            local ax `g'.yaxis2
            local sc `pr2'.yscale
            local rg `pr2'
        }
        else if "`a'" == "y" {
            local ax `g'.yaxis`ymain'
            local sc `prm'.yscale
            local rg `prm'
        }
        else {
            local ax `g'.xaxis1
            local sc `prm'.xscale
            local rg `prm'
        }
        file write `fh' `"  "`a'axis": {"' _n
        _g2m_textarr `fh' "title" "`ax'.title" 4
        _g2m_ticks `fh' "ticks" "`ax'" extra
        _g2m_pairs `fh' "`ax'" "format major.label_format" "grid style.draw_major_grid.setting" ///
            "draw draw_view.setting" "linecolor style.linestyle.color.setting" ///
            "tsize title.style.size.gmval" "ticksize style.majorstyle.tickstyle.textstyle.size.gmval" ///
            "tickangle style.majorstyle.tickangle.setting" "position position.setting"
        _g2m_pairs `fh' "`sc'" "reverse reverse.setting" "transform transform.setting" ///
            "min curmin" "max curmax" "datamin min" "datamax max"
        * the plot-region margin on the two screen sides of this axis (left/right for
        * x, bottom/top for y): the space between the axis ends and the data range
        if "`a'" == "x" _g2m_pairs `fh' "`rg'" "mlo style.margin.gleft.gmval" "mhi style.margin.gright.gmval"
        else _g2m_pairs `fh' "`rg'" "mlo style.margin.gbottom.gmval" "mhi style.margin.gtop.gmval"
        * xscale(noline) leaves the line style members unchanged; it is recorded
        * only as an edit in the graph's construction log
        local noline 0
        if "`a'" != "y2" {
            local an = cond("`a'" == "y", "`ymain'", "1")
            local nlog ``g'.__LOG.arrnels'
            if "`nlog'" == "" local nlog 0
            forvalues q = 1/`nlog' {
                local ll `"``g'.__LOG[`q']'"'
                if strpos(`"`ll'"', ".`a'axis`an'.style.editstyle") & strpos(`"`ll'"', "linestyle(none)") local noline 1
            }
        }
        file write `fh' `""noline": `noline', "'
        * yaxis(1 2): the second axis repeats the scale of axis 1, with no plot of its own
        if "`a'" == "y2" file write `fh' `""shared": `y2shared', "'
        file write `fh' `""e": 1"' _n "  }," _n
    }

    * reference lines, from every plot region (yline(, axis(2)) is stored in the
    * region of the second y axis)
    file write `fh' `"  "reflines": ["' _n
    local first 1
    forvalues j = 1/`npr' {
        local nl ``g'.plotregion`j'._xylines.arrnels'
        if "`nl'" == "" local nl 0
        forvalues k = 1/`nl' {
            local o `g'.plotregion`j'._xylines[`k']
            if !`first' file write `fh' "," _n
            local first 0
            file write `fh' `"    {"yaxis": "`ry`j''", "xaxis": "`rx`j''", "'
            _g2m_pairs `fh' "`o'" "z z" "ord ord.setting" "color style.linestyle.color.setting" ///
                "lw style.linestyle.width.gmval" "pattern style.linestyle.pattern.setting"
            file write `fh' `""e": 1}"'
        }
    }
    file write `fh' _n "  ]," _n

    * text boxes placed with text(); text(, yaxis(2)) is stored in another region
    local nt ``g'.n_text'
    if "`nt'" == "" local nt 0
    * a member of graph combine reports .n_text as 0 although its plot regions
    * still hold textbox1, textbox2, ...; count those directly
    local more 1
    while `more' {
        local k = `nt' + 1
        local more 0
        forvalues j = 1/`npr' {
            if "``g'.plotregion`j'.textbox`k'.xpos.val'" != "" local more 1
        }
        if `more' local nt `k'
        if `nt' >= 1000 local more 0
    }
    file write `fh' `"  "textboxes": ["' _n
    local first 1
    forvalues k = 1/`nt' {
        local o
        forvalues j = 1/`npr' {
            if "``g'.plotregion`j'.textbox`k'.xpos.val'" != "" {
                local o `g'.plotregion`j'.textbox`k'
                local tj `j'
                continue, break
            }
        }
        if "`o'" == "" continue
        if !`first' file write `fh' "," _n
        local first 0
        file write `fh' `"    {"yaxis": "`ry`tj''", "xaxis": "`rx`tj''", "'

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
        _g2m_plot `fh' "`preg`i''.plot`i'" `i' "`yax`i''" "`specdir'" "`xax`i''"
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
    * graph matrix shrinks text and markers with the number of variables
    local gm ``m'.gmetric_mult'
    if "`gm'" == "" | "`gm'" == "." local gm 1
    file write `fh' `"  "rows": "`nv'", "cols": "`nv'","' _n
    file write `fh' `"  "panels": ["' _n
    forvalues i = 1/`nv' {
        forvalues j = 1/`nv' {
            file write `fh' "    {" _n
            _g2m_kv `fh' "gmult" "`gm'" 6
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
                _g2m_plot `fh' "`pr'.plot1" 1 "1" "`specdir'" "1"
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
    args fh p i yax specdir xax
        if "`xax'" == "" local xax 1
        local type ``p'.type.setting'
        if "`type'" == "" local type unknown
        local sid ``p'.serset.id'
        if "`sid'" == "" local sid -1
        foreach v in xvar yvar y2var x2var lvar wvar pvar {
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
        file write `fh' `"    {"index": `i', "type": "`type'", "serset": `sid', "yaxis": "`yax'", "xaxis": "`xax'", "' _n
        file write `fh' `"     "xi": `xvari', "yi": `yvari', "y2i": `y2vari', "x2i": `x2vari', "labeli": `lvari', "weighti": `wvari', "posi": `pvari',"' _n
        _g2m_esc `"`yvarlab'"'
        file write `fh' `"     "ylabel": "`s(esc)'", "xformat": "`xvarfmt'", "yformat": "`yvarfmt'", "labelvarfmt": "`lvarfmt'", "' _n
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
            "labfmt style.label.format" "labangle style.label.textstyle.angle.setting" ///
            "cmissing style.connect_missings.setting" ///
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
    file write `fh' "  "
    _g2m_pairs `fh' "`g'" "stitle_size scaleaxis.title.style.size.gmval" ///
        "stick_size scaleaxis.style.majorstyle.tickstyle.textstyle.size.gmval" ///
        "gtick_size grpaxis.style.majorstyle.tickstyle.textstyle.size.gmval" ///
        "gtickangle grpaxis.style.majorstyle.tickangle.setting" ///
        "stickangle scaleaxis.style.majorstyle.tickangle.setting"
    file write `fh' _n
    _g2m_ticks `fh' "scaleaxis" "`g'.scaleaxis" extra
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
    local lsize ``g'.legend.plotregion1.label[1].style.size.gmval'
    file write `fh' `"  "legend": {"draw": "`ldraw'", "size": "`lsize'", "rows": "``g'.legend.style.rows.val'", "cols": "``g'.legend.style.cols.val'", "colfirst": "``g'.legend.style.col_first.setting'", "entries": ["'
    forvalues k = 1/`nk' {
        local lab `"``g'.legend.plotregion1.label[`k'].text[1]'"'
        local c ``g'.barstyles[`k'].area.shadestyle.color.setting'
        local c : list retokenize c
        * graph dot: the marker style of series k, for its legend key
        local mc ``g'.barstyles[`k'].marker.fillcolor.setting'
        local mc : list retokenize mc
        local ms ``g'.barstyles[`k'].marker.symbol.setting'
        local mz ``g'.barstyles[`k'].marker.size.gmval'
        _g2m_esc `"`lab'"'
        if `k' > 1 file write `fh' ", "
        file write `fh' `"["`c'", "`s(esc)'", "`mc'", "`ms'", "`mz'"]"'
    }
    file write `fh' "]}," _n
end

* ---------------------------------------------------------------------------
* helpers
* ---------------------------------------------------------------------------
* legend: [plot index, label, label colour] per entry
* Stata numbers the plots in its legend map region by region: the plots of
* .plotregion1 first, then those of .plotregion2. s(rord) lists the plot numbers
* in that order (empty when it is 1, 2, 3, ...), so map entry k is plot
* word k of s(rord).
program _g2m_rorder, sclass
    args g
    _g2m_family `g'
    local fam `s(fam)'
    sreturn local rord ""
    if "`fam'" != "twoway" exit
    capture local npr = ``g'.n_plotregions'
    if _rc | "`npr'" == "" exit
    if `npr' < 2 exit
    local np = ``g'.n_views'
    if "`np'" == "" exit
    local rord
    local same 1
    local n 0
    forvalues j = 1/`npr' {
        forvalues i = 1/`np' {
            if "``g'.plotregion`j'.plot`i'.type.setting'" != "" {
                local ++n
                local rord `rord' `i'
                if `i' != `n' local same 0
            }
        }
    }
    if !`same' sreturn local rord "`rord'"
end

program _g2m_legend
    args fh g rg
    * rg: the graph whose plot regions number the legend map (a by() graph's
    * first panel); by default the graph itself
    if "`rg'" == "" local rg `g'
    _g2m_rorder `rg'
    local rord `s(rord)'
    local ldraw ``g'.legend.draw_view.setting'
    local nk ``g'.legend.map.arrnels'
    if "`nk'" == "" local nk 0
    local ltitle `"``g'.legend.subtitle.text[1]'"'
    if `"`ltitle'"' == "" local ltitle `"``g'.legend.title.text[1]'"'
    _g2m_esc `"`ltitle'"'
    local lsize ``g'.legend.plotregion1.label[1].style.size.gmval'
    file write `fh' `"  "legend": {"draw": "`ldraw'", "title": "`s(esc)'", "size": "`lsize'", "rows": "``g'.legend.style.rows.val'", "' ///
        `""cols": "``g'.legend.style.cols.val'", "colfirst": "``g'.legend.style.col_first.setting'", "position": "``g'.style.legend_position.setting'", "entries": ["'
    forvalues k = 1/`nk' {
        local m ``g'.legend.map[`k']'
        if "`rord'" != "" & real("`m'") >= 1 & real("`m'") < . {
            local mm : word `m' of `rord'
            if "`mm'" != "" local m `mm'
        }
        local lab `"``g'.legend.plotregion1.label[`k'].text[1]'"'
        local lcol ``g'.legend.plotregion1.label[`k'].style.color.setting'
        if `nk' == 1 & `"`lab'"' == "" {
            * a one-key legend holds a single label object, not an array
            local lab `"``g'.legend.plotregion1.label.text[1]'"'
            local lcol ``g'.legend.plotregion1.label.style.color.setting'
        }
        local lcol : list retokenize lcol
        _g2m_esc `"`lab'"'
        if `k' > 1 file write `fh' ", "
        file write `fh' `"["`m'", "`s(esc)'", "`lcol'"]"'
    }
    file write `fh' "]}," _n
end

* drawn tick positions and labels of an axis object
program _g2m_ticks
    args fh key ax extra
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
    file write `fh' "],"
    if "`extra'" != "" {
        * xlabel(none): no tick list, no rule and not the default ticks
        local none 0
        if "``ax'.major.ticks.arrnels'" == "0" & "``ax'.major._default'" == "0" ///
            & "``ax'.major.use_rule.setting'" != "yes" local none 1
        file write `fh' `" "`key'_none": `none', "`key'_minor": ["'
        * xmlabel()/ymlabel() ticks sit in the labelled minor tickset
        local n ``ax'.minor.dlg_tickpos.arrnels'
        if "`n'" == "" local n 0
        local first 1
        forvalues k = 1/`n' {
            local pos ``ax'.minor.dlg_tickpos[`k']'
            local lab `"``ax'.minor.dlg_ticklabel[`k']'"'
            if "`pos'" == "" | "`pos'" == "." continue
            _g2m_esc `"`lab'"'
            if !`first' file write `fh' ", "
            local first 0
            file write `fh' `"["`pos'", "`s(esc)'"]"'
        }
        file write `fh' "],"
    }
    file write `fh' _n
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
        * color(none) reads back as black; its style name says it is none
        * (also marker fillcolor, whose path ends in fillcolor.setting)
        if substr("`path'", -13, .) == "color.setting" {
            local cpath = substr("`path'", 1, strlen("`path'")-8)
            local snm
            capture local snm ``obj'.`cpath'.snm'
            if !_rc & "`snm'" == "none" local val "none"
        }
        _g2m_esc `"`val'"'
        file write `fh' `""`key'": "`s(esc)'", "'
    }
end

* region fills and text colours set by options in the graph command: the
* house style keeps the scheme's own colours out, so only the colours that
* graphregion(), plotregion(), title(), xtitle(), ytitle(), xlabel() and
* ylabel() set on the command line are written to the spec
program _g2m_colors
    args fh g fam
    local cmd
    capture local cmd `"``g'.command'"'
    local cmd = strlower(`"`cmd'"')
    * each item: key  option  minimum abbreviation  colour path
    local items `""gfill graphregion 6 style.boxstyle.shadestyle.color""'
    if inlist("`fam'", "twoway", "bar") {
        local items `"`items' "pfill plotregion 5 plotregion1.style.boxstyle.shadestyle.color""'
    }
    local items `"`items' "title_color title 2 title.style.color""'
    local items `"`items' "subtitle_color subtitle 4 subtitle.style.color""'
    if "`fam'" == "twoway" {
        local items `"`items' "xtitle_color xtitle 3 xaxis1.title.style.color""'
        local items `"`items' "ytitle_color ytitle 3 yaxis1.title.style.color""'
        local items `"`items' "xtick_color xlabel 4 xaxis1.style.majorstyle.tickstyle.textstyle.color""'
        local items `"`items' "ytick_color ylabel 4 yaxis1.style.majorstyle.tickstyle.textstyle.color""'
    }
    file write `fh' "  "
    foreach it of local items {
        tokenize `"`it'"'
        mata: st_local("body", _g2m_optbody(st_local("cmd"), "`2'", `3'))
        local val
        if "`2'" == "xlabel" | "`2'" == "ylabel" local pat "(^|[ ,])labc[a-z]*[(]"
        else local pat "(^|[ ,])f?c[a-z]*[(]"
        if regexm(`"`body'"', "`pat'") {
            capture local val ``g'.`4'.setting'
            if _rc local val
            local snm
            capture local snm ``g'.`4'.snm'
            if "`snm'" == "none" local val "none"
            local val : list retokenize val
        }
        file write `fh' `""`1'": "`val'", "'
    }
    file write `fh' _n
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
/* the bodies of every option in cmd whose name abbreviates full (at least
   minlen letters), joined by spaces; quoted text is skipped when matching
   parentheses and left out of the result, so a title such as
   "rbar, color(none)" is not read as a color() option */
string scalar _g2m_optbody(string scalar cmd, string scalar full, real scalar minlen)
{
    real scalar i, j, n, depth, inq
    string scalar out, c, w, body

    out = ""
    n = strlen(cmd)
    inq = 0
    for (i = 1; i <= n; i++) {
        c = substr(cmd, i, 1)
        if (c == char(34)) inq = !inq
        if (inq) continue
        if (i > 1) {
            if (!anyof((" ", ","), substr(cmd, i - 1, 1))) continue
        }
        j = i
        while (j <= n & strpos("abcdefghijklmnopqrstuvwxyz", substr(cmd, j, 1))) j++
        w = substr(cmd, i, j - i)
        if (strlen(w) < minlen | w != substr(full, 1, strlen(w))) continue
        if (substr(cmd, j, 1) != "(") continue
        depth = 0
        body = ""
        for (i = j; i <= n; i++) {
            c = substr(cmd, i, 1)
            if (c == char(34)) {
                inq = !inq
                body = body + " "
                continue
            }
            if (inq) continue
            if (c == "(") depth++
            else if (c == ")") {
                depth--
                if (depth == 0) break
            }
            body = body + c
        }
        out = out + " " + substr(body, 2, .)
        inq = 0
    }
    return(out)
}

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
