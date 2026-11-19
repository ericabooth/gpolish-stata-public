"""Build the gallery pages from gallery/gallery.do: gallery/index.html (GitHub Pages)
and gallery/README.md (rendered on GitHub). Run from the repository root:

    python gallery/make_page.py            write both pages
    python gallery/make_page.py --check    write nothing; exit 1 if either page differs from
                                           what this script would write
    python gallery/make_page.py --blocks DIR
                                           write both pages and each example's code block to
                                           DIR/<key>.do, for running every block in a fresh
                                           Stata session

Any other argument, or --blocks without a folder, stops with a usage message and exit
status 2 before anything is written.

Each code block runs as it stands: the section's setup lines (sysuse, estimation, label var,
locals), without the default-look graph drawn before shotA, then the polished code between
shotA and shotBC, with the shared size macros written out and a gr2mpl line at the end."""
import argparse, html, os, re, sys, textwrap

# read the arguments before anything is written, so a mistyped option changes no file
ap = argparse.ArgumentParser(prog="python gallery/make_page.py", allow_abbrev=False,
                             description="Build gallery/index.html and gallery/README.md from gallery/gallery.do.")
mode = ap.add_mutually_exclusive_group()
mode.add_argument("--check", action="store_true",
                  help="write nothing; exit 1 if either page differs from what this script writes")
mode.add_argument("--blocks", metavar="DIR",
                  help="also write each example's code block to DIR/<key>.do")
opts = ap.parse_args()
if opts.blocks is not None and not opts.blocks.strip():
    ap.error("--blocks needs a folder name")
if not os.path.isfile("gallery/gallery.do"):
    ap.error("gallery/gallery.do not found; run the script from the repository's top folder")
INFO = {
 "04_lines": ("Multi-series lines", "Direct end labels with a value column replace the legend. The two notes are placed automatically."),
 "05_scatter": ("Labelled scatter on a log axis", "Point labels pick the least crowded of eight positions and avoid the fit line. Legend text takes the colour of its key."),
 "06_margins": ("marginsplot", "A graph built by another command. gpolish reads the drawn graph, so the same end labels work."),
 "07_highlight": ("One series highlighted", "Context series in gray, one in colour, and only that one labelled."),
 "11_fitci": ("Scatter with fit and confidence band", "Selected points labelled; the legend becomes a coloured key above the plot."),
 "12_timeseries": ("Daily time series", "A callout placed by the layout step at the series minimum."),
 "13_coef": ("Coefficient plot", "Built from twoway rcap and scatter. The scheme and the title edit do the work."),
 "14_histogram": ("Histogram", "A note with a curved arrow; text position given by hand here."),
 "15_hbar": ("Ranked horizontal bars", "graph hbar is not a twoway graph: the scheme and the bold title apply, the layout commands do not. gr2mpl redraws it."),
 "16_box": ("Box plot", "Same split as the bar chart: scheme and title inside Stata, full restyle from gr2mpl."),
 "17_by": ("Small multiples with by()", "The scheme removes the shaded panel strips. gr2mpl gives bold panel titles and shared axes."),
 "18_combine": ("Combined panels", "graph combine of four graphs, each styled by the scheme; gr2mpl redraws every panel."),
 "08_overlays": ("Finding box, brace and callout", "Three overlays on one scatter: a shaded finding box, a curly brace marking a range, and a callout that finds its own place."),
 "09_cibrace": ("Group means with confidence-interval braces", "One brace names the confidence interval; another measures the gap between the two means."),
 "10_flow": ("Flow chart of sample restrictions", "Boxes and arrows on an empty plot, built from gpolish note and gpolish arrow. The counts come from the data."),
 "02_heatmap": ("Correlation heatmap", "Tiles drawn with twoway rbar, cell values as marker labels, and a legend used as the colour key."),
 "19_matrix": ("Scatterplot matrix", "graph matrix is its own graph family: the scheme and the bold title apply, and gr2mpl redraws it."),
 "20_dendrogram": ("Cluster dendrogram", "cluster dendrogram produces a twoway graph, so the scheme and gpolish apply directly."),
 "01_avplot": ("Added-variable plot", "A regression diagnostic from avplot, with the coefficient stated in a finding box."),
 "21_statplot": ("statplot", "statplot output is a graph hbar. The scheme and title edit apply inside Stata; gr2mpl redraws it with its group labels."),
 "03_coefplot": ("coefplot with shaded confidence bands", "Two regressions drawn with the community command coefplot: lines for the estimates and three nested bands for 50, 80 and 95 percent intervals, with direct labels and a finding box added by gpolish."),
 "22_heatplot": ("heatplot", "A two-way density from the community command heatplot, with its colour key."),
}
GRAPH_CMDS = ("avplot", "twoway", "coefplot", "line", "scatter", "marginsplot", "graph ",
              "histogram", "cluster dendrogram", "statplot", "heatplot")
COMMUNITY = {"coefplot": "ssc install coefplot",
             "statplot": "ssc install statplot",
             "heatplot": "ssc install heatplot, ssc install palettes and ssc install colrspace"}
FONT = 'graph set window fontface "Open Sans"   // font used for the images; saved for later sessions'
INTRO_MD = ("Each code block runs as it stands in a fresh Stata session, as a do-file "
            "(paste it into the Do-file Editor: the `///` line breaks and local macros need one). "
            "A block loads its data, runs any estimation the graph needs, draws the polished graph, "
            "and saves the matplotlib version as `figure.png`. The examples that use the community "
            "commands coefplot, statplot and heatplot name the `ssc install` lines they need. "
            "The first line, `graph set window fontface`, changes a saved preference that stays in force in "
            "later Stata sessions; type `graph set window` first to see your current font, or leave the line out "
            "to keep it. In batch mode (`stata -b`) that line only prints a note, and Stata exports with the "
            "font set by `graph set svg fontface` instead.")


def statements(lines):
    """Group physical lines into statements joined by ///."""
    out, cur = [], []
    for ln in lines:
        cur.append(ln)
        if not ln.rstrip().endswith("///"):
            out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    return out


def expand(c):
    """Write out the size macros that gallery.do shares across examples."""
    c = c.replace("`SZ'", "xsize(7) ysize(4.6)").replace("`TS'", "size(13.5pt)").replace("`SS'", "size(10pt)")
    return c.replace("`NS'", "size(8pt)").replace("`LS'", "labsize(9pt)")


def block(body):
    """One runnable code block from the body of one gallery.do section."""
    community = None
    keep = []
    for ln in body.split("\n"):
        s = ln.strip()
        m = re.match(r"capture which (\w+)", s)
        if m:
            community = m.group(1)
            continue
        if s in ("if !_rc {", "preserve", "restore"):
            continue
        keep.append(ln)
    # the if !_rc { ... } guard around a community command is not part of the example;
    # drop its closing brace (the last "}" in column 1 of the section)
    if community:
        del keep[max(i for i, ln in enumerate(keep) if ln == "}")]
    lines = textwrap.dedent("\n".join(keep)).split("\n")
    ia = next(i for i, ln in enumerate(lines) if ln.startswith("shotA "))
    ib = next(i for i, ln in enumerate(lines) if ln.startswith("shotBC "))
    pre = statements(lines[:ia])
    # drop the default-look graph command(s) directly before shotA
    while pre and pre[-1][0].lstrip().startswith(GRAPH_CMDS) and "wardslinkage" not in pre[-1][0]:
        pre.pop()
    setup = [ln for st in pre for ln in st]
    head = [FONT]
    if community:
        head.append(f"* needs the community command {community} ({COMMUNITY[community]})")
    if not any(re.match(r"sysuse ", ln) for ln in setup):
        setup.insert(0, "sysuse nlsw88, clear")  # 16 and 17 reuse the data loaded by 15
    code = "\n".join(head + setup + lines[ia + 1:ib]).strip("\n")
    return expand(code) + "\ngr2mpl, saving(figure.png) replace"


src = open("gallery/gallery.do", encoding="utf-8").read()
parts = re.split(r"\n\* -{20,} (\d\d) [^\n]*\n", src)
code = {}
for i in range(1, len(parts), 2):
    body = parts[i + 1].split('\ndi as res "gallery done"')[0]  # the last section runs on to the end of the script
    m = re.search(r"shotA (\S+)", body)
    if m:
        code[m.group(1)] = block(body)
missing = sorted(set(INFO) ^ set(code))
assert not missing, f"gallery.do sections and INFO differ: {missing}"
FID_TXT = "How closely the gr2mpl images place text compared with Stata's own export is measured for all twenty-two graphs in"
COLS = [("a", "Stata default"), ("b", "scheme(pypolish) + gpolish"), ("c", "+ gr2mpl (matplotlib render)")]
# ---- HTML page
css = """
:root{--bg:#f6f6f4;--card:#ffffff;--ink:#1a1a1a;--mute:#6b6b6b;--line:#e2e2de;--accent:#0b5d7a;--code:#f1f1ee}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#161718;--card:#202224;--ink:#ececec;--mute:#a0a0a0;--line:#34373a;--accent:#6fb1c7;--code:#1a1b1d}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 "Open Sans",system-ui,-apple-system,"Segoe UI",Helvetica,Arial,sans-serif}
main{max-width:1500px;margin:0 auto;padding:32px 16px 64px}
h1{font-size:30px;margin:0 0 6px}h2{font-size:20px;margin:0 0 4px}
p.lead{color:var(--mute);max-width:70ch;margin:0 0 10px}a{color:var(--accent)}
nav{margin:18px 0 26px;display:flex;flex-wrap:wrap;gap:8px}
nav a{font-size:13px;text-decoration:none;border:1px solid var(--line);background:var(--card);padding:4px 10px;border-radius:14px}
section{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:18px;margin:0 0 22px}
section p{color:var(--mute);margin:0 0 14px;max-width:80ch}
.row{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}
@media (max-width:900px){.row{grid-template-columns:1fr}}
figure{margin:0}figcaption{font-size:12.5px;font-weight:700;color:var(--mute);margin:0 0 5px;text-transform:uppercase;letter-spacing:.04em}
img{width:100%;height:auto;display:block;border:1px solid var(--line);border-radius:4px;background:#fff}
details{margin-top:12px}summary{cursor:pointer;color:var(--accent);font-size:14px}
pre{background:var(--code);border:1px solid var(--line);border-radius:6px;padding:12px;overflow-x:auto;font:12.5px/1.5 ui-monospace,Menlo,Consolas,monospace}
footer{color:var(--mute);font-size:13px;margin-top:30px}
"""
h = ['<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
     "<title>gpolish gallery</title><style>" + css + "</style></head><body><main>",
     "<h1>gpolish gallery</h1>",
     '<p class="lead">Twenty-two Stata graphs, each drawn three ways: Stata\'s default look, the same graph with <code>scheme(pypolish)</code> and <code>gpolish</code> (still a Stata graph), and that graph redrawn in matplotlib by <code>gr2mpl</code>.</p>',
     '<p class="lead"><a href="https://github.com/ericabooth/gpolish-stata-public">Repository and installation</a> · every image on this page is produced by <a href="https://github.com/ericabooth/gpolish-stata-public/blob/main/gallery/gallery.do">gallery/gallery.do</a>.</p>',
     '<p class="lead">' + FID_TXT + ' <a href="https://github.com/ericabooth/gpolish-stata-public/blob/main/gallery/fidelity.md">gallery/fidelity.md</a> (per-item data in <a href="https://github.com/ericabooth/gpolish-stata-public/blob/main/gallery/fidelity.csv">fidelity.csv</a>).</p>',
     '<p class="lead">' + re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(INTRO_MD)) + "</p><nav>"]
for k in sorted(code): h.append(f'<a href="#{k}">{html.escape(INFO[k][0])}</a>')
h.append("</nav>")
md = ["# gpolish gallery", "",
      "Twenty-two Stata graphs, each drawn three ways: Stata's default look, the same graph with `scheme(pypolish)` and `gpolish` (still a Stata graph), and that graph redrawn in matplotlib by `gr2mpl`.", "",
      "Every image is produced by [gallery.do](gallery.do). A browsable version is at <https://ericabooth.github.io/gpolish-stata-public/gallery/>.", "",
      FID_TXT + " [fidelity.md](fidelity.md) (per-item data in [fidelity.csv](fidelity.csv)).", "", INTRO_MD, ""]
for k in sorted(code):
    t, blurb = INFO[k]
    h.append(f'<section id="{k}"><h2>{html.escape(t)}</h2><p>{html.escape(blurb)}</p><div class="row">')
    for s, lab in COLS:
        h.append(f'<figure><figcaption>{html.escape(lab)}</figcaption><a href="img/{k}_{s}.png"><img loading="lazy" src="img/{k}_{s}.png" alt="{html.escape(t)}: {html.escape(lab)}"></a></figure>')
    h.append(f"</div><details><summary>Stata code for the polished versions</summary><pre>{html.escape(code[k])}</pre></details></section>")
    md += [f"## {t}", "", blurb, "", f"![{t}](sheets/{k}.png)", "", "<details><summary>Stata code for the polished versions</summary>", "", "```stata", code[k], "```", "", "</details>", ""]
h.append("<footer>gpolish, gr2mpl and the pypolish scheme are MIT licensed. Data: datasets shipped with Stata.</footer></main></body></html>")
pages = {"gallery/index.html": "\n".join(h), "gallery/README.md": "\n".join(md)}
if opts.check:
    # regression check: the committed pages must be what this script writes
    stale = [f for f, t in pages.items() if not os.path.exists(f) or open(f, encoding="utf-8").read() != t]
    for f in stale:
        print(f, "differs from what make_page.py writes; run python gallery/make_page.py")
    print(len(code), "examples;", "pages up to date" if not stale else f"{len(stale)} page(s) out of date")
    sys.exit(1 if stale else 0)
for f, t in pages.items():
    with open(f, "w", encoding="utf-8") as fh:
        fh.write(t)
if opts.blocks:
    os.makedirs(opts.blocks, exist_ok=True)
    for k, c in code.items():
        with open(os.path.join(opts.blocks, k + ".do"), "w", encoding="utf-8") as fh:
            fh.write(c + "\n")
print(len(code), "examples")
